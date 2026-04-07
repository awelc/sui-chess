import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../suiClient";
import { PACKAGE_ID, MODULE, LOBBY_ID } from "../config";

const GAME_TYPE_SUFFIX = `::${MODULE}::Game`;

const TARGET_CREATE = `${PACKAGE_ID}::${MODULE}::create_game`;
const TARGET_JOIN = `${PACKAGE_ID}::${MODULE}::join_game`;
const TARGET_MOVE = `${PACKAGE_ID}::${MODULE}::make_move`;
const TARGET_RESIGN = `${PACKAGE_ID}::${MODULE}::resign`;
const TARGET_DRAW = `${PACKAGE_ID}::${MODULE}::offer_draw`;
const TARGET_CREATE_OPEN = `${PACKAGE_ID}::${MODULE}::create_open_game`;
const TARGET_JOIN_OPEN = `${PACKAGE_ID}::${MODULE}::join_open_game`;
const TARGET_CANCEL_OPEN = `${PACKAGE_ID}::${MODULE}::cancel_open_game`;

/** Sign + execute a transaction and return effects + objectTypes. */
function useExecuteTransaction() {
  return useSignAndExecuteTransaction({
    execute: async ({ bytes, signature }) => {
      const result = await suiClient.executeTransaction({
        transaction: Uint8Array.from(atob(bytes), (c) => c.charCodeAt(0)),
        signatures: [signature],
        include: { effects: true, objectTypes: true }
      });
      if (result.$kind === "FailedTransaction") {
        const msg = result.FailedTransaction.status.error?.toString() ?? "Transaction failed";
        throw new Error(msg);
      }
      return result.Transaction;
    }
  });
}

/** Find the Game object ID from a create_game transaction result. */
function extractGameId(tx: {
  effects?: { changedObjects: Array<{ objectId: string; idOperation: string }> } | undefined;
  objectTypes?: Record<string, string> | undefined;
}): string | null {
  const effects = tx.effects;
  const types = tx.objectTypes;
  if (!effects || !types) return null;

  for (const obj of effects.changedObjects) {
    if (obj.idOperation === "Created") {
      const t = types[obj.objectId];
      if (t && t.endsWith(GAME_TYPE_SUFFIX)) {
        return obj.objectId;
      }
    }
  }
  return null;
}

/** Create a new chess game. Returns { mutate, mutateAsync, ... }. */
export function useCreateGame() {
  const { mutate, mutateAsync, ...rest } = useExecuteTransaction();

  const createGame = async (opponent: string, betSui: number) => {
    const betMist = BigInt(Math.round(betSui * 1_000_000_000));
    const tx = new Transaction();
    const [betCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(betMist)]);
    tx.moveCall({
      target: TARGET_CREATE,
      arguments: [tx.pure.address(opponent), betCoin]
    });

    const result = await mutateAsync({ transaction: tx });
    const gameId = extractGameId(result);
    if (!gameId) throw new Error("Could not find created Game object");
    return gameId;
  };

  return { createGame, ...rest };
}

/** Join an existing chess game. Returns { mutate, mutateAsync, ... }. */
export function useJoinGame() {
  const { mutate, mutateAsync, ...rest } = useExecuteTransaction();

  const joinGame = async (gameId: string, betSui: number) => {
    const betMist = BigInt(Math.round(betSui * 1_000_000_000));
    const tx = new Transaction();
    const [betCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(betMist)]);
    tx.moveCall({
      target: TARGET_JOIN,
      arguments: [tx.object(gameId), betCoin]
    });

    await mutateAsync({ transaction: tx });
    return gameId;
  };

  return { joinGame, ...rest };
}

/** Make a move on the board. */
export function useMakeMove() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const makeMove = async (
    gameId: string,
    fromFile: number,
    fromRank: number,
    toFile: number,
    toRank: number,
    promotion: number = 0
  ) => {
    const tx = new Transaction();
    tx.moveCall({
      target: TARGET_MOVE,
      arguments: [
        tx.object(LOBBY_ID),
        tx.object(gameId),
        tx.pure.u8(fromFile),
        tx.pure.u8(fromRank),
        tx.pure.u8(toFile),
        tx.pure.u8(toRank),
        tx.pure.u8(promotion)
      ]
    });
    await mutateAsync({ transaction: tx });
  };

  return { makeMove, ...rest };
}

/** Resign the current game. */
export function useResign() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const resign = async (gameId: string) => {
    const tx = new Transaction();
    tx.moveCall({
      target: TARGET_RESIGN,
      arguments: [tx.object(LOBBY_ID), tx.object(gameId)]
    });
    await mutateAsync({ transaction: tx });
  };

  return { resign, ...rest };
}

/** Offer a draw. */
export function useOfferDraw() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const offerDraw = async (gameId: string) => {
    const tx = new Transaction();
    tx.moveCall({
      target: TARGET_DRAW,
      arguments: [tx.object(LOBBY_ID), tx.object(gameId)]
    });
    await mutateAsync({ transaction: tx });
  };

  return { offerDraw, ...rest };
}

/** Create an open game listed in the lobby. Returns the new game ID. */
export function useCreateOpenGame() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const createOpenGame = async (betSui: number) => {
    const betMist = BigInt(Math.round(betSui * 1_000_000_000));
    const tx = new Transaction();
    const [betCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(betMist)]);
    tx.moveCall({
      target: TARGET_CREATE_OPEN,
      arguments: [tx.object(LOBBY_ID), betCoin]
    });

    const result = await mutateAsync({ transaction: tx });
    const gameId = extractGameId(result);
    if (!gameId) throw new Error("Could not find created Game object");
    return gameId;
  };

  return { createOpenGame, ...rest };
}

/** Join an open game from the lobby. */
export function useJoinOpenGame() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const joinOpenGame = async (gameId: string, betSui: number) => {
    const betMist = BigInt(Math.round(betSui * 1_000_000_000));
    const tx = new Transaction();
    const [betCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(betMist)]);
    tx.moveCall({
      target: TARGET_JOIN_OPEN,
      arguments: [tx.object(LOBBY_ID), tx.object(gameId), betCoin]
    });

    await mutateAsync({ transaction: tx });
    return gameId;
  };

  return { joinOpenGame, ...rest };
}

/** Cancel an open game in the lobby. Returns the creator's bet. */
export function useCancelOpenGame() {
  const { mutateAsync, ...rest } = useExecuteTransaction();

  const cancelOpenGame = async (gameId: string) => {
    const tx = new Transaction();
    tx.moveCall({
      target: TARGET_CANCEL_OPEN,
      arguments: [tx.object(LOBBY_ID), tx.object(gameId)]
    });
    await mutateAsync({ transaction: tx });
  };

  return { cancelOpenGame, ...rest };
}
