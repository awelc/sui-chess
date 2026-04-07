import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useCreateGame, useJoinGame } from "../hooks/useGameActions";

interface GameSetupProps {
  onGameReady: (gameId: string) => void;
}

export default function GameSetup({ onGameReady }: GameSetupProps) {
  const account = useCurrentAccount();

  return (
    <div className="game-setup">
      <CreateGameForm disabled={!account} onCreated={onGameReady} />
      <JoinGameForm disabled={!account} onJoined={onGameReady} />
    </div>
  );
}

function CreateGameForm({
  disabled,
  onCreated
}: {
  disabled: boolean;
  onCreated: (gameId: string) => void;
}) {
  const [opponent, setOpponent] = useState("");
  const [betSui, setBetSui] = useState("0.1");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { createGame } = useCreateGame();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const gameId = await createGame(opponent, parseFloat(betSui));
      onCreated(gameId);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <form className="setup-form" onSubmit={handleSubmit}>
      <h2>Create Game</h2>
      <label>
        Opponent address
        <input
          type="text"
          placeholder="0x..."
          value={opponent}
          onChange={(e) => setOpponent(e.target.value)}
          required
        />
      </label>
      <label>
        Bet (SUI)
        <input
          type="number"
          min="0"
          step="0.01"
          value={betSui}
          onChange={(e) => setBetSui(e.target.value)}
          required
        />
      </label>
      <button type="submit" disabled={disabled || loading}>
        {loading ? "Creating..." : "Create Game"}
      </button>
      {error && <p className="error">{error}</p>}
    </form>
  );
}

function JoinGameForm({
  disabled,
  onJoined
}: {
  disabled: boolean;
  onJoined: (gameId: string) => void;
}) {
  const [gameId, setGameId] = useState("");
  const [betSui, setBetSui] = useState("0.1");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { joinGame } = useJoinGame();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await joinGame(gameId, parseFloat(betSui));
      onJoined(gameId);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <form className="setup-form" onSubmit={handleSubmit}>
      <h2>Join Game</h2>
      <label>
        Game ID
        <input
          type="text"
          placeholder="0x..."
          value={gameId}
          onChange={(e) => setGameId(e.target.value)}
          required
        />
      </label>
      <label>
        Bet (SUI)
        <input
          type="number"
          min="0"
          step="0.01"
          value={betSui}
          onChange={(e) => setBetSui(e.target.value)}
          required
        />
      </label>
      <button type="submit" disabled={disabled || loading}>
        {loading ? "Joining..." : "Join Game"}
      </button>
      {error && <p className="error">{error}</p>}
    </form>
  );
}
