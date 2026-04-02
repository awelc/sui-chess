#[test_only]
/// Tests for chess_board module: board initialization, piece placement,
/// and move application mechanics.
module sui_chess::chess_board_tests {
    use sui_chess::chess_board::{Self, sq};

    // Chess file constants (matching chess_board module's internal values).
    const A: u8 = 0;
    const B: u8 = 1;
    const C: u8 = 2;
    const D: u8 = 3;
    const E: u8 = 4;
    const F: u8 = 5;
    const G: u8 = 6;
    const H: u8 = 7;

    // ===== Board initialization tests =====

    #[test]
    /// Verify the starting position has exactly 16 white, 16 black, 32 empty squares.
    fun test_new_board_piece_count() {
        let board = chess_board::new();
        let squares = chess_board::squares(&board);
        let mut white_count: u64 = 0;
        let mut black_count: u64 = 0;
        let mut empty_count: u64 = 0;
        let mut i: u64 = 0;
        while (i < 64) {
            let sq = squares.borrow(i);
            if (sq.is_none()) {
                empty_count = empty_count + 1;
            } else {
                let piece = sq.borrow();
                if (piece.color() == chess_board::white()) {
                    white_count = white_count + 1;
                } else {
                    black_count = black_count + 1;
                };
            };
            i = i + 1;
        };
        assert!(white_count == 16);
        assert!(black_count == 16);
        assert!(empty_count == 32);
    }

    #[test]
    /// Verify white's back rank (rank 1) has R N B Q K B N R, all unmoved.
    ///     a  b  c  d  e  f  g  h
    /// 1 | R  N  B  Q  K  B  N  R |
    fun test_new_board_white_back_rank() {
        let board = chess_board::new();
        let expected_types = vector[
            chess_board::rook_type(),
            chess_board::knight_type(),
            chess_board::bishop_type(),
            chess_board::queen_type(),
            chess_board::king_type(),
            chess_board::bishop_type(),
            chess_board::knight_type(),
            chess_board::rook_type(),
        ];
        let mut file: u8 = 0;
        while (file < 8) {
            let piece = board.piece_at(sq(file, 1)).borrow();
            assert!(piece.kind() == *expected_types.borrow(file as u64));
            assert!(piece.color() == chess_board::white());
            assert!(!piece.has_moved());
            file = file + 1;
        };
    }

    #[test]
    /// Verify black's back rank (rank 8) has r n b q k b n r.
    ///     a  b  c  d  e  f  g  h
    /// 8 | r  n  b  q  k  b  n  r |
    fun test_new_board_black_back_rank() {
        let board = chess_board::new();
        let expected_types = vector[
            chess_board::rook_type(),
            chess_board::knight_type(),
            chess_board::bishop_type(),
            chess_board::queen_type(),
            chess_board::king_type(),
            chess_board::bishop_type(),
            chess_board::knight_type(),
            chess_board::rook_type(),
        ];
        let mut file: u8 = 0;
        while (file < 8) {
            let piece = board.piece_at(sq(file, 8)).borrow();
            assert!(piece.kind() == *expected_types.borrow(file as u64));
            assert!(piece.color() == chess_board::black());
            file = file + 1;
        };
    }

    #[test]
    /// Verify white pawns on rank 2 and black pawns on rank 7.
    ///     a  b  c  d  e  f  g  h
    /// 7 | p  p  p  p  p  p  p  p |  <- black pawns
    ///   | ...                     |
    /// 2 | P  P  P  P  P  P  P  P |  <- white pawns
    fun test_new_board_pawns() {
        let board = chess_board::new();
        let mut file: u8 = 0;
        while (file < 8) {
            let wp = board.piece_at(sq(file, 2)).borrow();
            assert!(wp.kind() == chess_board::pawn_type());
            assert!(wp.color() == chess_board::white());
            let bp = board.piece_at(sq(file, 7)).borrow();
            assert!(bp.kind() == chess_board::pawn_type());
            assert!(bp.color() == chess_board::black());
            file = file + 1;
        };
    }

    #[test]
    /// Verify ranks 3–6 are all empty in the starting position.
    ///     a  b  c  d  e  f  g  h
    /// 6 | .  .  .  .  .  .  .  . |
    /// 5 | .  .  .  .  .  .  .  . |
    /// 4 | .  .  .  .  .  .  .  . |
    /// 3 | .  .  .  .  .  .  .  . |
    fun test_new_board_empty_middle() {
        let board = chess_board::new();
        let mut rank: u8 = 3;
        while (rank <= 6) {
            let mut file: u8 = 0;
            while (file < 8) {
                assert!(board.is_empty(sq(file, rank)));
                file = file + 1;
            };
            rank = rank + 1;
        };
    }

    #[test]
    /// Verify new board has no en-passant target.
    fun test_new_board_no_ep() {
        let board = chess_board::new();
        assert!(board.ep_target_col().is_none());
    }

    #[test]
    /// Verify empty() creates a board with all 64 squares empty and no EP target.
    fun test_empty_board() {
        let board = chess_board::empty();
        let mut rank: u8 = 1;
        while (rank <= 8) {
            let mut file: u8 = 0;
            while (file < 8) {
                assert!(board.is_empty(sq(file, rank)));
                file = file + 1;
            };
            rank = rank + 1;
        };
        assert!(board.ep_target_col().is_none());
    }

    // ===== set_piece / piece_at tests =====

    #[test]
    /// Verify set_piece writes to the correct square and piece_at reads it back.
    /// Other squares should remain empty.
    fun test_set_and_get_piece() {
        let mut board = chess_board::empty();
        let queen = chess_board::new_piece(chess_board::queen_type(), chess_board::white());
        chess_board::set_piece(&mut board, sq(E, 4), option::some(queen));
        let read = board.piece_at(sq(E, 4)).borrow();
        assert!(read.kind() == chess_board::queen_type());
        assert!(read.color() == chess_board::white());
        assert!(board.is_empty(sq(D, 4)));
    }

    // ===== apply_move tests =====

    #[test]
    /// White pawn double-push from starting position: e2 → e4.
    /// Verifies: origin cleared, pawn at destination with has_moved flag,
    /// and ep_target_col set to E file.
    ///
    ///  Before:          After:
    ///     e                e
    /// 5 | . |          5 | . |
    /// 4 | . |          4 | P |  <- ep_target_col = E
    /// 3 | . |          3 | . |
    /// 2 | P |          2 | . |
    fun test_simple_pawn_advance() {
        let board = chess_board::new();
        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(E, 2),
            sq(E, 4),
            0,
        );
        assert!(new_board.is_empty(sq(E, 2)));
        let piece = new_board.piece_at(sq(E, 4)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::white());
        assert!(piece.has_moved());
        assert!(new_board.ep_target_col() == option::some(E));
    }

    #[test]
    /// White pawn single push: e2 → e3.
    /// Verifies: ep_target_col is NOT set (only double pushes set it).
    ///
    ///  Before:          After:
    ///     e                e
    /// 4 | . |          4 | . |
    /// 3 | . |          3 | P |  <- no EP target
    /// 2 | P |          2 | . |
    fun test_single_pawn_advance() {
        let board = chess_board::new();
        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(E, 2),
            sq(E, 3),
            0,
        );
        let piece = new_board.piece_at(sq(E, 3)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.has_moved());
        assert!(new_board.ep_target_col().is_none());
    }

    #[test]
    /// White pawn captures black pawn diagonally: e4 × f5.
    /// Verifies: captured piece replaced, origin cleared.
    ///
    ///  Before:          After:
    ///     e  f             e  f
    /// 5 | .  p |       5 | .  P |  <- white pawn captured black
    /// 4 | P  . |       4 | .  . |
    fun test_capture() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 4),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::white())),
        );
        chess_board::set_piece(
            &mut board,
            sq(F, 5),
            option::some(chess_board::new_piece(chess_board::pawn_type(), chess_board::black())),
        );

        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(E, 4),
            sq(F, 5),
            0,
        );
        let piece = new_board.piece_at(sq(F, 5)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::white());
        assert!(new_board.is_empty(sq(E, 4)));
    }

    #[test]
    /// En passant capture: white pawn on e5 captures black pawn on d5.
    /// Board's ep_target_col is set to D, indicating black's pawn
    /// on d5 just double-pushed and is capturable.
    /// White captures diagonally to d6, removing the black pawn from d5.
    ///
    ///  Before (ep_target_col=D):  After:
    ///     d  e                       d  e
    /// 6 | .  . |                 6 | P  . |  <- white pawn lands on d6
    /// 5 | p  P |                 5 | .  . |  <- black pawn on d5 removed
    /// 4 | .  . |                 4 | .  . |
    fun test_en_passant_capture() {
        let mut board = chess_board::empty_with_ep(D);
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

        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(E, 5),
            sq(D, 6),
            0,
        );
        let piece = new_board.piece_at(sq(D, 6)).borrow();
        assert!(piece.kind() == chess_board::pawn_type());
        assert!(piece.color() == chess_board::white());
        assert!(new_board.is_empty(sq(D, 5))); // captured pawn gone
        assert!(new_board.is_empty(sq(E, 5))); // origin cleared
        assert!(new_board.ep_target_col().is_none());
    }

    #[test]
    /// Pawn promotion: white pawn on a7 advances to a8, promoted to queen.
    /// Verifies: destination has a white queen (not pawn), marked as moved.
    ///
    ///  Before:          After:
    ///     a                a
    /// 8 | . |          8 | Q |  <- promoted!
    /// 7 | P |          7 | . |
    fun test_pawn_promotion() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(A, 7),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );

        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(A, 7),
            sq(A, 8),
            chess_board::queen_type(),
        );
        let piece = new_board.piece_at(sq(A, 8)).borrow();
        assert!(piece.kind() == chess_board::queen_type());
        assert!(piece.color() == chess_board::white());
        assert!(piece.has_moved());
    }

    #[test]
    /// White kingside castling: king e1 → g1, rook h1 → f1.
    /// Verifies: both pieces move, both marked as moved, original squares empty.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 1 | .  .  .  .  K  .  .  R |   1 | .  .  .  .  .  R  K  . |
    fun test_kingside_castling_white() {
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

        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(E, 1),
            sq(G, 1),
            0,
        );
        let k = new_board.piece_at(sq(G, 1)).borrow();
        assert!(k.kind() == chess_board::king_type());
        assert!(k.has_moved());
        let r = new_board.piece_at(sq(F, 1)).borrow();
        assert!(r.kind() == chess_board::rook_type());
        assert!(r.has_moved());
        assert!(new_board.is_empty(sq(E, 1)));
        assert!(new_board.is_empty(sq(H, 1)));
    }

    #[test]
    /// White queenside castling: king e1 → c1, rook a1 → d1.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 1 | R  .  .  .  K  .  .  . |   1 | .  .  K  R  .  .  .  . |
    fun test_queenside_castling_white() {
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

        let new_board = chess_board::apply_move(
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
        assert!(r.has_moved());
        assert!(new_board.is_empty(sq(E, 1)));
        assert!(new_board.is_empty(sq(A, 1)));
    }

    #[test]
    /// Black kingside castling: king e8 → g8, rook h8 → f8.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 8 | .  .  .  .  k  .  .  r |   8 | .  .  .  .  .  r  k  . |
    fun test_kingside_castling_black() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(H, 8),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );

        let new_board = chess_board::apply_move(
            &board,
            chess_board::black(),
            sq(E, 8),
            sq(G, 8),
            0,
        );
        let k = new_board.piece_at(sq(G, 8)).borrow();
        assert!(k.kind() == chess_board::king_type());
        assert!(k.color() == chess_board::black());
        let r = new_board.piece_at(sq(F, 8)).borrow();
        assert!(r.kind() == chess_board::rook_type());
        assert!(r.color() == chess_board::black());
    }

    #[test]
    /// Black queenside castling: king e8 → c8, rook a8 → d8.
    ///
    ///  Before:                         After:
    ///     a  b  c  d  e  f  g  h         a  b  c  d  e  f  g  h
    /// 8 | r  .  .  .  k  .  .  . |   8 | .  .  k  r  .  .  .  . |
    fun test_queenside_castling_black() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(E, 8),
            option::some(chess_board::new_piece(chess_board::king_type(), chess_board::black())),
        );
        chess_board::set_piece(
            &mut board,
            sq(A, 8),
            option::some(chess_board::new_piece(chess_board::rook_type(), chess_board::black())),
        );

        let new_board = chess_board::apply_move(
            &board,
            chess_board::black(),
            sq(E, 8),
            sq(C, 8),
            0,
        );
        let k = new_board.piece_at(sq(C, 8)).borrow();
        assert!(k.kind() == chess_board::king_type());
        let r = new_board.piece_at(sq(D, 8)).borrow();
        assert!(r.kind() == chess_board::rook_type());
    }

    #[test]
    /// Knight move from starting position: Nb1 → c3 (L-shape: +2 rows, +1 col).
    /// Verifies: knight moves, marked as moved, origin cleared, no EP target set.
    ///
    ///  Before:                    After:
    ///     a  b  c                    a  b  c
    /// 3 | .  .  . |              3 | .  .  N |  <- knight landed
    /// 2 | P  P  P |              2 | P  P  P |
    /// 1 | R  N  B |              1 | R  .  B |  <- knight gone
    fun test_knight_move() {
        let board = chess_board::new();
        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(B, 1),
            sq(C, 3),
            0,
        );
        let piece = new_board.piece_at(sq(C, 3)).borrow();
        assert!(piece.kind() == chess_board::knight_type());
        assert!(piece.color() == chess_board::white());
        assert!(piece.has_moved());
        assert!(new_board.is_empty(sq(B, 1)));
        assert!(new_board.ep_target_col().is_none());
    }

    #[test]
    /// EP target lifecycle across three moves:
    /// 1. White e2→e4: ep_target_col = some(E)
    /// 2. Black d7→d5: ep_target_col = some(D) (white's EP expired, black's set)
    /// 3. White Nb1→c3: ep_target_col = none (black's EP expired)
    ///
    /// This tests that ep_target_col resets every move and only persists for one turn.
    ///
    ///  Move 1 (white e2→e4):     Move 2 (black d7→d5):    Move 3 (white Nb1→c3):
    ///     d  e                      d  e                      d  e
    /// 5 | .  . |                5 | p  . |                5 | p  . |
    /// 4 | .  P |                4 | .  P |                4 | .  P |
    /// ep_target=E               ep_target=D                ep_target=none
    fun test_ep_target_lifecycle() {
        let board = chess_board::new();

        // Move 1: white e2→e4 — EP target set to E file.
        let board2 = board.apply_move(chess_board::white(), sq(E, 2), sq(E, 4), 0);
        assert!(board2.ep_target_col() == option::some(E));

        // Move 2: black d7→d5 — EP target now D file (white's expired).
        let board3 = board2.apply_move(chess_board::black(), sq(D, 7), sq(D, 5), 0);
        assert!(board3.ep_target_col() == option::some(D));

        // Move 3: white Nb1→c3 — no double push, EP target cleared.
        let board4 = board3.apply_move(chess_board::white(), sq(B, 1), sq(C, 3), 0);
        assert!(board4.ep_target_col().is_none());
    }

    #[test]
    /// Promotion to knight (underpromotion): white pawn d7 → d8=N.
    /// Verifies promotion works for pieces other than queen.
    ///
    ///  Before:          After:
    ///     d                d
    /// 8 | . |          8 | N |  <- promoted to knight
    /// 7 | P |          7 | . |
    fun test_promotion_to_knight() {
        let mut board = chess_board::empty();
        chess_board::set_piece(
            &mut board,
            sq(D, 7),
            option::some(
                chess_board::new_piece_with_flags(
                    chess_board::pawn_type(),
                    chess_board::white(),
                    true,
                ),
            ),
        );

        let new_board = chess_board::apply_move(
            &board,
            chess_board::white(),
            sq(D, 7),
            sq(D, 8),
            chess_board::knight_type(),
        );
        let piece = new_board.piece_at(sq(D, 8)).borrow();
        assert!(piece.kind() == chess_board::knight_type());
        assert!(piece.color() == chess_board::white());
    }
}
