import { pieceToUnicode } from "../lib/boardParser";

const PROMOTION_OPTIONS = [
  { type: 5, label: "Queen" },
  { type: 2, label: "Rook" },
  { type: 4, label: "Bishop" },
  { type: 3, label: "Knight" }
];

interface PromotionPickerProps {
  color: number; // 0=WHITE, 1=BLACK
  onSelect: (pieceType: number) => void;
}

export default function PromotionPicker({ color, onSelect }: PromotionPickerProps) {
  return (
    <div className="promotion-picker">
      <span className="promotion-label">Promote to:</span>
      {PROMOTION_OPTIONS.map((opt) => (
        <button
          key={opt.type}
          className="promotion-option"
          title={opt.label}
          onClick={() => onSelect(opt.type)}
        >
          {pieceToUnicode({ type: opt.type, color })}
        </button>
      ))}
    </div>
  );
}
