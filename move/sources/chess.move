/// On-chain chess game module — entry point for players.
///
/// ## How a game is played
///
/// 1. **White creates a game** (`create_game`), designating an opponent and
///    locking a bet (wager) of any amount in SUI.
/// 2. **Black joins** (`join_game`), locking their own bet. Bets can differ —
///    players may wager different amounts based on skill or confidence.
/// 3. **Players alternate moves** (`make_move`). Each move is validated on-chain
///    by `chess_rules` — illegal moves abort the transaction.
/// 4. **Game ends** by checkmate (automatic after a move), resignation (`resign`),
///    stalemate (automatic), or mutual draw agreement (`offer_draw`).
/// 5. **Bets are distributed**: the winner receives both bets. On a draw, each
///    player gets their own bet back.
///
/// Players pay gas fees for their own transactions. The Game is a Sui shared
/// object so both players can interact with it.
module sui_chess::chess {
    use sui::{balance::{Self, Balance}, coin::{Self, Coin}, event, sui::SUI};
    use sui_chess::chess_board::{Self, Board, Pos, WHITE, BLACK};

    // ===== Constants =====

    // Game end reasons for GameEnded event.
    const REASON_CHECKMATE: u8 = 0;
    const REASON_RESIGNATION: u8 = 1;
    const REASON_STALEMATE: u8 = 2;
    const REASON_DRAW_AGREEMENT: u8 = 3;

    // ===== Smart errors =====

    #[error]
    const EGameNotWaiting: vector<u8> = b"Game is not waiting for a player to join";
    #[error]
    const EGameNotActive: vector<u8> = b"Game is not active";
    #[error]
    const ENotYourTurn: vector<u8> = b"It is not your turn";
    #[error]
    const ENotAPlayer: vector<u8> = b"You are not a player in this game";
    #[error]
    const EWrongOpponent: vector<u8> = b"You are not the designated opponent";

    // ===== Structs =====

    /// The on-chain chess game. Created as a shared object so both players can interact.
    public struct Game has key {
        id: UID,
        board: Board,
        player_white: address,
        player_black: address,
        current_turn: u8,
        status: u8,
        moves: vector<MoveRecord>,
        white_bet: Balance<SUI>,
        black_bet: Balance<SUI>,
        white_draw_offer: bool,
        black_draw_offer: bool,
    }

    /// Compact record of a single move.
    public struct MoveRecord has copy, drop, store {
        from: Pos,
        to: Pos,
        promotion: u8,
    }

    // ===== Events =====

    public struct GameCreated has copy, drop {
        game_id: ID,
        white: address,
        black: address,
        white_bet: u64,
    }

    public struct GameJoined has copy, drop {
        game_id: ID,
        black: address,
        black_bet: u64,
    }

    public struct MoveMade has copy, drop {
        game_id: ID,
        player: address,
        from_file: u8,
        from_rank: u8,
        to_file: u8,
        to_rank: u8,
        is_check: bool,
        is_checkmate: bool,
        is_stalemate: bool,
    }

    public struct GameEnded has copy, drop {
        game_id: ID,
        winner: Option<address>,
        reason: u8,
    }

    public struct DrawOffered has copy, drop {
        game_id: ID,
        player: address,
    }

    // ===== Public functions =====

    /// White creates a new game, designating an opponent and locking a bet.
    public fun create_game(opponent: address, bet: Coin<SUI>, ctx: &mut TxContext) {
        let sender = ctx.sender();
        let game = Game {
            id: object::new(ctx),
            board: chess_board::new(),
            player_white: sender,
            player_black: opponent,
            current_turn: WHITE(),
            status: WAITING(),
            moves: vector::empty(),
            white_bet: coin::into_balance(bet),
            black_bet: balance::zero(),
            white_draw_offer: false,
            black_draw_offer: false,
        };

        event::emit(GameCreated {
            game_id: object::id(&game),
            white: sender,
            black: opponent,
            white_bet: balance::value(&game.white_bet),
        });

        transfer::share_object(game);
    }

    /// Black joins an existing game, locking a bet.
    public fun join_game(game: &mut Game, bet: Coin<SUI>, ctx: &mut TxContext) {
        assert!(game.status == WAITING(), EGameNotWaiting);
        assert!(ctx.sender() == game.player_black, EWrongOpponent);

        balance::join(&mut game.black_bet, coin::into_balance(bet));
        game.status = ACTIVE();

        event::emit(GameJoined {
            game_id: object::id(game),
            black: ctx.sender(),
            black_bet: balance::value(&game.black_bet),
        });
    }

    /// Make a chess move. Validates the move, updates the board, and checks for game end.
    public fun make_move(
        game: &mut Game,
        from_file: u8,
        from_rank: u8,
        to_file: u8,
        to_rank: u8,
        promotion: u8,
        ctx: &mut TxContext,
    ) {
        assert!(game.status == ACTIVE(), EGameNotActive);

        let sender = ctx.sender();
        let player = if (sender == game.player_white) {
            assert!(game.current_turn == WHITE(), ENotYourTurn);
            WHITE()
        } else if (sender == game.player_black) {
            assert!(game.current_turn == BLACK(), ENotYourTurn);
            BLACK()
        } else {
            abort ENotAPlayer
        };

        let from = chess_board::sq(from_file, from_rank);
        let to = chess_board::sq(to_file, to_rank);

        // Validate and apply the move (aborts if illegal).
        game.board = game.board.validate_and_apply_move(player, from, to, promotion);

        // Record the move.
        game.moves.push_back(MoveRecord { from, to, promotion });

        // Toggle turn.
        game.current_turn = if (player == WHITE()) { BLACK() } else { WHITE() };

        // Clear the mover's draw offer (making a move implicitly retracts it).
        if (player == WHITE()) {
            game.white_draw_offer = false;
        } else {
            game.black_draw_offer = false;
        };

        // Check for game-ending conditions.
        let opponent = game.current_turn;
        let is_check = game.board.is_in_check(opponent);
        let is_checkmate = is_check && game.board.is_checkmate(opponent);
        let is_stalemate = !is_check && game.board.is_stalemate(opponent);

        if (is_checkmate) {
            game.status = if (player == WHITE()) { WHITE_WINS() } else { BLACK_WINS() };
            resolve_game(game, ctx);
            event::emit(GameEnded {
                game_id: object::id(game),
                winner: option::some(sender),
                reason: REASON_CHECKMATE,
            });
        } else if (is_stalemate) {
            game.status = DRAW();
            resolve_game(game, ctx);
            event::emit(GameEnded {
                game_id: object::id(game),
                winner: option::none(),
                reason: REASON_STALEMATE,
            });
        };

        event::emit(MoveMade {
            game_id: object::id(game),
            player: sender,
            from_file,
            from_rank,
            to_file,
            to_rank,
            is_check,
            is_checkmate,
            is_stalemate,
        });
    }

    /// Resign the game. The opponent wins.
    public fun resign(game: &mut Game, ctx: &mut TxContext) {
        assert!(game.status == ACTIVE(), EGameNotActive);

        let sender = ctx.sender();
        if (sender == game.player_white) {
            game.status = BLACK_WINS();
        } else if (sender == game.player_black) {
            game.status = WHITE_WINS();
        } else {
            abort ENotAPlayer
        };

        resolve_game(game, ctx);

        event::emit(GameEnded {
            game_id: object::id(game),
            winner: option::some(if (sender == game.player_white) { game.player_black } else {
                game.player_white
            }),
            reason: REASON_RESIGNATION,
        });
    }

    /// Offer a draw. If both players have offered, the game is drawn.
    public fun offer_draw(game: &mut Game, ctx: &mut TxContext) {
        assert!(game.status == ACTIVE(), EGameNotActive);

        let sender = ctx.sender();
        if (sender == game.player_white) {
            game.white_draw_offer = true;
        } else if (sender == game.player_black) {
            game.black_draw_offer = true;
        } else {
            abort ENotAPlayer
        };

        if (game.white_draw_offer && game.black_draw_offer) {
            game.status = DRAW();
            resolve_game(game, ctx);
            event::emit(GameEnded {
                game_id: object::id(game),
                winner: option::none(),
                reason: REASON_DRAW_AGREEMENT,
            });
        } else {
            event::emit(DrawOffered {
                game_id: object::id(game),
                player: sender,
            });
        };
    }

    // ===== Internal helpers =====

    /// Distribute bets based on game result.
    /// Winner gets both bets. Draw returns each bet to its owner.
    fun resolve_game(game: &mut Game, ctx: &mut TxContext) {
        if (game.status == WHITE_WINS()) {
            let black_bet = balance::withdraw_all(&mut game.black_bet);
            balance::join(&mut game.white_bet, black_bet);
            let winnings = balance::withdraw_all(&mut game.white_bet);
            let coin = coin::from_balance(winnings, ctx);
            transfer::public_transfer(coin, game.player_white);
        } else if (game.status == BLACK_WINS()) {
            let white_bet = balance::withdraw_all(&mut game.white_bet);
            balance::join(&mut game.black_bet, white_bet);
            let winnings = balance::withdraw_all(&mut game.black_bet);
            let coin = coin::from_balance(winnings, ctx);
            transfer::public_transfer(coin, game.player_black);
        } else if (game.status == DRAW()) {
            let white_bet = balance::withdraw_all(&mut game.white_bet);
            if (balance::value(&white_bet) > 0) {
                let coin = coin::from_balance(white_bet, ctx);
                transfer::public_transfer(coin, game.player_white);
            } else {
                balance::destroy_zero(white_bet);
            };

            let black_bet = balance::withdraw_all(&mut game.black_bet);
            if (balance::value(&black_bet) > 0) {
                let coin = coin::from_balance(black_bet, ctx);
                transfer::public_transfer(coin, game.player_black);
            } else {
                balance::destroy_zero(black_bet);
            };
        };
    }

    // ===== Accessors (for tests) =====

    public fun status(game: &Game): u8 { game.status }

    public fun current_turn(game: &Game): u8 { game.current_turn }

    public fun board(game: &Game): &Board { &game.board }

    public fun white_bet_value(game: &Game): u64 { balance::value(&game.white_bet) }

    public fun black_bet_value(game: &Game): u64 { balance::value(&game.black_bet) }

    public fun move_count(game: &Game): u64 { game.moves.length() }

    public fun white_draw_offer(game: &Game): bool { game.white_draw_offer }

    public fun black_draw_offer(game: &Game): bool { game.black_draw_offer }

    // Status constant accessors.
    public fun WAITING(): u8 { 0 }

    public fun ACTIVE(): u8 { 1 }

    public fun WHITE_WINS(): u8 { 2 }

    public fun BLACK_WINS(): u8 { 3 }

    public fun DRAW(): u8 { 4 }
}
