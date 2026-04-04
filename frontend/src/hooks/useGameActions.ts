import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../suiClient";
import { PACKAGE_ID, MODULE } from "../config";

const TARGET_CREATE = `${PACKAGE_ID}::${MODULE}::create_game`;
const TARGET_JOIN = `${PACKAGE_ID}::${MODULE}::join_game`;

/** Sign + execute a transaction and return effects + objectTypes. */
function useExecuteTransaction() {
  return useSignAndExecuteTransaction({
    execute: async ({ bytes, signature }) => {
      const result = await suiClient.executeTransaction({
        transaction: Uint8Array.from(atob(bytes), (c) => c.charCodeAt(0)),
        signatures: [signature],
        include: { effects: true, objectTypes: true },
      });
      if (result.$kind === "FailedTransaction") {
        const msg =
          result.FailedTransaction.status.error?.toString() ??
          "Transaction failed";
        throw new Error(msg);
      }
      return result.Transaction;
    },
  });
}

/** Find the Game object ID from a create_game transaction result. */
function extractGameId(tx: {
  effects?:
    | { changedObjects: Array<{ objectId: string; idOperation: string }> }
    | undefined;
  objectTypes?: Record<string, string> | undefined;
}): string | null {
  const effects = tx.effects;
  const types = tx.objectTypes;
  if (!effects || !types) return null;

  for (const obj of effects.changedObjects) {
    if (obj.idOperation === "Created") {
      const t = types[obj.objectId];
      if (t && t.includes("::chess::Game")) {
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
      arguments: [tx.pure.address(opponent), betCoin],
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
      arguments: [tx.object(gameId), betCoin],
    });

    await mutateAsync({ transaction: tx });
    return gameId;
  };

  return { joinGame, ...rest };
}
