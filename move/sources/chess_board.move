/// Board representation for on-chain chess.
///
/// The board is a `vector<Option<Piece>>` of 64 elements indexed by position.
/// Row 0 is white's back rank (a1–h1), row 7 is black's back rank (a8–h8).
/// Empty squares are `option::none()`, occupied squares are `option::some(piece)`.
///
/// Positions are represented as `Pos` structs. Use `sq(file, rank)` to create
/// from chess notation: `sq(E, 2)` returns the position for square e2.
#[allow(unused_const)]
module sui_chess::chess_board {
    // Method aliases for Piece accessors (readable as piece.kind(), piece.color()).
    public use fun piece_kind as Piece.kind;
    public use fun piece_color as Piece.color;

    // Register chess_rules functions as methods on Board.
    public use fun sui_chess::chess_rules::validate_and_apply_move as Board.validate_and_apply_move;
    public use fun sui_chess::chess_rules::is_in_check as Board.is_in_check;
    public use fun sui_chess::chess_rules::is_checkmate as Board.is_checkmate;
    public use fun sui_chess::chess_rules::is_stalemate as Board.is_stalemate;

    // ===== Constants: piece types =====

    const PAWN: u8 = 1;
    const ROOK: u8 = 2;
    const KNIGHT: u8 = 3;
    const BISHOP: u8 = 4;
    const QUEEN: u8 = 5;
    const KING: u8 = 6;

    // ===== Constants: colors =====

    const WHITE: u8 = 0;
    const BLACK: u8 = 1;

    // ===== Constants: chess files (column indices) =====
    const A: u8 = 0;
    const B: u8 = 1;
    const C: u8 = 2;
    const D: u8 = 3;
    const E: u8 = 4;
    const F: u8 = 5;
    const G: u8 = 6;
    const H: u8 = 7;

    // ===== Errors =====

    const EIndexOutOfBounds: u64 = 0;

    // ===== Position struct =====

    /// A position on the board. Use `sq(file, rank)` to create from chess notation.
    public struct Pos has copy, drop, store {
        row: u8,
        col: u8,
    }

    // ===== Piece struct =====

    /// A chess piece with its type, color, and movement state.
    /// `has_moved` tracks castling eligibility (king/rook) and pawn double-push eligibility.
    public struct Piece has copy, drop, store {
        piece_type: u8,
        color: u8,
        has_moved: bool,
    }

    // ===== Board struct =====

    /// The chess board state.
    public struct Board has copy, drop, store {
        /// 64 squares (row-major, row 0 = white back rank). None = empty square.
        squares: vector<Option<Piece>>,
        /// Column of the pawn that just double-pushed and is capturable en-passant,
        /// or `none` if no en-passant is available. Resets every move.
        ep_target_col: Option<u8>,
    }

    // ===== Position constructors and accessors =====

    /// Convert chess file (A..H) + rank (1..8) to a board position.
    /// Example: `sq(E, 2)` returns the position for square e2.
    public fun sq(file: u8, rank: u8): Pos {
        Pos { row: rank - 1, col: file }
    }

    /// Get the row index from a position.
    public fun row(p: &Pos): u8 { p.row }

    /// Get the column index from a position.
    public fun col(p: &Pos): u8 { p.col }

    // ===== Piece constructors =====

    /// Create a new piece (unmoved).
    public fun new_piece(piece_type: u8, color: u8): Piece {
        Piece { piece_type, color, has_moved: false }
    }

    /// Create a piece with explicit has_moved flag (useful for test setup).
    public fun new_piece_with_flags(piece_type: u8, color: u8, has_moved: bool): Piece {
        Piece { piece_type, color, has_moved }
    }

    // ===== Piece accessors =====

    public fun piece_kind(piece: &Piece): u8 { piece.piece_type }

    public fun piece_color(piece: &Piece): u8 { piece.color }

    public fun has_moved(piece: &Piece): bool { piece.has_moved }

    // ===== Board accessors =====

    /// Read the square at the given position.
    public fun piece_at(board: &Board, p: Pos): Option<Piece> {
        let idx = (p.row as u64) * 8 + (p.col as u64);
        assert!(idx < 64, EIndexOutOfBounds);
        *board.squares.borrow(idx)
    }

    /// Write a square at the given position.
    public fun set_piece(board: &mut Board, p: Pos, piece: Option<Piece>) {
        let idx = (p.row as u64) * 8 + (p.col as u64);
        assert!(idx < 64, EIndexOutOfBounds);
        *board.squares.borrow_mut(idx) = piece;
    }

    /// True if the square at the given position has no piece.
    public fun is_empty(board: &Board, p: Pos): bool {
        piece_at(board, p).is_none()
    }

    /// Borrow the raw squares vector (useful for iteration).
    public fun squares(board: &Board): &vector<Option<Piece>> {
        &board.squares
    }

    /// Column of the pawn eligible for en-passant capture, or none.
    public fun ep_target_col(board: &Board): Option<u8> {
        board.ep_target_col
    }

    // ===== Board construction =====

    /// Standard chess starting position.
    public fun new(): Board {
        let mut squares = vector::empty<Option<Piece>>();

        // Row 0: white back rank (a1..h1)
        squares.push_back(option::some(new_piece(ROOK, WHITE)));
        squares.push_back(option::some(new_piece(KNIGHT, WHITE)));
        squares.push_back(option::some(new_piece(BISHOP, WHITE)));
        squares.push_back(option::some(new_piece(QUEEN, WHITE)));
        squares.push_back(option::some(new_piece(KING, WHITE)));
        squares.push_back(option::some(new_piece(BISHOP, WHITE)));
        squares.push_back(option::some(new_piece(KNIGHT, WHITE)));
        squares.push_back(option::some(new_piece(ROOK, WHITE)));

        // Row 1: white pawns
        let mut i: u64 = 0;
        while (i < 8) {
            squares.push_back(option::some(new_piece(PAWN, WHITE)));
            i = i + 1;
        };

        // Rows 2–5: empty squares
        i = 0;
        while (i < 32) {
            squares.push_back(option::none());
            i = i + 1;
        };

        // Row 6: black pawns
        i = 0;
        while (i < 8) {
            squares.push_back(option::some(new_piece(PAWN, BLACK)));
            i = i + 1;
        };

        // Row 7: black back rank (a8..h8)
        squares.push_back(option::some(new_piece(ROOK, BLACK)));
        squares.push_back(option::some(new_piece(KNIGHT, BLACK)));
        squares.push_back(option::some(new_piece(BISHOP, BLACK)));
        squares.push_back(option::some(new_piece(QUEEN, BLACK)));
        squares.push_back(option::some(new_piece(KING, BLACK)));
        squares.push_back(option::some(new_piece(BISHOP, BLACK)));
        squares.push_back(option::some(new_piece(KNIGHT, BLACK)));
        squares.push_back(option::some(new_piece(ROOK, BLACK)));

        Board { squares, ep_target_col: option::none() }
    }

    /// Create an empty board (useful for setting up test positions).
    public fun empty(): Board {
        let mut squares = vector::empty<Option<Piece>>();
        let mut i: u64 = 0;
        while (i < 64) {
            squares.push_back(option::none());
            i = i + 1;
        };
        Board { squares, ep_target_col: option::none() }
    }

    /// Create an empty board with a specific ep_target_col (useful for EP test setup).
    public fun empty_with_ep(ep_col: u8): Board {
        let mut board = empty();
        board.ep_target_col = option::some(ep_col);
        board
    }

    // ===== Move application =====

    /// Apply a move to the board, returning the new board state.
    ///
    /// This function handles the mechanical board update only — it does NOT
    /// validate legality. Callers (chess_rules) must validate before calling.
    ///
    /// Handles: simple moves, captures, en-passant captures, castling,
    /// pawn promotion, and flag bookkeeping (has_moved, ep_target_col).
    public fun apply_move(board: &Board, player: u8, from: Pos, to: Pos, promotion: u8): Board {
        let mut new_board = *board;
        let piece = piece_at(&new_board, from).destroy_some();
        let target = piece_at(&new_board, to);

        // EP opportunity expires every move by default. Pawn double-push sets it below.
        new_board.ep_target_col = option::none();

        // Start with the piece marked as having moved.
        let mut moved_piece = Piece {
            piece_type: piece.piece_type,
            color: piece.color,
            has_moved: true,
        };

        // --- Pawn special cases ---
        if (piece.piece_type == PAWN) {
            // Double push: record EP target column.
            let row_diff = if (to.row > from.row) {
                to.row - from.row
            } else {
                from.row - to.row
            };
            if (row_diff == 2) {
                new_board.ep_target_col = option::some(to.col);
            };

            // En-passant capture: pawn moves diagonally to an empty square,
            // meaning it's capturing the adjacent pawn that double-pushed.
            if (to.col != from.col && target.is_none()) {
                set_piece(&mut new_board, Pos { row: from.row, col: to.col }, option::none());
            };

            // Promotion: replace pawn with the promoted piece.
            if (promotion > 0) {
                moved_piece =
                    Piece {
                        piece_type: promotion,
                        color: player,
                        has_moved: true,
                    };
            };
        };

        // --- Castling: move the rook alongside the king ---
        if (piece.piece_type == KING) {
            let col_diff = if (to.col > from.col) {
                to.col - from.col
            } else {
                from.col - to.col
            };
            if (col_diff == 2) {
                // Kingside castle: rook from col 7 → col 5
                // Queenside castle: rook from col 0 → col 3
                let (rook_from_col, rook_to_col) = if (to.col > from.col) {
                    (H, F)
                } else {
                    (A, D)
                };
                let rook_from = Pos { row: from.row, col: rook_from_col };
                let rook_to = Pos { row: from.row, col: rook_to_col };
                let mut rook = piece_at(&new_board, rook_from).destroy_some();
                rook.has_moved = true;
                set_piece(&mut new_board, rook_from, option::none());
                set_piece(&mut new_board, rook_to, option::some(rook));
            };
        };

        // Place the piece and clear the origin square.
        set_piece(&mut new_board, to, option::some(moved_piece));
        set_piece(&mut new_board, from, option::none());

        new_board
    }

    // ===== Constants accessors (for use by other modules) =====

    public fun pawn_type(): u8 { PAWN }

    public fun rook_type(): u8 { ROOK }

    public fun knight_type(): u8 { KNIGHT }

    public fun bishop_type(): u8 { BISHOP }

    public fun queen_type(): u8 { QUEEN }

    public fun king_type(): u8 { KING }

    public fun white(): u8 { WHITE }

    public fun black(): u8 { BLACK }
}
