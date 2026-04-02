#[test_only]
/// Tests for chess_rules module: move validation, check detection,
/// checkmate, stalemate, and special moves (castling, en-passant, promotion).
module sui_chess::chess_rules_tests {
    use sui_chess::{chess_board::{Self, sq}, chess_rules};

    // Chess file constants.
    const A: u8 = 0;
    const B: u8 = 1;
    const C: u8 = 2;
    const D: u8 = 3;
    const E: u8 = 4;
    const F: u8 = 5;
    const G: u8 = 6;
    const H: u8 = 7;

    // ===== Pawn tests =====
    // Pawns are the only piece where color affects movement direction.
    // Each behavior is tested for both white and black, placed adjacent.

    // --- Forward one ---

    #[test]
    /// White pawn advances one square: e2 → e3.
    ///
    ///  Before:          After:
    ///     e                e
    /// 3 | . |          3 | P |  <- pawn moved here
    /// 2 | P |          2 | . |
    fun test_white_pawn_forward_one() {
        let board = chess_board::new();
        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 2),
            sq(E, 3),
            0,
        );
        let piece = new_board.piece_at(sq(E, 3)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(new_board.is_empty(sq(E, 2)));
    }

    #[test]
    /// Black pawn advances one square: d7 → d6.
    ///
    ///  Before:          After:
    ///     d                d
    /// 7 | p |          7 | . |
    /// 6 | . |          6 | p |  <- pawn moved here
    fun test_black_pawn_forward_one() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::black(),
            sq(D, 7),
            sq(D, 6),
            0,
        );
        let piece = new_board.piece_at(sq(D, 6)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::black());
    }

    // --- Forward two ---

    #[test]
    /// White pawn double-push from starting position: e2 → e4.
    ///
    ///  Before:          After:
    ///     e                e
    /// 4 | . |          4 | P |  <- pawn double-pushed
    /// 3 | . |          3 | . |
    /// 2 | P |          2 | . |
    fun test_white_pawn_forward_two() {
        let board = chess_board::new();
        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 2),
            sq(E, 4),
            0,
        );
        let piece = new_board.piece_at(sq(E, 4)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
    }

    #[test]
    /// Black pawn double-push from starting position: d7 → d5.
    ///
    ///  Before:          After:
    ///     d                d
    /// 7 | p |          7 | . |
    /// 6 | . |          6 | . |
    /// 5 | . |          5 | p |  <- pawn double-pushed
    fun test_black_pawn_forward_two() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::black(),
            sq(D, 7),
            sq(D, 5),
            0,
        );
        let piece = new_board.piece_at(sq(D, 5)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::black());
    }

    // --- Forward two blocked ---

    #[test]
    #[expected_failure]
    /// White pawn double-push blocked by piece on e3. e2 → e4 is illegal.
    ///
    ///  Position:
    ///     e
    /// 4 | . |
    /// 3 | n |  <- blocker prevents double-push
    /// 2 | P |
    fun test_white_pawn_forward_two_blocked() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 2),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 3),
            option::some(chess_board::new_piece(chess_board::knight_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 2), sq(E, 4), 0);
    }

    #[test]
    #[expected_failure]
    /// Black pawn double-push blocked by piece on d6. d7 → d5 is illegal.
    ///
    ///  Position:
    ///     d
    /// 7 | p |
    /// 6 | N |  <- blocker prevents double-push
    /// 5 | . |
    fun test_black_pawn_forward_two_blocked() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 6),
            option::some(chess_board::new_piece(chess_board::knight_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 7), sq(D, 5), 0);
    }

    // --- Forward two already moved ---

    #[test]
    #[expected_failure]
    /// White pawn that has already moved cannot double-push. e3 → e5 is illegal.
    ///
    ///  Position:
    ///     e
    /// 5 | . |  <- can't reach
    /// 4 | . |
    /// 3 | P |  <- already moved
    fun test_white_pawn_forward_two_already_moved() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 3),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 3), sq(E, 5), 0);
    }

    #[test]
    #[expected_failure]
    /// Black pawn that has already moved cannot double-push. d6 → d4 is illegal.
    ///
    ///  Position:
    ///     d
    /// 6 | p |  <- already moved
    /// 5 | . |
    /// 4 | . |  <- can't reach
    fun test_black_pawn_forward_two_already_moved() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 6),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 6), sq(D, 4), 0);
    }

    // --- Backward ---

    #[test]
    #[expected_failure]
    /// White pawn cannot move backward. e3 → e2 is illegal.
    ///
    ///  Position:
    ///     e
    /// 3 | P |  <- can't go backward
    /// 2 | . |
    fun test_white_pawn_backward() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 3),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 3), sq(E, 2), 0);
    }

    #[test]
    #[expected_failure]
    /// Black pawn cannot move backward (up). d6 → d7 is illegal.
    ///
    ///  Position:
    ///     d
    /// 7 | . |
    /// 6 | p |  <- can't go backward (up for black)
    fun test_black_pawn_backward() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 6),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 6), sq(D, 7), 0);
    }

    // --- Diagonal capture ---

    #[test]
    /// White pawn captures black piece diagonally: e4 × d5.
    ///
    ///  Before:          After:
    ///     d  e             d  e
    /// 5 | p  . |       5 | P  . |  <- white captured black
    /// 4 | .  P |       4 | .  . |
    fun test_white_pawn_diagonal_capture() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 5),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 4),
            sq(D, 5),
            0,
        );
        let piece = new_board.piece_at(sq(D, 5)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::white());
    }

    #[test]
    /// Black pawn captures white piece diagonally: d5 × e4.
    ///
    ///  Before:          After:
    ///     d  e             d  e
    /// 5 | p  . |       5 | .  . |
    /// 4 | .  P |       4 | .  p |  <- black captured white
    fun test_black_pawn_diagonal_capture() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 5),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::black(),
            sq(D, 5),
            sq(E, 4),
            0,
        );
        let piece = new_board.piece_at(sq(E, 4)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::black());
    }

    // --- Diagonal to empty ---

    #[test]
    #[expected_failure]
    /// White pawn cannot move diagonally to empty square. e4 → d5 is illegal.
    ///
    ///  Position:
    ///     d  e
    /// 5 | .  . |  <- empty, can't move diagonally
    /// 4 | .  P |
    fun test_white_pawn_diagonal_to_empty() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 4), sq(D, 5), 0);
    }

    #[test]
    #[expected_failure]
    /// Black pawn cannot move diagonally to empty square. d5 → e4 is illegal.
    ///
    ///  Position:
    ///     d  e
    /// 5 | p  . |
    /// 4 | .  . |  <- empty, can't move diagonally
    fun test_black_pawn_diagonal_to_empty() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 5),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 5), sq(E, 4), 0);
    }

    // --- En-passant ---

    #[test]
    /// White en-passant: e5 captures d5 pawn that just double-pushed (ep=D).
    ///
    ///  Before (ep=D):      After:
    ///     d  e                d  e
    /// 6 | .  . |          6 | P  . |  <- white lands on d6
    /// 5 | p  P |          5 | .  . |  <- black pawn removed
    fun test_white_pawn_en_passant() {
        let mut board = chess_board::empty_with_ep(D);
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 5),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 5),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 5),
            sq(D, 6),
            0,
        );
        let piece = new_board.piece_at(sq(D, 6)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::white());
        assert!(new_board.is_empty(sq(D, 5)));
    }

    #[test]
    /// Black en-passant: d4 captures e4 pawn that just double-pushed (ep=E).
    ///
    ///  Before (ep=E):      After:
    ///     d  e                d  e
    /// 4 | p  P |          4 | .  . |  <- white pawn removed
    /// 3 | .  . |          3 | .  p |  <- black lands on e3
    fun test_black_pawn_en_passant() {
        let mut board = chess_board::empty_with_ep(E);
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::black(),
            sq(D, 4),
            sq(E, 3),
            0,
        );
        let piece = new_board.piece_at(sq(E, 3)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::black());
        assert!(new_board.is_empty(sq(E, 4)));
    }

    // --- Promotion ---

    #[test]
    /// White pawn promotion: e7 → e8 promoted to queen.
    ///
    ///  Before:          After:
    ///     e                e
    /// 8 | . |          8 | Q |  <- promoted
    /// 7 | P |          7 | . |
    fun test_white_pawn_promotion() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 7),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 7),
            sq(E, 8),
            chess_board::queen_type(),
        );
        let piece = new_board.piece_at(sq(E, 8)).borrow();
        assert!(piece.kind() == chess_board::queen_type());
        assert!(piece.color() == chess_board::white());
    }

    #[test]
    /// Black pawn promotion: d2 → d1 promoted to queen.
    ///
    ///  Before:          After:
    ///     d                d
    /// 2 | p |          2 | . |
    /// 1 | . |          1 | q |  <- promoted
    fun test_black_pawn_promotion() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 2),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::black(),
            sq(D, 2),
            sq(D, 1),
            chess_board::queen_type(),
        );
        let piece = new_board.piece_at(sq(D, 1)).borrow();
        assert!(piece.kind() == chess_board::queen_type());
        assert!(piece.color() == chess_board::black());
    }

    // --- Promotion missing ---

    #[test]
    #[expected_failure]
    /// White pawn reaching rank 8 without promotion piece is illegal.
    ///
    ///  Position:
    ///     e
    /// 8 | . |  <- must specify promotion piece
    /// 7 | P |
    fun test_white_pawn_promotion_missing() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 7),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 7), sq(E, 8), 0);
    }

    #[test]
    #[expected_failure]
    /// Black pawn reaching rank 1 without promotion piece is illegal.
    ///
    ///  Position:
    ///     d
    /// 2 | p |
    /// 1 | . |  <- must specify promotion piece
    fun test_black_pawn_promotion_missing() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 2),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 2), sq(D, 1), 0);
    }

    // ===== Knight tests =====

    #[test]
    /// Knight on d4 can reach all 8 L-shaped destinations.
    ///
    ///  Position (x marks valid destinations):
    ///     b  c  d  e  f
    /// 6 | .  x  .  x  . |
    /// 5 | x  .  .  .  x |
    /// 4 | .  .  N  .  . |
    /// 3 | x  .  .  .  x |
    /// 2 | .  x  .  x  . |
    fun test_knight_all_l_shapes() {
        let destinations = vector[
            sq(C, 6),
            sq(E, 6),
            sq(B, 5),
            sq(F, 5),
            sq(B, 3),
            sq(F, 3),
            sq(C, 2),
            sq(E, 2),
        ];

        let mut i: u64 = 0;
        while (i < destinations.length()) {
            let mut board = chess_board::empty();
            chess_board::set_piece(
                &mut board,
                sq(A, 1),
                option::some(
                    chess_board::new_piece(chess_board::king_type(), chess_board::white()),
                ),
            );
            chess_board::set_piece(
                &mut board,
                sq(D, 4),
                option::some(
                    chess_board::new_piece_with_flags(
                        chess_board::knight_type(),
                        chess_board::white(),
                        true,
                    ),
                ),
            );
            chess_board::set_piece(
                &mut board,
                sq(H, 8),
                option::some(
                    chess_board::new_piece(chess_board::king_type(), chess_board::black()),
                ),
            );

            let dest = *destinations.borrow(i);
            let new_board = chess_rules::validate_and_apply_move(
                &board,
                chess_board::white(),
                sq(D, 4),
                dest,
                0,
            );
            let piece = new_board.piece_at(dest).borrow();
            assert!(piece.kind() == chess_board::knight_type());
            i = i + 1;
        };
    }

    #[test]
    #[expected_failure]
    /// Knight cannot move in a non-L-shape. d4 → d6 (straight) is illegal.
    ///
    ///  Position:
    ///     d
    /// 6 | . |  <- can't reach by L-shape
    /// 5 | . |
    /// 4 | N |
    fun test_knight_invalid_move() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::knight_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(D, 6), 0);
    }

    #[test]
    /// Knight can jump over pieces. Nb1 → c3 with pawns in the way.
    ///
    ///  Before:              After:
    ///     a  b  c              a  b  c
    /// 3 | .  .  . |       3 | .  .  N |  <- knight landed
    /// 2 | P  P  P |       2 | P  P  P |  <- pawns don't block
    /// 1 | R  N  B |       1 | R  .  B |  <- knight gone
    fun test_knight_jumps_over_pieces() {
        let board = chess_board::new();
        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(B, 1),
            sq(C, 3),
            0,
        );
        let piece = new_board.piece_at(sq(C, 3)).borrow();
        assert!(piece.kind() == chess_board::knight_type());
    }

    // ===== Bishop tests =====

    #[test]
    /// Bishop moves diagonally: c1 → e3 with clear path.
    ///
    ///  Before:              After:
    ///     c  d  e              c  d  e
    /// 3 | .  .  . |       3 | .  .  B |  <- bishop moved
    /// 2 | .  .  . |       2 | .  .  . |
    /// 1 | B  .  . |       1 | .  .  . |
    fun test_bishop_diagonal() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 1),
            option::some(chess_board::new_piece(chess_board::bishop_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(C, 1),
            sq(E, 3),
            0,
        );
        let piece = new_board.piece_at(sq(E, 3)).borrow();
        assert!(piece.kind() == chess_board::bishop_type());
    }

    #[test]
    #[expected_failure]
    /// Bishop cannot move straight. c1 → c3 is illegal.
    ///
    ///  Position:
    ///     c
    /// 3 | . |  <- can't reach in a straight line
    /// 2 | . |
    /// 1 | B |
    fun test_bishop_straight() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 1),
            option::some(chess_board::new_piece(chess_board::bishop_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(C, 1), sq(C, 3), 0);
    }

    #[test]
    #[expected_failure]
    /// Bishop path blocked: piece on d2 prevents c1 → e3.
    ///
    ///  Position:
    ///     c  d  e
    /// 3 | .  .  . |  <- can't reach
    /// 2 | .  p  . |  <- blocker on diagonal
    /// 1 | B  .  . |
    fun test_bishop_path_blocked() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 1),
            option::some(chess_board::new_piece(chess_board::bishop_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 2),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(C, 1), sq(E, 3), 0);
    }

    // ===== Rook tests =====

    #[test]
    /// Rook moves horizontally: a1 → d1.
    ///
    ///  Before:                  After:
    ///     a  b  c  d               a  b  c  d
    /// 1 | R  .  .  . |        1 | .  .  .  R |  <- rook slid right
    fun test_rook_horizontal() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(A, 1),
            sq(D, 1),
            0,
        );
        let piece = new_board.piece_at(sq(D, 1)).borrow();
        assert!(piece.kind() == chess_board::rook_type());
    }

    #[test]
    /// Rook moves vertically: a1 → a5.
    ///
    ///  Before:          After:
    ///     a                a
    /// 5 | . |          5 | R |  <- rook moved up
    /// 4 | . |          4 | . |
    /// 3 | . |          3 | . |
    /// 2 | . |          2 | . |
    /// 1 | R |          1 | . |
    fun test_rook_vertical() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(A, 1),
            sq(A, 5),
            0,
        );
        let piece = new_board.piece_at(sq(A, 5)).borrow();
        assert!(piece.kind() == chess_board::rook_type());
    }

    #[test]
    #[expected_failure]
    /// Rook path blocked: piece on a3 prevents a1 → a5.
    ///
    ///  Position:
    ///     a
    /// 5 | . |  <- can't reach
    /// 4 | . |
    /// 3 | p |  <- blocker
    /// 2 | . |
    /// 1 | R |
    fun test_rook_path_blocked() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 3),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(A, 1), sq(A, 5), 0);
    }

    // ===== Queen tests =====

    #[test]
    /// Queen moves both straight and diagonal.
    /// First d1 → d4 (straight), then d4 → g7 (diagonal).
    ///
    ///  Move 1 (straight):       Move 2 (diagonal):
    ///     d                        d        g
    /// 7 | . |                  7 | .  ...  Q |  <- queen moved diag
    /// 4 | . |  <- queen here   4 | .        . |
    /// 1 | Q |                  1 | .        . |
    fun test_queen_straight_and_diagonal() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 1),
            option::some(chess_board::new_piece(chess_board::queen_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(D, 1),
            sq(D, 4),
            0,
        );
        let piece = new_board.piece_at(sq(D, 4)).borrow();
        assert!(piece.kind() == chess_board::queen_type());

        let new_board2 = chess_rules::validate_and_apply_move(
            &new_board,
            chess_board::white(),
            sq(D, 4),
            sq(G, 7),
            0,
        );
        let piece2 = chess_board::piece_at(&new_board2, sq(G, 7)).borrow();
        assert!(piece2.kind() == chess_board::queen_type());
    }

    #[test]
    #[expected_failure]
    /// Queen cannot move in L-shape. d1 → e3 is illegal.
    ///
    ///  Position:
    ///     d  e
    /// 3 | .  . |  <- can't reach by L-shape
    /// 2 | .  . |
    /// 1 | Q  . |
    fun test_queen_invalid_l_shape() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 1),
            option::some(chess_board::new_piece(chess_board::queen_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 1), sq(E, 3), 0);
    }

    // ===== King tests =====

    #[test]
    /// King moves one square: e1 → e2.
    ///
    ///  Before:          After:
    ///     e                e
    /// 2 | . |          2 | K |  <- king moved
    /// 1 | K |          1 | . |
    fun test_king_one_square() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 1),
            sq(E, 2),
            0,
        );
        let piece = new_board.piece_at(sq(E, 2)).borrow();
        assert!(piece.kind() == chess_board::king_type());
    }

    #[test]
    #[expected_failure]
    /// King cannot move 2 squares without castling setup (no rook present).
    ///
    ///  Position:
    ///     e  f  g
    /// 1 | K  .  . |  <- no rook on h1, can't castle
    fun test_king_two_squares_no_castle() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 1), sq(G, 1), 0);
    }

    // ===== Castling tests =====

    #[test]
    /// White kingside castling: e1 → g1.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 1 | .  .  .  .  K  .  .  R |   1 | .  .  .  .  .  R  K  . |
    fun test_castling_white_kingside() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 1),
            sq(G, 1),
            0,
        );
        let k = new_board.piece_at(sq(G, 1)).borrow();
        assert!(k.kind() == chess_board::king_type());
        let r = new_board.piece_at(sq(F, 1)).borrow();
        assert!(r.kind() == chess_board::rook_type());
    }

    #[test]
    /// White queenside castling: e1 → c1.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 1 | R  .  .  .  K  .  .  . |   1 | .  .  K  R  .  .  .  . |
    fun test_castling_white_queenside() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 1),
            sq(C, 1),
            0,
        );
        let k = new_board.piece_at(sq(C, 1)).borrow();
        assert!(k.kind() == chess_board::king_type());
        let r = new_board.piece_at(sq(D, 1)).borrow();
        assert!(r.kind() == chess_board::rook_type());
    }

    #[test]
    #[expected_failure]
    /// Castling fails if king has already moved.
    ///
    ///  Position:
    ///     e  f  g  h
    /// 1 | K* .  .  R |  <- *king has_moved=true
    fun test_castling_king_moved() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::king_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 1), sq(G, 1), 0);
    }

    #[test]
    #[expected_failure]
    /// Castling fails if path is blocked: bishop on f1 blocks kingside castling.
    ///
    ///  Position:
    ///     e  f  g  h
    /// 1 | K  B  .  R |  <- bishop blocks path
    fun test_castling_path_blocked() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(F, 1),
            option::some(chess_board::new_piece(chess_board::bishop_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 1), sq(G, 1), 0);
    }

    #[test]
    #[expected_failure]
    /// Castling fails if king passes through attacked square.
    /// Black rook on f8 attacks f1.
    ///
    ///  Position:
    ///     a        e  f  g  h
    /// 8 | k  ...  .  r  .  . |  <- rook attacks f-file
    ///   | ...                 |
    /// 1 | .  ...  K  .  .  R |  <- king can't pass through f1
    fun test_castling_through_check() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(F, 8),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 1), sq(G, 1), 0);
    }

    // ===== Check detection tests =====

    #[test]
    /// Rook gives check on same row: white king on a1, black rook on e1.
    ///
    ///  Position:
    ///     a  b  c  d  e
    /// 1 | K  .  .  .  r |  <- rook attacks king along rank 1
    fun test_is_in_check() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        assert!(board.is_in_check(chess_board::white()));
    }

    #[test]
    /// King is not in check when no opponent piece attacks it.
    ///
    ///  Position:
    ///     a          h
    /// 1 | K |    8 | k |  <- kings far apart, safe
    fun test_not_in_check() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        assert!(!board.is_in_check(chess_board::white()));
    }

    #[test]
    #[expected_failure]
    /// King cannot move into an attacked square. Black rook attacks b-file.
    ///
    ///  Position:
    ///     a  b
    /// 8 | .  r |  <- attacks entire b-file
    ///   | ...  |
    /// 1 | K  . |  <- king can't go to b1
    fun test_move_into_check() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(B, 8),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(A, 1), sq(B, 1), 0);
    }

    // ===== Pin test =====

    #[test]
    #[expected_failure]
    /// Moving a pinned piece exposes the king. Bishop on c4 is pinned
    /// by black rook on e4 along rank 4. Moving bishop off rank exposes king.
    ///
    ///  Position:
    ///     a  b  c  d  e
    /// 4 | K  .  B  .  r |  <- bishop pinned along rank 4
    fun test_pinned_piece() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 4),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::bishop_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(C, 4), sq(D, 5), 0);
    }

    // ===== Checkmate tests =====

    #[test]
    /// Scholar's mate: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6?? 4.Qxf7#
    /// After Qxf7#, black is in checkmate.
    ///
    ///  Final position after Qxf7#:
    ///     a  b  c  d  e  f  g  h
    /// 8 | r  .  b  q  k  b  .  r |
    /// 7 | p  p  p  p  .  Q  p  p |  <- queen delivers mate on f7
    /// 6 | .  .  n  .  .  n  .  . |
    /// 5 | .  .  .  .  p  .  .  . |
    /// 4 | .  .  B  .  P  .  .  . |
    /// 3 | .  .  .  .  .  .  .  . |
    /// 2 | P  P  P  P  .  P  P  P |
    /// 1 | R  N  B  .  K  .  N  R |
    fun test_scholars_mate() {
        let board = chess_board::new();
        let b1 = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(E, 2),
            sq(E, 4),
            0,
        );
        let b2 = chess_rules::validate_and_apply_move(
            &b1,
            chess_board::black(),
            sq(E, 7),
            sq(E, 5),
            0,
        );
        let b3 = chess_rules::validate_and_apply_move(
            &b2,
            chess_board::white(),
            sq(F, 1),
            sq(C, 4),
            0,
        );
        let b4 = chess_rules::validate_and_apply_move(
            &b3,
            chess_board::black(),
            sq(B, 8),
            sq(C, 6),
            0,
        );
        let b5 = chess_rules::validate_and_apply_move(
            &b4,
            chess_board::white(),
            sq(D, 1),
            sq(H, 5),
            0,
        );
        let b6 = chess_rules::validate_and_apply_move(
            &b5,
            chess_board::black(),
            sq(G, 8),
            sq(F, 6),
            0,
        );
        let b7 = chess_rules::validate_and_apply_move(
            &b6,
            chess_board::white(),
            sq(H, 5),
            sq(F, 7),
            0,
        );

        assert!(b7.is_checkmate(chess_board::black()));
    }

    #[test]
    /// Back rank mate: white rook moves to d8, mating the black king on b8.
    /// Black king trapped behind own pawns on a7, b7, c7.
    ///
    ///  Before:                 After:
    ///     a  b  c  d              a  b  c  d
    /// 8 | .  k  .  . |       8 | .  k  .  R |  <- rook delivers mate
    /// 7 | p  p  p  . |       7 | p  p  p  . |  <- pawns trap king
    /// 1 | K  .  .  R |       1 | K  .  .  . |
    fun test_back_rank_mate() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(B, 8),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::king_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(B, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );

        let new_board = chess_rules::validate_and_apply_move(
            &board,
            chess_board::white(),
            sq(D, 1),
            sq(D, 8),
            0,
        );
        assert!(new_board.is_checkmate(chess_board::black()));
    }

    // ===== Stalemate test =====

    #[test]
    /// Stalemate: black king on a8, not in check, but no legal moves.
    /// White queen on b6 and white king on c8 trap the black king.
    ///
    ///  Position:
    ///     a  b  c
    /// 8 | k  .  K |  <- black king has no legal moves
    /// 7 | .  .  . |
    /// 6 | .  Q  . |  <- queen covers a7, b7, b8
    fun test_stalemate() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 8),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::king_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(B, 6),
            option::some(chess_board::new_piece(chess_board::queen_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(C, 8),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::king_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );

        assert!(!board.is_in_check(chess_board::black()));
        assert!(board.is_stalemate(chess_board::black()));
    }

    // ===== Own-piece capture test =====

    #[test]
    #[expected_failure]
    /// Cannot capture your own piece: white rook tries to take white pawn on a3.
    ///
    ///  Position:
    ///     a
    /// 3 | P |  <- own piece, can't capture
    /// 2 | . |
    /// 1 | R |
    fun test_cannot_capture_own_piece() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 3),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(A, 1), sq(A, 3), 0);
    }

    // ===== Rook illegal diagonal =====

    #[test]
    #[expected_failure]
    /// Rook cannot move diagonally. a1 → c3 is illegal.
    ///
    ///  Position:
    ///     a     c
    /// 3 | .  .  . |  <- can't reach diagonally
    /// 2 | .  .    |
    /// 1 | R       |
    fun test_rook_diagonal() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(A, 1), sq(C, 3), 0);
    }

    // ===== Invalid shape tests =====

    #[test]
    #[expected_failure]
    /// Bishop cannot move like a knight. d4 → e6 (L-shape) is illegal.
    fun test_bishop_like_knight() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::bishop_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(E, 6), 0);
    }

    #[test]
    #[expected_failure]
    /// Rook cannot move like a knight. d4 → e6 (L-shape) is illegal.
    fun test_rook_like_knight() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::rook_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(E, 6), 0);
    }

    #[test]
    #[expected_failure]
    /// Pawn cannot move sideways. e4 → f4 (horizontal) is illegal.
    ///
    ///  Position:
    ///     e  f
    /// 4 | P  . |  <- can't move sideways
    fun test_pawn_sideways() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(E, 4), sq(F, 4), 0);
    }

    // ===== Smoke tests =====
    // Each piece attempts an obviously illegal move — a destination no piece type
    // could legally reach (e.g., 3 forward + 3 sideways). Catches bugs where
    // validation accidentally accepts a nonsensical move shape.

    #[test]
    #[expected_failure]
    /// Smoke test: white pawn d2 → g5 (3 fwd + 3 right) is illegal for any piece.
    fun test_white_pawn_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 2),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 2), sq(G, 5), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: black pawn d7 → a4 (3 fwd + 3 left) is illegal for any piece.
    fun test_black_pawn_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 7),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::black(), sq(D, 7), sq(A, 4), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: knight d4 → g7 (3+3) is not an L-shape.
    fun test_knight_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::knight_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(G, 7), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: bishop d4 → g6 (3 fwd + 2 right) is not diagonal.
    fun test_bishop_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::bishop_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(G, 6), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: rook d4 → f6 (2+2) is neither straight nor diagonal.
    fun test_rook_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::rook_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(F, 6), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: queen d4 → f7 (3+2) is neither straight, diagonal, nor L-shape.
    fun test_queen_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::queen_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(F, 7), 0);
    }

    #[test]
    #[expected_failure]
    /// Smoke test: king d4 → f6 (2+2) is too far for a king.
    fun test_king_smoke() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::king_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(F, 6), 0);
    }

    // ===== Edge case tests =====

    #[test]
    #[expected_failure]
    /// Moving a piece to its own square is illegal.
    fun test_move_to_same_square() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::rook_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(D, 4), 0);
    }

    #[test]
    #[expected_failure]
    /// Moving from an empty square is illegal.
    fun test_move_empty_square() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(D, 5), 0);
    }

    #[test]
    #[expected_failure]
    /// White cannot move a black piece.
    fun test_move_opponent_piece() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 1),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(D, 4),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::rook_type(),
                    chess_board::black(),
                    true,
                ),
            ),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );

        board.validate_and_apply_move(chess_board::white(), sq(D, 4), sq(D, 6), 0);
    }
}
