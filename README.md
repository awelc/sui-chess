# Sui Chess

Two-player chess on the [Sui](https://sui.io) blockchain, with SUI betting and on-chain move validation. Built with Move smart contracts and a React/TypeScript frontend. Developed with the help of [Claude Code](https://claude.com/claude-code).

## Live demo

[https://dist-psi-one-77.vercel.app](https://dist-psi-one-77.vercel.app) — deployed on Sui testnet.

> **Note:** Sui testnet is periodically reset, which wipes all published packages. When this happens the live demo link will temporarily break until the contracts are republished. If the app shows a "dependent package not found" error, that's why.

## Features

- **Fully on-chain chess rules** — legal moves, check, checkmate, stalemate, castling, en passant, and pawn promotion are all validated by the Move smart contracts. The chain is authoritative; the frontend never validates moves locally.
- **Lobby matchmaking** — players advertise open games, others browse and join from any machine. No need to share game IDs or addresses.
- **SUI betting** — players wager SUI on the outcome. Winner takes both bets; draws return each bet. Bets can be asymmetric.
- **Private games** — alternatively, specify an opponent address directly for a private game.
- **Resume from lobby** — active games appear in "Your Games" so players can leave and return without losing context.
- **Visual move feedback** — pending moves highlight in green, rejected moves in red with a ghost piece showing the attempted destination.
- **Smart error messages** — illegal moves show human-readable errors like "This piece cannot move to the destination square".

## Architecture

```
┌──────────────────────┐       ┌────────────────────────┐       ┌──────────────────┐
│  React frontend      │       │  Sui blockchain        │       │  Slush wallet    │
│  (Vercel-hosted)     │◀─────▶│  (Move contracts)      │◀─────▶│  (signs txns)    │
└──────────────────────┘  gRPC └────────────────────────┘       └──────────────────┘
       ▲                              ▲
       │                              │
       ▼                              │
  getObject() polls                   │
  for Game + Lobby                    │
  state every 3s                      │
                                      │
                          All game state lives on-chain:
                          - Board (64-square vector)
                          - Bets (Balance<SUI>)
                          - Lobby (open + active games)
```

- **Move contracts** (`move/`) are the single source of truth: board state, bets, move validation, game lifecycle, and the matchmaking lobby all live on-chain.
- **Frontend** (`frontend/`) is a static React app built with Vite. It uses [`@mysten/dapp-kit`](https://sdk.mystenlabs.com/dapp-kit) for wallet connection (via [`ConnectModal`](https://sdk.mystenlabs.com/dapp-kit/components/ConnectModal) and `useSignAndExecuteTransaction`) and [`SuiGrpcClient`](https://sdk.mystenlabs.com/typescript/sui-client) from `@mysten/sui/grpc` for reading state and executing transactions. No JSON-RPC (deprecated) is used for chain interactions.
- **Integration scripts** (`scripts/`) publish contracts and run end-to-end tests on devnet/testnet.

## Code structure

```
sui-chess/
├── move/
│   ├── sources/
│   │   ├── chess.move         # Game module: create/join/move/resign/draw + Lobby
│   │   ├── chess_rules.move   # Legal-move validation, check/checkmate detection
│   │   └── chess_board.move   # Board representation and mechanical move application
│   ├── tests/
│   │   ├── chess_tests.move   # Game lifecycle, lobby, betting (20 tests)
│   │   ├── chess_rules_tests.move # Move validation, check/mate (60 tests)
│   │   └── chess_board_tests.move # Board operations (20 tests)
│   └── Move.toml
│
├── frontend/
│   ├── src/
│   │   ├── main.tsx           # Providers (QueryClient, SuiClient, Wallet)
│   │   ├── App.tsx            # Routes between lobby and active game
│   │   ├── config.ts          # Reads VITE_NETWORK, VITE_PACKAGE_ID, VITE_LOBBY_ID
│   │   ├── suiClient.ts       # Shared SuiGrpcClient instance
│   │   ├── components/
│   │   │   ├── GameLobby.tsx       # Open games list + create/join/cancel
│   │   │   ├── ChessGame.tsx       # Active game view (board + controls)
│   │   │   ├── ChessBoard.tsx      # 8×8 grid with click-to-move
│   │   │   └── PromotionPicker.tsx # Pawn promotion piece selector
│   │   ├── hooks/
│   │   │   ├── useLobby.ts         # Polls Lobby object for open/active games
│   │   │   ├── useGame.ts          # Polls a single Game object
│   │   │   └── useGameActions.ts   # Transaction builders for all game actions
│   │   └── lib/
│   │       └── boardParser.ts      # Parses on-chain Board into renderable grid
│   ├── .env.example
│   └── package.json
│
└── scripts/
    ├── setup-accounts.sh      # Creates test accounts, requests faucet (devnet)
    ├── publish.sh             # Publishes contracts + creates lobby, writes .env files
    └── test-game.sh           # End-to-end scenarios on the active network
```

## Prerequisites

- [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) (v1.x)
- Node.js 18+
- [`jq`](https://jqlang.github.io/jq/) (used by the scripts)
- A Sui wallet for browser use — e.g. [Slush](https://slush.app/)

## Setup

1. Clone the repo and install frontend dependencies:
   ```bash
   cd frontend
   npm install
   ```

2. Create test accounts and fund them (devnet):
   ```bash
   ./scripts/setup-accounts.sh devnet
   ```
   For testnet, pass `testnet` instead and request tokens at [https://faucet.sui.io](https://faucet.sui.io) for the addresses printed by the script.

3. Publish the contracts and create the lobby:
   ```bash
   ./scripts/publish.sh devnet
   ```
   Pass `testnet` instead for testnet. This publishes the package, creates the shared `Lobby` object, and writes `PACKAGE_ID` + `LOBBY_ID` to both `scripts/.env` and `frontend/.env` — the values correspond to whichever network you published to.

## Testing

### Move unit tests (100 tests)

```bash
cd move
sui move test -e devnet
```

The `-e devnet` flag is needed because `Move.toml` uses an empty chain ID for devnet (to avoid hardcoding the ID that changes on resets). If your CLI is switched to testnet or mainnet, you can omit it.

- `chess_rules_tests` (60) — per-piece move validation, check/checkmate/stalemate detection, castling, en passant, pawn promotion
- `chess_tests` (20) — game lifecycle, lobby, betting distribution, resignation, draw
- `chess_board_tests` (20) — board construction, piece placement, apply_move mechanics

### Integration tests on devnet/testnet

```bash
./scripts/test-game.sh
```

The script runs against whichever network the Sui CLI is currently switched to (`sui client active-env`), using the `PACKAGE_ID` and `LOBBY_ID` from `scripts/.env` — which point at whatever network you last ran `publish.sh` for. To test on a different network, switch the CLI and republish:

```bash
sui client switch --env testnet
./scripts/publish.sh testnet
./scripts/test-game.sh
```

It runs three scenarios:
1. Create a game via the lobby, join, make one move
2. Play scholar's mate and verify checkmate + bet payout
3. Create a game and resign, verify winner gets both bets

## Frontend

Run the app locally:

```bash
cd frontend
npm run dev
```

Open the printed URL in a browser with a Sui wallet extension (Slush). Make sure your wallet is on the same network as `VITE_NETWORK` in `frontend/.env`.

To play a full game you need two wallet accounts — one creates an open game, the other joins it via the lobby. The accounts can be in different browser profiles or on different machines; both clients see the board update via 3-second polling.

## Deployment

### Contracts

Deploy to a specific network with:
```bash
./scripts/publish.sh testnet   # or devnet, mainnet
```

The script:
- Removes stale publication files
- Publishes the package to the specified network
- Calls `create_lobby` to mint the shared Lobby object
- Writes the resulting `PACKAGE_ID` and `LOBBY_ID` to `scripts/.env` and `frontend/.env`

### Frontend to Vercel

```bash
cd frontend
npm run build
npx vercel deploy --prod dist
```

The build bakes in `VITE_NETWORK`, `VITE_PACKAGE_ID`, and `VITE_LOBBY_ID` from `frontend/.env`. Vercel gives you a public URL that anyone with a Sui wallet can use.

## Gas costs

Checkmate detection is the most expensive operation in chess because it requires brute-forcing every legal move for every piece. Initial naive implementation cost ~110M MIST (~0.11 SUI) per checkmate move. After three optimization passes it's down to ~1M MIST — roughly a **100× reduction**:

1. **Cached king positions** — avoid scanning all 64 squares to find the king during check detection.
2. **Piece lists by color** — iterate ~16 pieces instead of 64 squares when enumerating legal moves.
3. **Smart candidate generation** — per piece type, generate only reachable squares (knight: 8, king: 10, sliders: walk rays) instead of trying all 64 destinations.

All other game actions (create, join, move, resign, draw) cost ~1M MIST each.

## License

MIT
