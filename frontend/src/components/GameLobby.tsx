import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useLobby } from "../hooks/useLobby";
import { useCreateOpenGame, useJoinOpenGame, useCancelOpenGame } from "../hooks/useGameActions";

interface GameLobbyProps {
  onGameReady: (gameId: string) => void;
}

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function truncateGameId(id: string) {
  if (id.length <= 10) return id;
  return `${id.slice(0, 4)}...${id.slice(-4)}`;
}

function formatSui(mist: string): string {
  const val = Number(mist) / 1_000_000_000;
  return val.toFixed(3);
}

export default function GameLobby({ onGameReady }: GameLobbyProps) {
  const account = useCurrentAccount();
  const { openGames, activeGames, isLoading } = useLobby();
  const { createOpenGame } = useCreateOpenGame();
  const { joinOpenGame } = useJoinOpenGame();
  const { cancelOpenGame } = useCancelOpenGame();

  const [betSui, setBetSui] = useState("0.1");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const myAddress = account?.address;

  // Games involving the current player.
  const myGames = activeGames.filter((g) => g.white === myAddress || g.black === myAddress);

  // Open games from other players.
  const otherOpenGames = openGames.filter((g) => g.creator !== myAddress);

  // My open games (waiting, not yet joined).
  const myOpenGames = openGames.filter((g) => g.creator === myAddress);

  const handleCreate = async () => {
    if (!account || submitting) return;
    setError("");
    setSubmitting(true);
    try {
      const gameId = await createOpenGame(parseFloat(betSui));
      onGameReady(gameId);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleJoin = async (gameId: string) => {
    if (!account || submitting) return;
    setError("");
    setSubmitting(true);
    try {
      await joinOpenGame(gameId, parseFloat(betSui));
      onGameReady(gameId);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleCancel = async (gameId: string) => {
    if (!account || submitting) return;
    setError("");
    setSubmitting(true);
    try {
      await cancelOpenGame(gameId);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="game-lobby">
      {/* Your active/waiting games */}
      {(myGames.length > 0 || myOpenGames.length > 0) && (
        <div className="lobby-section">
          <h2>Your Games</h2>
          {myOpenGames.map((game) => (
            <div key={game.gameId} className="lobby-game mine">
              <code className="lobby-game-id">{truncateGameId(game.gameId)}</code>
              <span className="lobby-status">Waiting</span>
              <span className="lobby-bet">{formatSui(game.betAmount)} SUI</span>
              <button className="lobby-action" onClick={() => onGameReady(game.gameId)}>
                View
              </button>
              <button
                className="lobby-action"
                onClick={() => handleCancel(game.gameId)}
                disabled={submitting}
              >
                Cancel
              </button>
            </div>
          ))}
          {myGames
            .filter(
              (g) =>
                g.black !== "0x0000000000000000000000000000000000000000000000000000000000000000"
            )
            .map((game) => {
              const opponent = game.white === myAddress ? game.black : game.white;
              return (
                <div key={game.gameId} className="lobby-game mine">
                  <code className="lobby-game-id">{truncateGameId(game.gameId)}</code>
                  <span className="lobby-status">Active</span>
                  <span className="lobby-creator">vs {truncateAddress(opponent)}</span>
                  <button className="lobby-action" onClick={() => onGameReady(game.gameId)}>
                    Resume
                  </button>
                </div>
              );
            })}
        </div>
      )}

      {/* Create a new game */}
      <div className="lobby-create">
        <h2>Create Game</h2>
        <label>
          Bet (SUI)
          <input
            type="number"
            min="0"
            step="0.01"
            value={betSui}
            onChange={(e) => setBetSui(e.target.value)}
          />
        </label>
        <button onClick={handleCreate} disabled={!account || submitting}>
          {submitting ? "Creating..." : "Create Open Game"}
        </button>
      </div>

      {/* Open games from other players */}
      <div className="lobby-section">
        <h2>Open Games</h2>
        {isLoading && <p className="lobby-hint">Loading...</p>}
        {!isLoading && otherOpenGames.length === 0 && (
          <p className="lobby-hint">No open games from other players.</p>
        )}
        {otherOpenGames.map((game) => (
          <div key={game.gameId} className="lobby-game">
            <code className="lobby-game-id">{truncateGameId(game.gameId)}</code>
            <span className="lobby-creator">{truncateAddress(game.creator)}</span>
            <span className="lobby-bet">{formatSui(game.betAmount)} SUI</span>
            <button
              className="lobby-action"
              onClick={() => handleJoin(game.gameId)}
              disabled={!account || submitting}
            >
              Join
            </button>
          </div>
        ))}
      </div>

      {error && <p className="error">{error}</p>}
    </div>
  );
}
