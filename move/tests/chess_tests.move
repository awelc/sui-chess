#[test_only]
/// Integration tests for chess game module: game lifecycle, betting,
/// resignation, draw, and fee withdrawal using test_scenario.
module sui_chess::chess_tests {
    use sui::{coin, sui::SUI, test_scenario::{Self, Scenario}};
    use sui_chess::{
        chess::{Self, Game, PublisherCap},
        chess_board::{WHITE, BLACK, PAWN, E, F, G, B, C, D, H, A, sq}
    };

    // Test addresses.
    const DEPLOYER: address = @0xDE;
    const WHITE_PLAYER: address = @0xA;
    const BLACK_PLAYER: address = @0xB;
    const STRANGER: address = @0xC;

    // 1 SUI in MIST.
    const ONE_SUI: u64 = 1_000_000_000;

    // ===== Helpers =====

    /// Create a game as White. Pays `fee` MIST as entry fee and locks `white_bet` MIST
    /// as the amount White is wagering on winning. Advances scenario for Black's turn.
    fun create_game(scenario: &mut Scenario, fee: u64, white_bet: u64) {
        scenario.next_tx(WHITE_PLAYER);
        let fee_coin = coin::mint_for_testing<SUI>(fee, scenario.ctx());
        let bet_coin = coin::mint_for_testing<SUI>(white_bet, scenario.ctx());
        chess::create_game(BLACK_PLAYER, fee_coin, bet_coin, scenario.ctx());
    }

    /// Join a game as Black. Pays `fee` MIST as entry fee and locks `black_bet` MIST
    /// as the amount Black is wagering on winning.
    fun join_game(scenario: &mut Scenario, fee: u64, black_bet: u64) {
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        let fee_coin = coin::mint_for_testing<SUI>(fee, scenario.ctx());
        let bet_coin = coin::mint_for_testing<SUI>(black_bet, scenario.ctx());
        chess::join_game(&mut game, fee_coin, bet_coin, scenario.ctx());
        test_scenario::return_shared(game);
    }

    /// Create + join a game. Both players pay `fee` MIST entry fee and lock their
    /// respective wager amounts (in MIST). Returns scenario ready for White's first move.
    fun setup_active_game(scenario: &mut Scenario, fee: u64, white_bet: u64, black_bet: u64) {
        create_game(scenario, fee, white_bet);
        join_game(scenario, fee, black_bet);
    }

    /// Make a move as the given player (file/rank coordinates).
    fun make_move(
        scenario: &mut Scenario,
        player: address,
        from_file: u8,
        from_rank: u8,
        to_file: u8,
        to_rank: u8,
        promotion: u8,
    ) {
        scenario.next_tx(player);
        let mut game = scenario.take_shared<Game>();
        chess::make_move(
            &mut game,
            from_file,
            from_rank,
            to_file,
            to_rank,
            promotion,
            scenario.ctx(),
        );
        test_scenario::return_shared(game);
    }

    // ===== Game creation tests =====

    #[test]
    /// Create a game and verify initial state: WAITING, white bet stored, fee pool = 1 SUI.
    fun test_create_game() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        create_game(&mut scenario, ONE_SUI, 5 * ONE_SUI);

        // Verify game state.
        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::WAITING());
        assert!(game.white_bet_value() == 5 * ONE_SUI);
        assert!(game.black_bet_value() == 0);
        assert!(game.fee_pool_value() == ONE_SUI);
        assert!(game.current_turn() == WHITE());
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Entry fee != 1 SUI should fail.
    fun test_create_game_wrong_fee() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        scenario.next_tx(WHITE_PLAYER);
        let fee = coin::mint_for_testing<SUI>(ONE_SUI / 2, scenario.ctx()); // 0.5 SUI
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::create_game(BLACK_PLAYER, fee, bet, scenario.ctx());
        scenario.end();
    }

    // ===== Join game tests =====

    #[test]
    /// Black joins a game. Verify status=ACTIVE, both bets stored, fee pool = 2 SUI.
    fun test_join_game() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        create_game(&mut scenario, ONE_SUI, 5 * ONE_SUI);
        join_game(&mut scenario, ONE_SUI, 3 * ONE_SUI);

        // Verify game state.
        scenario.next_tx(BLACK_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::ACTIVE());
        assert!(game.white_bet_value() == 5 * ONE_SUI);
        assert!(game.black_bet_value() == 3 * ONE_SUI);
        assert!(game.fee_pool_value() == 2 * ONE_SUI);
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Stranger (not the designated opponent) tries to join.
    fun test_join_game_wrong_player() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        create_game(&mut scenario, ONE_SUI, ONE_SUI);

        scenario.next_tx(STRANGER);
        let mut game = scenario.take_shared<Game>();
        let fee = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::join_game(&mut game, fee, bet, scenario.ctx());
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Joining an already-active game should fail.
    fun test_join_game_already_active() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        // Try joining again.
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        let fee = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::join_game(&mut game, fee, bet, scenario.ctx());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Making moves tests =====

    #[test]
    /// White plays e2→e4. Verify board updated, turn toggled, move recorded.
    fun test_make_move() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        // Verify state.
        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.current_turn() == BLACK());
        assert!(game.move_count() == 1);
        // Piece should be at e4.
        let piece = game.board().piece_at(sq(E(), 4));
        assert!(piece.is_some());
        assert!(piece.borrow().kind() == PAWN());
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Black tries to move on White's turn.
    fun test_make_move_wrong_turn() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        // Black tries to move first (it's White's turn).
        make_move(&mut scenario, BLACK_PLAYER, E(), 7, E(), 5, 0);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Stranger tries to make a move.
    fun test_make_move_not_a_player() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        make_move(&mut scenario, STRANGER, E(), 2, E(), 4, 0);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Move on a WAITING game (not yet active).
    fun test_make_move_game_not_active() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        create_game(&mut scenario, ONE_SUI, ONE_SUI);

        // Try to move before Black joins.
        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        scenario.end();
    }

    // ===== Full game tests =====

    #[test]
    /// Scholar's mate: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6?? 4.Qxf7#
    /// White wins, gets both bets.
    fun test_scholars_mate_payout() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, 5 * ONE_SUI, 3 * ONE_SUI);

        // 1. e4
        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);
        // 1... e5
        make_move(&mut scenario, BLACK_PLAYER, E(), 7, E(), 5, 0);
        // 2. Bc4
        make_move(&mut scenario, WHITE_PLAYER, F(), 1, C(), 4, 0);
        // 2... Nc6
        make_move(&mut scenario, BLACK_PLAYER, B(), 8, C(), 6, 0);
        // 3. Qh5
        make_move(&mut scenario, WHITE_PLAYER, D(), 1, H(), 5, 0);
        // 3... Nf6??
        make_move(&mut scenario, BLACK_PLAYER, G(), 8, F(), 6, 0);
        // 4. Qxf7# — checkmate
        make_move(&mut scenario, WHITE_PLAYER, H(), 5, F(), 7, 0);

        // Verify game ended.
        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::WHITE_WINS());
        // Bets should be zeroed out (distributed).
        assert!(game.white_bet_value() == 0);
        assert!(game.black_bet_value() == 0);
        test_scenario::return_shared(game);

        // Verify White received both bets (5 + 3 = 8 SUI).
        assert!(test_scenario::has_most_recent_for_address<coin::Coin<SUI>>(WHITE_PLAYER));

        scenario.end();
    }

    #[test]
    /// Different bet amounts: White bets 5 SUI, Black bets 3 SUI.
    /// White wins via resignation, gets 8 SUI total.
    fun test_different_bet_amounts() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, 5 * ONE_SUI, 3 * ONE_SUI);

        // Black resigns immediately.
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut game, scenario.ctx());
        assert!(game.status() == chess::WHITE_WINS());
        test_scenario::return_shared(game);

        scenario.next_tx(WHITE_PLAYER);
        let winnings = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(winnings.value() == 8 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, winnings);

        scenario.end();
    }

    // ===== Resignation tests =====

    #[test]
    /// White resigns. Black wins both bets.
    fun test_resign_white() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, 2 * ONE_SUI, 2 * ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut game, scenario.ctx());
        assert!(game.status() == chess::BLACK_WINS());
        test_scenario::return_shared(game);

        // Transfers are visible after next_tx.
        scenario.next_tx(BLACK_PLAYER);
        let winnings = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(winnings.value() == 4 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, winnings);

        scenario.end();
    }

    #[test]
    /// Black resigns. White wins both bets.
    fun test_resign_black() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, 2 * ONE_SUI, 2 * ONE_SUI);

        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut game, scenario.ctx());
        assert!(game.status() == chess::WHITE_WINS());
        test_scenario::return_shared(game);

        scenario.next_tx(WHITE_PLAYER);
        let winnings = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(winnings.value() == 4 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, winnings);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Stranger tries to resign.
    fun test_resign_not_a_player() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        scenario.next_tx(STRANGER);
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut game, scenario.ctx());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Draw tests =====

    #[test]
    /// Both players offer draw. Each gets own bet back.
    fun test_draw_mutual() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, 5 * ONE_SUI, 3 * ONE_SUI);

        // White offers draw.
        scenario.next_tx(WHITE_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut game, scenario.ctx());
        assert!(game.white_draw_offer());
        assert!(!game.black_draw_offer());
        assert!(game.status() == chess::ACTIVE()); // Not drawn yet.
        test_scenario::return_shared(game);

        // Black accepts (offers draw too).
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut game, scenario.ctx());
        assert!(game.status() == chess::DRAW());
        test_scenario::return_shared(game);

        // Transfers visible after next_tx. Check White got 5 SUI back.
        scenario.next_tx(WHITE_PLAYER);
        let white_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(white_coin.value() == 5 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, white_coin);

        // Check Black got 3 SUI back.
        scenario.next_tx(BLACK_PLAYER);
        let black_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(black_coin.value() == 3 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, black_coin);

        scenario.end();
    }

    #[test]
    /// Only White offers draw. Game stays ACTIVE.
    fun test_draw_one_sided() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut game, scenario.ctx());
        assert!(game.status() == chess::ACTIVE());
        assert!(game.white_draw_offer());
        assert!(!game.black_draw_offer());
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    /// White offers draw, then makes a move. Draw offer should be cleared.
    fun test_draw_offer_cleared_on_move() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        // White offers draw.
        scenario.next_tx(WHITE_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut game, scenario.ctx());
        assert!(game.white_draw_offer());
        test_scenario::return_shared(game);

        // White makes a move — draw offer should reset.
        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(!game.white_draw_offer());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Fee withdrawal tests =====

    #[test]
    /// Publisher withdraws fees after game ends.
    fun test_withdraw_fees() {
        let mut scenario = test_scenario::begin(DEPLOYER);

        // Init creates PublisherCap for deployer.
        chess::init_for_testing(scenario.ctx());

        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        // Black resigns to end the game.
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut game, scenario.ctx());
        test_scenario::return_shared(game);

        // Publisher withdraws fees.
        scenario.next_tx(DEPLOYER);
        let cap = scenario.take_from_sender<PublisherCap>();
        let mut game = scenario.take_shared<Game>();
        chess::withdraw_fees(&cap, &mut game, scenario.ctx());
        assert!(game.fee_pool_value() == 0);
        test_scenario::return_shared(game);
        test_scenario::return_to_sender(&scenario, cap);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Can't withdraw fees before game ends.
    fun test_withdraw_fees_game_not_over() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        chess::init_for_testing(scenario.ctx());
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI, ONE_SUI);

        // Try to withdraw while game is active.
        scenario.next_tx(DEPLOYER);
        let cap = scenario.take_from_sender<PublisherCap>();
        let mut game = scenario.take_shared<Game>();
        chess::withdraw_fees(&cap, &mut game, scenario.ctx());
        test_scenario::return_shared(game);
        test_scenario::return_to_sender(&scenario, cap);

        scenario.end();
    }
}
