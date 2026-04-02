/// Chess move validation and game state detection.
///
/// This module enforces all chess rules: piece movement, captures, special moves
/// (castling, en-passant, promotion), check detection, checkmate, and stalemate.
/// All validation is on-chain since real money (bets) will be at stake.
module sui_chess::chess_rules {
    use sui_chess::chess_board::{
        Self,
        Board,
        Piece,
        Pos,
        PAWN,
        ROOK,
        KNIGHT,
        BISHOP,
        QUEEN,
        KING,
        WHITE,
        BLACK
    };

    // ===== Smart errors =====

    #[error]
    const EOutOfBounds: vector<u8> = b"Position is outside the board";
    #[error]
    const EPieceNotFound: vector<u8> = b"No piece at the source square";
    #[error]
    const ENotYourPiece: vector<u8> = b"The piece at source does not belong to the moving player";
    #[error]
    const EDestinationBlockedByOwnPiece: vector<u8> = b"Cannot capture your own piece";
    #[error]
    const EInvalidPieceMove: vector<u8> = b"This piece cannot move to the destination square";
    #[error]
    const EStillInCheck: vector<u8> = b"Move leaves the king in check";
    #[error]
    const EInvalidPromotion: vector<u8> =
        b"Invalid promotion: must promote when reaching last rank";

    // ===== Public API =====

    /// Validate a move and apply it, returning the new board state.
    /// Aborts with a descriptive error if the move is illegal.
    public fun validate_and_apply_move(
        board: &Board,
        player: u8,
        from: Pos,
        to: Pos,
        promotion: u8,
    ): Board {
        // Bounds check.
        assert!(from.row() < 8 && from.col() < 8, EOutOfBounds);
        assert!(to.row() < 8 && to.col() < 8, EOutOfBounds);

        // Source must have a piece belonging to the player.
        let from_sq = board.piece_at(from);
        assert!(from_sq.is_some(), EPieceNotFound);
        let piece = from_sq.borrow();
        assert!(piece.color() == player, ENotYourPiece);

        // Destination must not have own piece.
        let to_sq = board.piece_at(to);
        if (to_sq.is_some()) {
            assert!(to_sq.borrow().color() != player, EDestinationBlockedByOwnPiece);
        };

        // Validate move shape based on piece type.
        let pt = piece.kind();
        let valid = if (pt == PAWN()) {
            validate_pawn_move(board, piece, player, from, to)
        } else if (pt == KNIGHT()) {
            validate_knight_move(from, to)
        } else if (pt == BISHOP()) {
            validate_bishop_move(board, from, to)
        } else if (pt == ROOK()) {
            validate_rook_move(board, from, to)
        } else if (pt == QUEEN()) {
            validate_queen_move(board, from, to)
        } else if (pt == KING()) {
            validate_king_move(board, piece, player, from, to)
        } else {
            false
        };
        assert!(valid, EInvalidPieceMove);

        // Validate promotion: must promote when pawn reaches last rank, must not otherwise.
        let last_rank = if (player == WHITE()) { 7u8 } else { 0u8 };
        if (pt == PAWN() && to.row() == last_rank) {
            assert!(promotion >= ROOK() && promotion <= QUEEN(), EInvalidPromotion);
        } else {
            assert!(promotion == 0, EInvalidPromotion);
        };

        // Apply the move, then verify the player's king is not in check.
        let new_board = board.apply_move(player, from, to, promotion);
        assert!(!is_in_check(&new_board, player), EStillInCheck);

        new_board
    }

    /// Returns true if the given player's king is in check.
    public fun is_in_check(board: &Board, player: u8): bool {
        let king_pos = find_king(board, player);
        let opponent = if (player == WHITE()) { BLACK() } else {
            WHITE()
        };

        // Check if any opponent piece can attack the king's square.
        let squares = board.squares();
        let mut i: u64 = 0;
        while (i < 64) {
            let sq = squares.borrow(i);
            if (sq.is_some()) {
                let piece = sq.borrow();
                if (piece.color() == opponent) {
                    let attacker_pos = chess_board::sq((i % 8) as u8, (i / 8) as u8 + 1);
                    if (can_attack(board, piece, attacker_pos, king_pos)) {
                        return true
                    };
                };
            };
            i = i + 1;
        };
        false
    }

    /// Returns true if the given player is in checkmate (in check, no legal moves).
    public fun is_checkmate(board: &Board, player: u8): bool {
        is_in_check(board, player) && !has_any_playable_move(board, player)
    }

    /// Returns true if the given player is in stalemate (not in check, no legal moves).
    public fun is_stalemate(board: &Board, player: u8): bool {
        !is_in_check(board, player) && !has_any_playable_move(board, player)
    }

    // ===== Piece movement validators =====
    // Each returns true if the move shape is valid for that piece type.
    // They do NOT check whether the move leaves the king in check.

    /// Pawn movement: forward 1 or 2, diagonal capture, en-passant.
    fun validate_pawn_move(board: &Board, piece: &Piece, player: u8, from: Pos, to: Pos): bool {
        let from_row = from.row();
        let from_col = from.col();
        let to_row = to.row();
        let to_col = to.col();
        let col_diff = from_col.diff(to_col);

        // Direction: white moves up (+row), black moves down (-row).
        let (forward_one, start_rank) = if (player == WHITE()) {
            (from_row + 1, 1u8)
        } else {
            (from_row - 1, 6u8)
        };

        // Forward one square.
        if (to_col == from_col && to_row == forward_one) {
            return board.is_empty(to)
        };

        // Forward two squares from starting rank (unmoved pawn).
        if (to_col == from_col && from_row == start_rank && !piece.has_moved()) {
            let forward_two = if (player == WHITE()) { from_row + 2 } else {
                from_row - 2
            };
            if (to_row == forward_two) {
                // Both intermediate and destination squares must be empty.
                let intermediate = chess_board::sq(from_col, forward_one + 1);
                return board.is_empty(intermediate) && board.is_empty(to)
            };
        };

        // Diagonal move (capture or en-passant): one square diagonally forward.
        if (col_diff == 1 && to_row == forward_one) {
            // Normal capture: destination has an enemy piece.
            let to_sq = board.piece_at(to);
            if (to_sq.is_some()) {
                return to_sq.borrow().color() != player
            };
            // En-passant: destination is empty but matches ep_target_col.
            let ep = board.ep_target_col();
            if (ep.is_some() && *ep.borrow() == to_col) {
                return true
            };
        };

        false
    }

    /// Knight movement: L-shape (2+1 in any direction). No path checking.
    fun validate_knight_move(from: Pos, to: Pos): bool {
        let row_diff = from.row().diff(to.row());
        let col_diff = from.col().diff(to.col());
        (row_diff == 2 && col_diff == 1) || (row_diff == 1 && col_diff == 2)
    }

    /// Bishop movement: diagonal with clear path.
    fun validate_bishop_move(board: &Board, from: Pos, to: Pos): bool {
        let row_diff = from.row().diff(to.row());
        let col_diff = from.col().diff(to.col());
        // Must move diagonally (equal row and col distance, non-zero).
        if (row_diff == 0 || row_diff != col_diff) { return false };
        is_path_clear(board, from, to)
    }

    /// Rook movement: straight line (same row or same col) with clear path.
    fun validate_rook_move(board: &Board, from: Pos, to: Pos): bool {
        // Must move in a straight line (same row XOR same col).
        if (from.row() != to.row() && from.col() != to.col()) { return false };
        if (from.row() == to.row() && from.col() == to.col()) { return false };
        is_path_clear(board, from, to)
    }

    /// Queen movement: rook-like or bishop-like.
    fun validate_queen_move(board: &Board, from: Pos, to: Pos): bool {
        validate_rook_move(board, from, to) || validate_bishop_move(board, from, to)
    }

    /// King movement: one square in any direction, or castling.
    fun validate_king_move(board: &Board, piece: &Piece, player: u8, from: Pos, to: Pos): bool {
        let row_diff = from.row().diff(to.row());
        let col_diff = from.col().diff(to.col());

        // Normal king move: one square in any direction.
        if (row_diff <= 1 && col_diff <= 1 && (row_diff + col_diff) > 0) {
            return true
        };

        // Castling: king moves exactly 2 squares horizontally from starting position.
        if (row_diff == 0 && col_diff == 2) {
            return validate_castling(board, piece, player, from, to)
        };

        false
    }

    /// Castling validation. Checks all requirements:
    /// - King and rook unmoved
    /// - Path clear between king and rook
    /// - King not in check, doesn't pass through or land in check
    fun validate_castling(board: &Board, king: &Piece, player: u8, from: Pos, to: Pos): bool {
        // King must not have moved.
        if (king.has_moved()) { return false };

        // King must not be in check.
        if (is_in_check(board, player)) { return false };

        let from_row = from.row();
        let to_col = to.col();

        // Determine rook position based on castling direction.
        let (rook_col, step_dir_right) = if (to_col > from.col()) {
            (7u8, true) // Kingside
        } else {
            (0u8, false) // Queenside
        };

        // Rook must exist and not have moved.
        let rook_pos = chess_board::sq(rook_col, from_row + 1);
        let rook_sq = board.piece_at(rook_pos);
        if (rook_sq.is_none()) { return false };
        let rook = rook_sq.borrow();
        if (rook.kind() != ROOK() || rook.color() != player) {
            return false
        };
        if (rook.has_moved()) { return false };

        // All squares between king and rook must be empty.
        let king_col = from.col();
        let (start_col, end_col) = if (step_dir_right) {
            (king_col + 1, rook_col)
        } else {
            (rook_col + 1, king_col)
        };
        let mut c = start_col;
        while (c < end_col) {
            if (!board.is_empty(chess_board::sq(c, from_row + 1))) {
                return false
            };
            c = c + 1;
        };

        // King must not pass through or land on an attacked square.
        let pass_through_col = if (step_dir_right) { king_col + 1 } else { king_col - 1 };
        let pass_through = chess_board::sq(pass_through_col, from_row + 1);
        if (is_square_attacked(board, pass_through, player)) { return false };

        // Check the destination square.
        if (is_square_attacked(board, to, player)) { return false };

        true
    }

    // ===== Check and attack helpers =====

    /// Returns true if a piece at `attacker_pos` can attack `target_pos`.
    /// This checks raw attack capability (movement shape + path clearance) without
    /// considering whether the attack would leave the attacker's own king in check.
    fun can_attack(board: &Board, piece: &Piece, attacker_pos: Pos, target_pos: Pos): bool {
        let pt = piece.kind();
        if (pt == PAWN()) {
            // Pawns attack diagonally forward (one square).
            let col_diff = attacker_pos.col().diff(target_pos.col());
            if (col_diff != 1) { return false };
            let player = piece.color();
            let expected_row = if (player == WHITE()) {
                attacker_pos.row() + 1
            } else {
                attacker_pos.row() - 1
            };
            target_pos.row() == expected_row
        } else if (pt == KNIGHT()) {
            validate_knight_move(attacker_pos, target_pos)
        } else if (pt == BISHOP()) {
            validate_bishop_move(board, attacker_pos, target_pos)
        } else if (pt == ROOK()) {
            validate_rook_move(board, attacker_pos, target_pos)
        } else if (pt == QUEEN()) {
            validate_queen_move(board, attacker_pos, target_pos)
        } else if (pt == KING()) {
            let row_diff = attacker_pos.row().diff(target_pos.row());
            let col_diff = attacker_pos.col().diff(target_pos.col());
            row_diff <= 1 && col_diff <= 1 && (row_diff + col_diff) > 0
        } else {
            false
        }
    }

    /// Returns true if the given square is attacked by any piece of the opponent.
    fun is_square_attacked(board: &Board, target: Pos, player: u8): bool {
        let opponent = if (player == WHITE()) { BLACK() } else {
            WHITE()
        };
        let squares = board.squares();
        let mut i: u64 = 0;
        while (i < 64) {
            let sq = squares.borrow(i);
            if (sq.is_some()) {
                let piece = sq.borrow();
                if (piece.color() == opponent) {
                    let attacker_pos = chess_board::sq((i % 8) as u8, (i / 8) as u8 + 1);
                    if (can_attack(board, piece, attacker_pos, target)) {
                        return true
                    };
                };
            };
            i = i + 1;
        };
        false
    }

    /// Find the position of the given player's king. Aborts if king not found.
    fun find_king(board: &Board, player: u8): Pos {
        let squares = board.squares();
        let mut i: u64 = 0;
        while (i < 64) {
            let sq = squares.borrow(i);
            if (sq.is_some()) {
                let piece = sq.borrow();
                if (piece.kind() == KING() && piece.color() == player) {
                    return chess_board::sq((i % 8) as u8, (i / 8) as u8 + 1)
                };
            };
            i = i + 1;
        };
        abort 0 // King must always exist.
    }

    // ===== Legal move enumeration =====

    /// Returns true if the player has at least one playable move.
    /// A "playable" move is both a valid piece movement AND does not leave the player's king in check.
    /// Iterates all pieces, tries all candidate destinations, short-circuits on first playable move.
    fun has_any_playable_move(board: &Board, player: u8): bool {
        let squares = board.squares();
        let mut i: u64 = 0;
        while (i < 64) {
            let sq = squares.borrow(i);
            if (sq.is_some()) {
                let piece = sq.borrow();
                if (piece.color() == player) {
                    let from = chess_board::sq((i % 8) as u8, (i / 8) as u8 + 1);
                    if (has_playable_move(board, piece, player, from)) {
                        return true
                    };
                };
            };
            i = i + 1;
        };
        false
    }

    /// Check if a specific piece has any playable move from its position.
    /// Tests each candidate destination for valid piece movement shape,
    /// then verifies the resulting position doesn't leave the player's king in check.
    fun has_playable_move(board: &Board, piece: &Piece, player: u8, from: Pos): bool {
        let pt = piece.kind();

        let mut to_row: u8 = 0;
        while (to_row < 8) {
            let mut to_col: u8 = 0;
            while (to_col < 8) {
                let to = chess_board::sq(to_col, to_row + 1);

                // Skip if same square or own piece at destination.
                if (!(from.row() == to_row && from.col() == to_col)) {
                    let to_sq = board.piece_at(to);
                    let own_piece_at_dest = to_sq.is_some() && to_sq.borrow().color() == player;

                    if (!own_piece_at_dest) {
                        let shape_valid = if (pt == PAWN()) {
                            validate_pawn_move(board, piece, player, from, to)
                        } else if (pt == KNIGHT()) {
                            validate_knight_move(from, to)
                        } else if (pt == BISHOP()) {
                            validate_bishop_move(board, from, to)
                        } else if (pt == ROOK()) {
                            validate_rook_move(board, from, to)
                        } else if (pt == QUEEN()) {
                            validate_queen_move(board, from, to)
                        } else if (pt == KING()) {
                            validate_king_move(board, piece, player, from, to)
                        } else {
                            false
                        };

                        if (shape_valid) {
                            // For pawn promotion, try queen (any legal promotion suffices).
                            let promo = if (pt == PAWN()) {
                                let last_rank = if (player == WHITE()) { 7u8 } else {
                                    0u8
                                };
                                if (to_row == last_rank) { QUEEN() } else { 0u8 }
                            } else {
                                0u8
                            };
                            let new_board = board.apply_move(player, from, to, promo);
                            if (!is_in_check(&new_board, player)) {
                                return true
                            };
                        };
                    };
                };

                to_col = to_col + 1;
            };
            to_row = to_row + 1;
        };
        false
    }

    // ===== Utility helpers =====

    /// Check if all squares between `from` and `to` are empty (exclusive of both endpoints).
    /// Works for straight (rook), diagonal (bishop), or combined (queen) paths by stepping
    /// +1/0/-1 independently on each axis. Assumes from != to and a valid line direction.
    fun is_path_clear(board: &Board, from: Pos, to: Pos): bool {
        let from_row = from.row();
        let from_col = from.col();
        let to_row = to.row();
        let to_col = to.col();

        let mut cur_row = from_row;
        let mut cur_col = from_col;

        // Advance one step from `from` toward `to`.
        cur_row = step_toward(cur_row, to_row);
        cur_col = step_toward(cur_col, to_col);

        // Walk until we reach `to`, checking each intermediate square.
        while (cur_row != to_row || cur_col != to_col) {
            if (!board.is_empty(chess_board::sq(cur_col, cur_row + 1))) {
                return false
            };
            cur_row = step_toward(cur_row, to_row);
            cur_col = step_toward(cur_col, to_col);
        };
        true
    }

    /// Move `current` one step toward `target`. Returns current if already equal.
    fun step_toward(current: u8, target: u8): u8 {
        if (current < target) { current + 1 } else if (current > target) { current - 1 } else {
            current
        }
    }
}
