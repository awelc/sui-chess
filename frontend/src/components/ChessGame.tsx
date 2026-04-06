import { useState } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useGame } from "../hooks/useGame";
import { useMakeMove, useResign, useOfferDraw } from "../hooks/useGameActions";
import ChessBoard from "./ChessBoard";
import {
  displayToChessCoords,
  WHITE,
  STATUS_ACTIVE,
  STATUS_WAITING,
  STATUS_WHITE_WINS,
  STATUS_BLACK_WINS,
  STATUS_DRAW,
} from "../lib/boardParser";

interface ChessGameProps {
  gameId: string;
  onLeave: () => void;
}

const QUEEN = 5;

export default function ChessGame({ gameId, onLeave }: ChessGameProps) {
  const account = useCurrentAccount();
  const { game, isLoading, error: fetchError } = useGame(gameId);
  const { makeMove } = useMakeMove();
  const { resign } = useResign();
  const { offerDraw } = useOfferDraw();

  const [selectedSquare, setSelectedSquare] = useState<{
    displayRow: number;
    col: number;
  } | null>(null);
  const [moveError, setMoveError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (isLoading && !game) return <p>Loading game...</p>;
  if (fetchError) return <p className="error">Error: {String(fetchError)}</p>;
  if (!game) return <p>Game not found.</p>;

  const myAddress = account?.address;
  const isWhite = myAddress === game.playerWhite;
  const isBlack = myAddress === game.playerBlack;
  const isMyTurn =
    game.status === STATUS_ACTIVE &&
    ((game.currentTurn === WHITE && isWhite) ||
      (game.currentTurn !== WHITE && isBlack));

  const handleSquareClick = async (displayRow: number, col: number) => {
    if (!isMyTurn || submitting) return;

    if (!selectedSquare) {
      // First click: select source
      const piece = game.board[displayRow][col];
      if (!piece) return;
      // Only select own pieces
      const myColor = isWhite ? WHITE : 1;
      if (piece.color !== myColor) return;
      setSelectedSquare({ displayRow, col });
      return;
    }

    // Second click: submit move
    const from = displayToChessCoords(
      selectedSquare.displayRow,
      selectedSquare.col,
    );
    const to = displayToChessCoords(displayRow, col);
    setSelectedSquare(null);
    setMoveError("");
    setSubmitting(true);

    // Auto-promote to queen if pawn reaches last rank
    let promotion = 0;
    const piece = game.board[selectedSquare.displayRow][selectedSquare.col];
    if (piece?.type === 1) {
      if ((isWhite && to.rank === 8) || (isBlack && to.rank === 1)) {
        promotion = QUEEN;
      }
    }

    try {
      await makeMove(gameId, from.file, from.rank, to.file, to.rank, promotion);
    } catch (err) {
      setMoveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleResign = async () => {
    if (submitting) return;
    setSubmitting(true);
    try {
      await resign(gameId);
    } catch (err) {
      setMoveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleOfferDraw = async () => {
    if (submitting) return;
    setSubmitting(true);
    try {
      await offerDraw(gameId);
    } catch (err) {
      setMoveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="chess-game">
      <div className="game-info">
        <code className="game-id">{gameId}</code>
        <StatusBar game={game} isWhite={isWhite} isBlack={isBlack} />
      </div>

      <ChessBoard
        board={game.board}
        selectedSquare={selectedSquare}
        onSquareClick={handleSquareClick}
      />

      {moveError && <p className="error">{moveError}</p>}

      {game.status === STATUS_ACTIVE && (isWhite || isBlack) && (
        <div className="game-controls">
          <button onClick={handleResign} disabled={submitting}>
            Resign
          </button>
          <button onClick={handleOfferDraw} disabled={submitting}>
            Offer Draw
          </button>
        </div>
      )}

      <button className="back-btn" onClick={onLeave}>
        Back to lobby
      </button>
    </div>
  );
}

function StatusBar({
  game,
  isWhite,
  isBlack,
}: {
  game: {
    status: number;
    currentTurn: number;
    playerWhite: string;
    playerBlack: string;
    whiteDrawOffer: boolean;
    blackDrawOffer: boolean;
  };
  isWhite: boolean;
  isBlack: boolean;
}) {
  const role = isWhite ? "White" : isBlack ? "Black" : "Spectator";

  let statusText: string;
  switch (game.status) {
    case STATUS_WAITING:
      statusText = "Waiting for opponent to join...";
      break;
    case STATUS_ACTIVE:
      statusText = game.currentTurn === WHITE ? "White's turn" : "Black's turn";
      break;
    case STATUS_WHITE_WINS:
      statusText = "White wins!";
      break;
    case STATUS_BLACK_WINS:
      statusText = "Black wins!";
      break;
    case STATUS_DRAW:
      statusText = "Game drawn.";
      break;
    default:
      statusText = `Status: ${game.status}`;
  }

  return (
    <div className="status-bar">
      <span>You: {role}</span>
      <span className="status-text">{statusText}</span>
      {game.whiteDrawOffer && (
        <span className="draw-offer">White offers draw</span>
      )}
      {game.blackDrawOffer && (
        <span className="draw-offer">Black offers draw</span>
      )}
    </div>
  );
}
