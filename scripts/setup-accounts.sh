#!/bin/bash
# Create two test addresses for chess game testing and fund them via devnet faucet.
# Writes WHITE_ADDR and BLACK_ADDR to .env in this directory.
# Safe to re-run — skips address creation if aliases already exist.
#
# Usage: ./setup-accounts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "=== Setting up chess test accounts ==="

# Ensure devnet env exists and switch to it.
sui client new-env --alias devnet --rpc https://fullnode.devnet.sui.io:443 2>/dev/null || true
sui client switch --env devnet
echo "Network: $(sui client active-env)"

# Create white player address (skip if exists).
if sui client switch --address white-player 2>/dev/null; then
    WHITE_ADDR=$(sui client active-address)
    echo "White player already exists: $WHITE_ADDR"
else
    echo "Creating white player address..."
    WHITE_OUTPUT=$(sui client new-address ed25519 white-player 2>&1)
    WHITE_ADDR=$(echo "$WHITE_OUTPUT" | grep -oE '0x[a-f0-9]{64}' | head -1)
    echo "White: $WHITE_ADDR"
fi

# Create black player address (skip if exists).
if sui client switch --address black-player 2>/dev/null; then
    BLACK_ADDR=$(sui client active-address)
    echo "Black player already exists: $BLACK_ADDR"
else
    echo "Creating black player address..."
    BLACK_OUTPUT=$(sui client new-address ed25519 black-player 2>&1)
    BLACK_ADDR=$(echo "$BLACK_OUTPUT" | grep -oE '0x[a-f0-9]{64}' | head -1)
    echo "Black: $BLACK_ADDR"
fi

# Fund both accounts — request faucet twice each so they have 2 coins
# (one for bets, one for gas).
echo ""
echo "Funding accounts (2 faucet requests each for bet + gas coins)..."

sui client switch --address white-player > /dev/null
sui client faucet 2>&1 | grep -v "^$"
sleep 3
sui client faucet 2>&1 | grep -v "^$"

sui client switch --address black-player > /dev/null
sui client faucet 2>&1 | grep -v "^$"
sleep 3
sui client faucet 2>&1 | grep -v "^$"

# Write to .env.
echo "WHITE_ADDR=$WHITE_ADDR" > "$ENV_FILE"
echo "BLACK_ADDR=$BLACK_ADDR" >> "$ENV_FILE"

echo ""
echo "=== Written to $ENV_FILE ==="
cat "$ENV_FILE"
echo ""
echo "Wait ~30s for faucet funds, then verify with:"
echo "  sui client gas --address white-player"
echo "  sui client gas --address black-player"
