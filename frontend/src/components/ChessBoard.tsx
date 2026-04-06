import {
  type PieceInfo,
  pieceToUnicode,
  FILE_LABELS,
} from "../lib/boardParser";

interface ChessBoardProps {
  board: (PieceInfo | null)[][];
  selectedSquare: { displayRow: number; col: number } | null;
  onSquareClick: (displayRow: number, col: number) => void;
}

export default function ChessBoard({
  board,
  selectedSquare,
  onSquareClick,
}: ChessBoardProps) {
  return (
    <div className="chess-board">
      {board.map((row, displayRow) => (
        <div key={displayRow} className="board-row">
          <span className="rank-label">{8 - displayRow}</span>
          {row.map((piece, col) => {
            const isLight = (displayRow + col) % 2 === 0;
            const isSelected =
              selectedSquare?.displayRow === displayRow &&
              selectedSquare?.col === col;
            return (
              <button
                key={col}
                className={`square ${isLight ? "light" : "dark"} ${isSelected ? "selected" : ""}`}
                onClick={() => onSquareClick(displayRow, col)}
              >
                {piece ? pieceToUnicode(piece) : ""}
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
