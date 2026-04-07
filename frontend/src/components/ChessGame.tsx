import { useState, useRef, useCallback } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useGame } from "../hooks/useGame";
import { useMakeMove, useResign, useOfferDraw } from "../hooks/useGameActions";
import ChessBoard, { type PendingMove } from "./ChessBoard";
import PromotionPicker from "./PromotionPicker";
import {
  type PieceInfo,
  displayToChessCoords,
  parseAbortMessage,
  WHITE,
  STATUS_ACTIVE,
  STATUS_WAITING,
  STATUS_WHITE_WINS,
  STATUS_BLACK_WINS,
  STATUS_DRAW
} from "../lib/boardParser";

interface ChessGameProps {
  gameId: string;
  onLeave: () => void;
}

function truncateGameId(id: string) {
  if (id.length <= 10) return id;
  return `${id.slice(0, 4)}...${id.slice(-4)}`;
}

interface PromotionPending {
  from: { file: number; rank: number };
  to: { file: number; rank: number };
  displayRow: number;
  col: number;
  piece: PieceInfo;
  sourceDisplayRow: number;
  sourceCol: number;
}

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
  const [pendingMove, setPendingMove] = useState<PendingMove | null>(null);
  const [pendingSource, setPendingSource] = useState<{
    displayRow: number;
    col: number;
  } | null>(null);
  const [promotionMove, setPromotionMove] = useState<PromotionPending | null>(null);
  const rejectTimer = useRef<ReturnType<typeof setTimeout>>();

  const clearPending = useCallback(() => {
    setPendingMove(null);
    setPendingSource(null);
    setPromotionMove(null);
    setMoveError("");
    if (rejectTimer.current) clearTimeout(rejectTimer.current);
  }, []);

  if (isLoading && !game) return <p>Loading game...</p>;
  if (fetchError) return <p className="error">Error: {String(fetchError)}</p>;
  if (!game) return <p>Game not found.</p>;

  const myAddress = account?.address;
  const isWhite = myAddress === game.playerWhite;
  const isBlack = myAddress === game.playerBlack;
  const isMyTurn =
    game.status === STATUS_ACTIVE &&
    ((game.currentTurn === WHITE && isWhite) || (game.currentTurn !== WHITE && isBlack));

  const handleSquareClick = async (displayRow: number, col: number) => {
    // Clear any previous pending/rejected move on click
    if (pendingMove) clearPending();

    if (!isMyTurn || submitting) return;

    if (!selectedSquare) {
      const piece = game.board[displayRow][col];
      if (!piece) return;
      const myColor = isWhite ? WHITE : 1;
      if (piece.color !== myColor) return;
      setSelectedSquare({ displayRow, col });
      return;
    }

    // Second click: submit move
    const from = displayToChessCoords(selectedSquare.displayRow, selectedSquare.col);
    const to = displayToChessCoords(displayRow, col);
    const piece = game.board[selectedSquare.displayRow][selectedSquare.col] as PieceInfo;

    // Show pending move immediately: source stays green, destination goes green
    const srcCoords = {
      displayRow: selectedSquare.displayRow,
      col: selectedSquare.col
    };
    setPendingSource(srcCoords);
    setPendingMove({ displayRow, col, piece, status: "pending" });
    setSelectedSquare(null);
    setMoveError("");

    // Check if this is a pawn promotion
    const isPawnPromotion =
      piece.type === 1 && ((isWhite && to.rank === 8) || (isBlack && to.rank === 1));

    if (isPawnPromotion) {
      setPromotionMove({
        from,
        to,
        displayRow,
        col,
        piece,
        sourceDisplayRow: srcCoords.displayRow,
        sourceCol: srcCoords.col
      });
      return;
    }

    await submitMove(from, to, 0, displayRow, col, piece);
  };

  const submitMove = async (
    from: { file: number; rank: number },
    to: { file: number; rank: number },
    promotion: number,
    displayRow: number,
    col: number,
    piece: PieceInfo
  ) => {
    setSubmitting(true);
    try {
      await makeMove(gameId, from.file, from.rank, to.file, to.rank, promotion);
      setPendingMove(null);
      setPendingSource(null);
      setPromotionMove(null);
    } catch (err) {
      const raw = err instanceof Error ? err.message : String(err);
      setMoveError(parseAbortMessage(raw));
      setPendingSource(null);
      setPromotionMove(null);
      setPendingMove({ displayRow, col, piece, status: "rejected" });
      rejectTimer.current = setTimeout(() => {
        setPendingMove(null);
        setMoveError("");
      }, 3000);
    } finally {
      setSubmitting(false);
    }
  };

  const handlePromotion = async (pieceType: number) => {
    if (!promotionMove) return;
    const { from, to, displayRow, col, piece } = promotionMove;
    await submitMove(from, to, pieceType, displayRow, col, piece);
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
        <div className="game-id-row">
          <span className="game-id-label">Game</span>
          <code className="game-id">{truncateGameId(gameId)}</code>
        </div>
        <StatusBar game={game} isWhite={isWhite} isBlack={isBlack} />
      </div>

      <ChessBoard
        board={game.board}
        selectedSquare={selectedSquare}
        pendingSource={pendingSource}
        pendingMove={pendingMove}
        onSquareClick={handleSquareClick}
      />

      {promotionMove && <PromotionPicker color={isWhite ? WHITE : 1} onSelect={handlePromotion} />}

      {moveError && <p className="error move-error">{moveError}</p>}

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
  isBlack
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
      {game.whiteDrawOffer && <span className="draw-offer">White offers draw</span>}
      {game.blackDrawOffer && <span className="draw-offer">Black offers draw</span>}
    </div>
  );
}
