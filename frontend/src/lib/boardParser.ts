export interface PieceInfo {
  type: number; // 1=PAWN, 2=ROOK, 3=KNIGHT, 4=BISHOP, 5=QUEEN, 6=KING
  color: number; // 0=WHITE, 1=BLACK
}

export interface GameState {
  board: (PieceInfo | null)[][]; // 8 rows × 8 cols, board[0] = rank 8 (top)
  currentTurn: number;
  status: number;
  playerWhite: string;
  playerBlack: string;
  whiteBet: string;
  blackBet: string;
  whiteDrawOffer: boolean;
  blackDrawOffer: boolean;
}

// Status constants matching chess.move
export const STATUS_WAITING = 0;
export const STATUS_ACTIVE = 1;
export const STATUS_WHITE_WINS = 2;
export const STATUS_BLACK_WINS = 3;
export const STATUS_DRAW = 4;

export const WHITE = 0;
export const BLACK = 1;

const PIECE_UNICODE: Record<string, string> = {
  "1_0": "♙",
  "2_0": "♖",
  "3_0": "♘",
  "4_0": "♗",
  "5_0": "♕",
  "6_0": "♔",
  "1_1": "♟",
  "2_1": "♜",
  "3_1": "♞",
  "4_1": "♝",
  "5_1": "♛",
  "6_1": "♚",
};

export function pieceToUnicode(piece: PieceInfo): string {
  return PIECE_UNICODE[`${piece.type}_${piece.color}`] ?? "?";
}

/**
 * Parse the JSON representation of a Game object into a renderable GameState.
 * The `json` field from getObject({ include: { json: true } }) contains
 * the Move struct fields as a nested object.
 */
export function parseGameObject(json: Record<string, unknown>): GameState {
  const fields = json as Record<string, unknown>;

  // Parse board squares: 64-element array of Option<Piece>
  const boardFields = fields.board as Record<string, unknown>;
  const squares = boardFields.squares as unknown[];

  // Build 8×8 grid, flipped for display (board[0] = rank 8)
  const board: (PieceInfo | null)[][] = [];
  for (let displayRow = 0; displayRow < 8; displayRow++) {
    const row: (PieceInfo | null)[] = [];
    const onChainRow = 7 - displayRow; // flip: display row 0 = on-chain row 7
    for (let col = 0; col < 8; col++) {
      const sq = squares[onChainRow * 8 + col];
      row.push(parsePiece(sq));
    }
    board.push(row);
  }

  return {
    board,
    currentTurn: Number(fields.current_turn),
    status: Number(fields.status),
    playerWhite: String(fields.player_white),
    playerBlack: String(fields.player_black),
    whiteBet: String(
      (fields.white_bet as Record<string, unknown>)?.value ?? "0",
    ),
    blackBet: String(
      (fields.black_bet as Record<string, unknown>)?.value ?? "0",
    ),
    whiteDrawOffer: Boolean(fields.white_draw_offer),
    blackDrawOffer: Boolean(fields.black_draw_offer),
  };
}

function parsePiece(sq: unknown): PieceInfo | null {
  if (sq === null || sq === undefined) return null;

  // Option<Piece> in JSON can appear as:
  // - null (empty square)
  // - { piece_type: N, color: N, has_moved: bool } (direct fields)
  // - { fields: { piece_type: N, color: N, has_moved: bool } } (wrapped)
  const obj = sq as Record<string, unknown>;

  if ("piece_type" in obj) {
    return { type: Number(obj.piece_type), color: Number(obj.color) };
  }
  if ("fields" in obj) {
    const f = obj.fields as Record<string, unknown>;
    return { type: Number(f.piece_type), color: Number(f.color) };
  }
  return null;
}

/** Convert display coordinates to chess file/rank for the contract. */
export function displayToChessCoords(
  displayRow: number,
  col: number,
): { file: number; rank: number } {
  return { file: col, rank: 8 - displayRow };
}

export const FILE_LABELS = ["a", "b", "c", "d", "e", "f", "g", "h"];
