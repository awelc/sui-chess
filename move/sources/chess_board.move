/// Board representation for on-chain chess.
///
/// The board is a `vector<Option<Piece>>` of 64 elements indexed by position.
/// Row 0 is white's back rank (a1–h1), row 7 is black's back rank (a8–h8).
/// Empty squares are `option::none()`, occupied squares are `option::some(piece)`.
///
/// Positions are represented as `Pos` structs. Use `sq(file, rank)` to create
/// from chess notation: `sq(E(), 2)` returns the position for square e2.
module sui_chess::chess_board {
    // Method aliases for Piece accessors (readable as piece.kind(), piece.color()).
    public use fun piece_kind as Piece.kind;
    public use fun piece_color as Piece.color;

    // Register chess_rules functions as methods on Board.
    public use fun sui_chess::chess_rules::validate_and_apply_move as Board.validate_and_apply_move;
    public use fun sui_chess::chess_rules::is_in_check as Board.is_in_check;
    public use fun sui_chess::chess_rules::is_checkmate as Board.is_checkmate;
    public use fun sui_chess::chess_rules::is_stalemate as Board.is_stalemate;
    public use fun sui_chess::chess_rules::has_any_playable_move as Board.has_any_playable_move;

    // ===== Errors =====

    const EIndexOutOfBounds: u64 = 0;

    // ===== Piece types =====

    public fun PAWN(): u8 { 1 }

    public fun ROOK(): u8 { 2 }

    public fun KNIGHT(): u8 { 3 }

    public fun BISHOP(): u8 { 4 }

    public fun QUEEN(): u8 { 5 }

    public fun KING(): u8 { 6 }

    // ===== Colors =====

    public fun WHITE(): u8 { 0 }

    public fun BLACK(): u8 { 1 }

    // ===== Chess files (column indices) =====

    public fun A(): u8 { 0 }

    public fun B(): u8 { 1 }

    public fun C(): u8 { 2 }

    public fun D(): u8 { 3 }

    public fun E(): u8 { 4 }

    public fun F(): u8 { 5 }

    public fun G(): u8 { 6 }

    public fun H(): u8 { 7 }

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
        /// White king position.
        white_king_pos: Pos,
        /// Black king position.
        black_king_pos: Pos,
        /// Positions of all white pieces.
        white_pieces: vector<Pos>,
        /// Positions of all black pieces.
        black_pieces: vector<Pos>,
    }

    // ===== Position constructors and accessors =====

    /// Convert chess file (A..H) + rank (1..8) to a board position.
    /// Example: `sq(E(), 2)` returns the position for square e2.
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
    /// Automatically updates king positions and piece lists.
    public fun set_piece(board: &mut Board, p: Pos, piece: Option<Piece>) {
        let idx = (p.row as u64) * 8 + (p.col as u64);
        assert!(idx < 64, EIndexOutOfBounds);

        // Remove old piece at this position from its piece list (handles captures + clears).
        let old = board.squares.borrow(idx);
        if (old.is_some()) {
            let old_pc = old.borrow();
            let old_list = if (old_pc.color == WHITE()) {
                &mut board.white_pieces
            } else {
                &mut board.black_pieces
            };
            vector_remove(old_list, &p);
        };

        *board.squares.borrow_mut(idx) = piece;

        if (piece.is_some()) {
            let pc = piece.borrow();
            // Update king position cache.
            if (pc.piece_type == KING()) {
                if (pc.color == WHITE()) {
                    board.white_king_pos = p;
                } else {
                    board.black_king_pos = p;
                };
            };
            // Add to piece list.
            let list = if (pc.color == WHITE()) {
                &mut board.white_pieces
            } else {
                &mut board.black_pieces
            };
            list.push_back(p);
        };
    }

    /// True if the square at the given position has no piece.
    public fun is_empty(board: &Board, p: Pos): bool {
        piece_at(board, p).is_none()
    }

    /// Borrow the raw squares vector.
    public fun squares(board: &Board): &vector<Option<Piece>> {
        &board.squares
    }

    /// Column of the pawn eligible for en-passant capture, or none.
    public fun ep_target_col(board: &Board): Option<u8> {
        board.ep_target_col
    }

    /// Get the cached king position for a player.
    public fun king_pos(board: &Board, player: u8): Pos {
        if (player == WHITE()) { board.white_king_pos } else { board.black_king_pos }
    }

    /// Get the piece positions for a player.
    public fun pieces(board: &Board, player: u8): &vector<Pos> {
        if (player == WHITE()) { &board.white_pieces } else { &board.black_pieces }
    }

    // ===== Board construction =====

    /// Standard chess starting position.
    public fun new(): Board {
        let mut squares = vector::empty<Option<Piece>>();

        // Row 0: white back rank (a1..h1)
        squares.push_back(option::some(new_piece(ROOK(), WHITE())));
        squares.push_back(option::some(new_piece(KNIGHT(), WHITE())));
        squares.push_back(option::some(new_piece(BISHOP(), WHITE())));
        squares.push_back(option::some(new_piece(QUEEN(), WHITE())));
        squares.push_back(option::some(new_piece(KING(), WHITE())));
        squares.push_back(option::some(new_piece(BISHOP(), WHITE())));
        squares.push_back(option::some(new_piece(KNIGHT(), WHITE())));
        squares.push_back(option::some(new_piece(ROOK(), WHITE())));

        // Row 1: white pawns
        let mut i: u64 = 0;
        while (i < 8) {
            squares.push_back(option::some(new_piece(PAWN(), WHITE())));
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
            squares.push_back(option::some(new_piece(PAWN(), BLACK())));
            i = i + 1;
        };

        // Row 7: black back rank (a8..h8)
        squares.push_back(option::some(new_piece(ROOK(), BLACK())));
        squares.push_back(option::some(new_piece(KNIGHT(), BLACK())));
        squares.push_back(option::some(new_piece(BISHOP(), BLACK())));
        squares.push_back(option::some(new_piece(QUEEN(), BLACK())));
        squares.push_back(option::some(new_piece(KING(), BLACK())));
        squares.push_back(option::some(new_piece(BISHOP(), BLACK())));
        squares.push_back(option::some(new_piece(KNIGHT(), BLACK())));
        squares.push_back(option::some(new_piece(ROOK(), BLACK())));

        // Build piece position lists.
        let mut white_pieces = vector::empty<Pos>();
        let mut black_pieces = vector::empty<Pos>();
        let mut col: u8 = 0;
        while (col < 8) {
            white_pieces.push_back(Pos { row: 0, col }); // back rank
            white_pieces.push_back(Pos { row: 1, col }); // pawns
            black_pieces.push_back(Pos { row: 6, col }); // pawns
            black_pieces.push_back(Pos { row: 7, col }); // back rank
            col = col + 1;
        };

        Board {
            squares,
            ep_target_col: option::none(),
            white_king_pos: Pos { row: 0, col: E() },
            black_king_pos: Pos { row: 7, col: E() },
            white_pieces,
            black_pieces,
        }
    }

    /// Create an empty board (useful for setting up test positions).
    /// King positions default to e1/e8; set_piece auto-updates them when a king is placed.
    public fun empty(): Board {
        let mut squares = vector::empty<Option<Piece>>();
        let mut i: u64 = 0;
        while (i < 64) {
            squares.push_back(option::none());
            i = i + 1;
        };
        Board {
            squares,
            ep_target_col: option::none(),
            white_king_pos: Pos { row: 0, col: E() },
            black_king_pos: Pos { row: 7, col: E() },
            white_pieces: vector::empty(),
            black_pieces: vector::empty(),
        }
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
        if (piece.piece_type == PAWN()) {
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
        if (piece.piece_type == KING()) {
            let col_diff = if (to.col > from.col) {
                to.col - from.col
            } else {
                from.col - to.col
            };
            if (col_diff == 2) {
                // Kingside castle: rook from col H → col F
                // Queenside castle: rook from col A → col D
                let (rook_from_col, rook_to_col) = if (to.col > from.col) {
                    (H(), F())
                } else {
                    (A(), D())
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

        // Update cached king position if the king moved.
        if (piece.piece_type == KING()) {
            if (player == WHITE()) {
                new_board.white_king_pos = to;
            } else {
                new_board.black_king_pos = to;
            };
        };

        new_board
    }

    // ===== Internal helpers =====

    /// Remove the first occurrence of `val` from `v`. No-op if not found.
    fun vector_remove(v: &mut vector<Pos>, val: &Pos) {
        let len = v.length();
        let mut i: u64 = 0;
        while (i < len) {
            let item = v.borrow(i);
            if (item.row == val.row && item.col == val.col) {
                v.swap_remove(i);
                return
            };
            i = i + 1;
        };
    }
}
