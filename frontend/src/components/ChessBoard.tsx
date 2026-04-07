import { type PieceInfo, pieceToUnicode, WHITE, FILE_LABELS } from "../lib/boardParser";

export interface PendingMove {
  displayRow: number;
  col: number;
  piece: PieceInfo;
  status: "pending" | "rejected";
}

interface ChessBoardProps {
  board: (PieceInfo | null)[][];
  selectedSquare: { displayRow: number; col: number } | null;
  pendingSource: { displayRow: number; col: number } | null;
  pendingMove: PendingMove | null;
  onSquareClick: (displayRow: number, col: number) => void;
}

function PieceChar({ piece }: { piece: PieceInfo }) {
  const colorClass = piece.color === WHITE ? "piece-white" : "piece-black";
  return <span className={colorClass}>{pieceToUnicode(piece)}</span>;
}

export default function ChessBoard({
  board,
  selectedSquare,
  pendingSource,
  pendingMove,
  onSquareClick
}: ChessBoardProps) {
  return (
    <div className="chess-board">
      {board.map((row, displayRow) => (
        <div key={displayRow} className="board-row">
          <span className="rank-label">{8 - displayRow}</span>
          {row.map((piece, col) => {
            const isLight = (displayRow + col) % 2 === 0;
            const isSelected =
              (selectedSquare?.displayRow === displayRow && selectedSquare?.col === col) ||
              (pendingSource?.displayRow === displayRow && pendingSource?.col === col);
            const isPendingDest =
              pendingMove?.displayRow === displayRow && pendingMove?.col === col;
            const moveStatus = isPendingDest ? pendingMove.status : null;

            return (
              <button
                key={col}
                className={`square ${isLight ? "light" : "dark"} ${isSelected ? "selected" : ""} ${moveStatus ?? ""}`}
                onClick={() => onSquareClick(displayRow, col)}
              >
                {isPendingDest ? (
                  <span className="square-content">
                    {piece && (
                      <span className="existing-piece">
                        <PieceChar piece={piece} />
                      </span>
                    )}
                    <span className="ghost-piece">
                      <PieceChar piece={pendingMove.piece} />
                    </span>
                  </span>
                ) : piece ? (
                  <PieceChar piece={piece} />
                ) : (
                  ""
                )}
              </button>
            );
          })}
        </div>
      ))}
      <div className="board-row file-labels">
        <span className="rank-label" />
        {FILE_LABELS.map((f) => (
          <span key={f} className="file-label">
            {f}
          </span>
        ))}
      </div>
    </div>
  );
}
