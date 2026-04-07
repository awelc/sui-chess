#[test_only]
/// Integration tests for chess game module: game lifecycle, betting,
/// resignation, and draw using test_scenario.
module sui_chess::chess_tests {
    use sui::{coin, sui::SUI, test_scenario::{Self, Scenario}};
    use sui_chess::{
        chess::{Self, Game},
        chess_board::{WHITE, BLACK, PAWN, E, F, G, B, C, D, H, A, sq}
    };

    // Test addresses.
    const WHITE_PLAYER: address = @0xA;
    const BLACK_PLAYER: address = @0xB;
    const STRANGER: address = @0xC;

    // 1 SUI in MIST.
    const ONE_SUI: u64 = 1_000_000_000;

    // ===== Helpers =====

    /// Create a lobby (needed by make_move, resign, offer_draw).
    fun create_lobby(scenario: &mut Scenario) {
        scenario.next_tx(WHITE_PLAYER);
        chess::create_lobby(scenario.ctx());
    }

    /// Create a game as White, locking `white_bet` MIST as a wager.
    fun create_game(scenario: &mut Scenario, white_bet: u64) {
        scenario.next_tx(WHITE_PLAYER);
        let bet = coin::mint_for_testing<SUI>(white_bet, scenario.ctx());
        chess::create_game(BLACK_PLAYER, bet, scenario.ctx());
    }

    /// Join a game as Black, locking `black_bet` MIST as a wager.
    fun join_game(scenario: &mut Scenario, black_bet: u64) {
        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        let bet = coin::mint_for_testing<SUI>(black_bet, scenario.ctx());
        chess::join_game(&mut game, bet, scenario.ctx());
        test_scenario::return_shared(game);
    }

    /// Create lobby + create + join a game with the given wager amounts.
    fun setup_active_game(scenario: &mut Scenario, white_bet: u64, black_bet: u64) {
        create_lobby(scenario);
        create_game(scenario, white_bet);
        join_game(scenario, black_bet);
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
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::make_move(
            &mut lobby,
            &mut game,
            from_file,
            from_rank,
            to_file,
            to_rank,
            promotion,
            scenario.ctx(),
        );
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);
    }

    // ===== Game creation tests =====

    #[test]
    /// Create a game and verify initial state: WAITING, white bet stored.
    fun test_create_game() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        create_game(&mut scenario, 5 * ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::WAITING());
        assert!(game.white_bet_value() == 5 * ONE_SUI);
        assert!(game.black_bet_value() == 0);
        assert!(game.current_turn() == WHITE());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Join game tests =====

    #[test]
    /// Black joins a game. Verify status=ACTIVE, both bets stored.
    fun test_join_game() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        create_game(&mut scenario, 5 * ONE_SUI);
        join_game(&mut scenario, 3 * ONE_SUI);

        scenario.next_tx(BLACK_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::ACTIVE());
        assert!(game.white_bet_value() == 5 * ONE_SUI);
        assert!(game.black_bet_value() == 3 * ONE_SUI);
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Stranger (not the designated opponent) tries to join.
    fun test_join_game_wrong_player() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        create_game(&mut scenario, ONE_SUI);

        scenario.next_tx(STRANGER);
        let mut game = scenario.take_shared<Game>();
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::join_game(&mut game, bet, scenario.ctx());
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Joining an already-active game should fail.
    fun test_join_game_already_active() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        scenario.next_tx(BLACK_PLAYER);
        let mut game = scenario.take_shared<Game>();
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::join_game(&mut game, bet, scenario.ctx());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Making moves tests =====

    #[test]
    /// White plays e2→e4. Verify board updated, turn toggled, move recorded.
    fun test_make_move() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.current_turn() == BLACK());
        assert!(game.move_count() == 1);
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
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        make_move(&mut scenario, BLACK_PLAYER, E(), 7, E(), 5, 0);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Stranger tries to make a move.
    fun test_make_move_not_a_player() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        make_move(&mut scenario, STRANGER, E(), 2, E(), 4, 0);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Move on a WAITING game (not yet active).
    fun test_make_move_game_not_active() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        create_game(&mut scenario, ONE_SUI);

        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        scenario.end();
    }

    // ===== Full game tests =====

    #[test]
    /// Scholar's mate: 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6?? 4.Qxf7#
    /// White wins, gets both bets.
    fun test_scholars_mate_payout() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, 5 * ONE_SUI, 3 * ONE_SUI);

        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);
        make_move(&mut scenario, BLACK_PLAYER, E(), 7, E(), 5, 0);
        make_move(&mut scenario, WHITE_PLAYER, F(), 1, C(), 4, 0);
        make_move(&mut scenario, BLACK_PLAYER, B(), 8, C(), 6, 0);
        make_move(&mut scenario, WHITE_PLAYER, D(), 1, H(), 5, 0);
        make_move(&mut scenario, BLACK_PLAYER, G(), 8, F(), 6, 0);
        make_move(&mut scenario, WHITE_PLAYER, H(), 5, F(), 7, 0);

        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::WHITE_WINS());
        assert!(game.white_bet_value() == 0);
        assert!(game.black_bet_value() == 0);
        test_scenario::return_shared(game);

        assert!(test_scenario::has_most_recent_for_address<coin::Coin<SUI>>(WHITE_PLAYER));

        scenario.end();
    }

    #[test]
    /// Different bet amounts: White bets 5 SUI, Black bets 3 SUI.
    /// White wins via resignation, gets 8 SUI total.
    fun test_different_bet_amounts() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, 5 * ONE_SUI, 3 * ONE_SUI);

        scenario.next_tx(BLACK_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut lobby, &mut game, scenario.ctx());
        assert!(game.status() == chess::WHITE_WINS());
        test_scenario::return_shared(lobby);
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
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, 2 * ONE_SUI, 2 * ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut lobby, &mut game, scenario.ctx());
        assert!(game.status() == chess::BLACK_WINS());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.next_tx(BLACK_PLAYER);
        let winnings = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(winnings.value() == 4 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, winnings);

        scenario.end();
    }

    #[test]
    /// Black resigns. White wins both bets.
    fun test_resign_black() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, 2 * ONE_SUI, 2 * ONE_SUI);

        scenario.next_tx(BLACK_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut lobby, &mut game, scenario.ctx());
        assert!(game.status() == chess::WHITE_WINS());
        test_scenario::return_shared(lobby);
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
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        scenario.next_tx(STRANGER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::resign(&mut lobby, &mut game, scenario.ctx());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Draw tests =====

    #[test]
    /// Both players offer draw. Each gets own bet back.
    fun test_draw_mutual() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, 5 * ONE_SUI, 3 * ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut lobby, &mut game, scenario.ctx());
        assert!(game.white_draw_offer());
        assert!(!game.black_draw_offer());
        assert!(game.status() == chess::ACTIVE());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.next_tx(BLACK_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut lobby, &mut game, scenario.ctx());
        assert!(game.status() == chess::DRAW());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.next_tx(WHITE_PLAYER);
        let white_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(white_coin.value() == 5 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, white_coin);

        scenario.next_tx(BLACK_PLAYER);
        let black_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(black_coin.value() == 3 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, black_coin);

        scenario.end();
    }

    #[test]
    /// Only White offers draw. Game stays ACTIVE.
    fun test_draw_one_sided() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut lobby, &mut game, scenario.ctx());
        assert!(game.status() == chess::ACTIVE());
        assert!(game.white_draw_offer());
        assert!(!game.black_draw_offer());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    /// White offers draw, then makes a move. Draw offer should be cleared.
    fun test_draw_offer_cleared_on_move() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);
        setup_active_game(&mut scenario, ONE_SUI, ONE_SUI);

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::offer_draw(&mut lobby, &mut game, scenario.ctx());
        assert!(game.white_draw_offer());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        make_move(&mut scenario, WHITE_PLAYER, E(), 2, E(), 4, 0);

        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(!game.white_draw_offer());
        test_scenario::return_shared(game);

        scenario.end();
    }

    // ===== Lobby tests =====

    #[test]
    /// Create an open game via the lobby. Verify it appears in open_games.
    fun test_create_open_game() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);

        // Create lobby.
        chess::create_lobby(scenario.ctx());

        // Create open game.
        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::create_open_game(&mut lobby, bet, scenario.ctx());
        assert!(chess::open_game_count(&lobby) == 1);
        test_scenario::return_shared(lobby);

        // Verify the game exists and is WAITING.
        scenario.next_tx(WHITE_PLAYER);
        let game = scenario.take_shared<Game>();
        assert!(game.status() == chess::WAITING());
        assert!(game.white_bet_value() == ONE_SUI);
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    /// Join an open game via the lobby. Verify it's removed from lobby and game is ACTIVE.
    fun test_join_open_game() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);

        chess::create_lobby(scenario.ctx());

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::create_open_game(&mut lobby, bet, scenario.ctx());
        test_scenario::return_shared(lobby);

        // Black (or any stranger) joins.
        scenario.next_tx(STRANGER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        let bet = coin::mint_for_testing<SUI>(2 * ONE_SUI, scenario.ctx());
        chess::join_open_game(&mut lobby, &mut game, bet, scenario.ctx());
        assert!(chess::open_game_count(&lobby) == 0);
        assert!(game.status() == chess::ACTIVE());
        assert!(game.black_bet_value() == 2 * ONE_SUI);
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.end();
    }

    #[test]
    /// Cancel an open game. Verify bet returned and game removed from lobby.
    fun test_cancel_open_game() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);

        chess::create_lobby(scenario.ctx());

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let bet = coin::mint_for_testing<SUI>(5 * ONE_SUI, scenario.ctx());
        chess::create_open_game(&mut lobby, bet, scenario.ctx());
        test_scenario::return_shared(lobby);

        // Creator cancels.
        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::cancel_open_game(&mut lobby, &mut game, scenario.ctx());
        assert!(chess::open_game_count(&lobby) == 0);
        assert!(game.status() == chess::DRAW());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        // Verify bet returned.
        scenario.next_tx(WHITE_PLAYER);
        let returned_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(returned_coin.value() == 5 * ONE_SUI);
        test_scenario::return_to_sender(&scenario, returned_coin);

        scenario.end();
    }

    #[test]
    #[expected_failure]
    /// Non-creator tries to cancel an open game.
    fun test_cancel_open_game_not_creator() {
        let mut scenario = test_scenario::begin(WHITE_PLAYER);

        chess::create_lobby(scenario.ctx());

        scenario.next_tx(WHITE_PLAYER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let bet = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
        chess::create_open_game(&mut lobby, bet, scenario.ctx());
        test_scenario::return_shared(lobby);

        // Stranger tries to cancel.
        scenario.next_tx(STRANGER);
        let mut lobby = scenario.take_shared<chess::Lobby>();
        let mut game = scenario.take_shared<Game>();
        chess::cancel_open_game(&mut lobby, &mut game, scenario.ctx());
        test_scenario::return_shared(lobby);
        test_scenario::return_shared(game);

        scenario.end();
    }
}
