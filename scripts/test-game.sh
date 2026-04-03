#!/bin/bash
# Integration test: play chess games on devnet via CLI.
# Sources .env for PACKAGE_ID, WHITE_ADDR, BLACK_ADDR.
#
# Usage: ./test-game.sh
#
# Prerequisites:
#   1. Run ./setup-accounts.sh (creates and funds accounts)
#   2. Run ./publish.sh (publishes package)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Run setup-accounts.sh and publish.sh first."
    exit 1
fi
source "$ENV_FILE"

for var in PACKAGE_ID WHITE_ADDR BLACK_ADDR; do
    if [ -z "${!var}" ]; then
        echo "Error: $var not set in $ENV_FILE"
        exit 1
    fi
done

echo "=== Chess Integration Test ==="
echo "Package:  $PACKAGE_ID"
echo "White:    $WHITE_ADDR"
echo "Black:    $BLACK_ADDR"
echo "Network:  $(sui client active-env)"
echo ""

GAS_BUDGET=50000000
HIGH_GAS_BUDGET=500000000
MIN_BALANCE=5000000000  # 5 SUI — minimum per coin to be considered "sufficient"
FAUCET_TIMEOUT=120      # seconds to wait for faucet
PASS=0
FAIL=0

# ===== Coin management =====

# Count coins with balance >= MIN_BALANCE for the current address.
count_sufficient_coins() {
    sui client gas --json 2>/dev/null | jq "[.[] | select(.mistBalance >= $MIN_BALANCE)] | length"
}

# Ensure the given address has at least 2 coins with >= 5 SUI each.
# Requests faucet and polls until funded or timeout.
ensure_funded() {
    local alias=$1
    sui client switch --address "$alias" > /dev/null 2>&1

    local sufficient
    sufficient=$(count_sufficient_coins)

    if [ "$sufficient" -ge 2 ]; then
        return 0
    fi

    echo "  $alias: only $sufficient coins with >= 5 SUI. Requesting faucet..."

    # Request faucet (twice for 2 coins).
    sui client faucet > /dev/null 2>&1 || true
    sleep 2
    sui client faucet > /dev/null 2>&1 || true

    # Poll until we have 2 sufficient coins or timeout.
    local elapsed=0
    while [ "$elapsed" -lt "$FAUCET_TIMEOUT" ]; do
        sleep 5
        elapsed=$((elapsed + 5))
        sufficient=$(count_sufficient_coins)
        if [ "$sufficient" -ge 2 ]; then
            echo "  $alias: funded ($sufficient coins with >= 5 SUI)"
            return 0
        fi
        echo "  $alias: waiting... ($sufficient sufficient coins, ${elapsed}s elapsed)"
    done

    echo "  ERROR: $alias not funded after ${FAUCET_TIMEOUT}s"
    return 1
}

# Ensure both players are funded. Call before each scenario.
ensure_both_funded() {
    echo "Checking funds..."
    ensure_funded white-player
    ensure_funded black-player
    echo ""
}

# ===== Transaction helpers =====

# Execute a sui client call and return the transaction digest.
# Automatically uses the last coin for gas (first coin free for bet).
sui_call() {
    local addr_alias=$1
    local func=$2
    shift 2
    local args=("$@")

    sui client switch --address "$addr_alias" > /dev/null 2>&1

    local gas_coin
    gas_coin=$(sui client gas --json 2>/dev/null | jq -r "[.[] | select(.mistBalance >= $MIN_BALANCE)] | .[-1].gasCoinId")

    local output
    output=$(sui client call \
        --package "$PACKAGE_ID" \
        --module chess \
        --function "$func" \
        --args "${args[@]}" \
        --gas "$gas_coin" \
        --gas-budget $GAS_BUDGET 2>&1)

    echo "$output" | grep "Transaction Digest:" | awk '{print $3}'
}

# Like sui_call but with higher gas budget (for checkmate moves).
sui_call_high_gas() {
    local addr_alias=$1
    local func=$2
    shift 2
    local args=("$@")

    sui client switch --address "$addr_alias" > /dev/null 2>&1

    local gas_coin
    gas_coin=$(sui client gas --json 2>/dev/null | jq -r "[.[] | select(.mistBalance >= $MIN_BALANCE)] | .[-1].gasCoinId")

    local output
    output=$(sui client call \
        --package "$PACKAGE_ID" \
        --module chess \
        --function "$func" \
        --args "${args[@]}" \
        --gas "$gas_coin" \
        --gas-budget $HIGH_GAS_BUDGET 2>&1)

    echo "$output" | grep "Transaction Digest:" | awk '{print $3}'
}

# Query transaction for structured JSON.
tx_json() {
    local digest=$1
    sleep 1
    sui client tx-block "$digest" --json 2>&1
}

# Get the first sufficient coin ID (for use as bet).
# Note: sui_call uses the LAST sufficient coin for gas. As long as ensure_funded
# guarantees >= 2 sufficient coins, bet and gas coins are always different.
bet_coin() {
    local coins
    coins=$(sui client gas --json 2>/dev/null | jq "[.[] | select(.mistBalance >= $MIN_BALANCE)]")
    local count
    count=$(echo "$coins" | jq 'length')
    if [ "$count" -lt 2 ]; then
        echo "ERROR: Need at least 2 coins with >= $MIN_BALANCE MIST, have $count" >&2
        return 1
    fi
    echo "$coins" | jq -r '.[0].gasCoinId'
}

# Report gas cost.
report_gas() {
    local label=$1
    local json=$2
    local compute=$(echo "$json" | jq -r '.effects.gasUsed.computationCost')
    local total=$((compute / 1000000))
    echo "  Gas ($label): ${total}M MIST"
}

# ===== Scenario 1: Create + join + one move =====

echo "--- Scenario 1: Create, join, make a move ---"
ensure_both_funded

# White creates game.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_game "$BLACK_ADDR" "$(bet_coin)")
echo "[White] Created game (tx: $DIGEST)"
JSON=$(tx_json "$DIGEST")
GAME_ID=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID"
report_gas "create_game" "$JSON"

# Black joins.
sui client switch --address black-player > /dev/null
DIGEST=$(sui_call black-player join_game "$GAME_ID" "$(bet_coin)")
echo "[Black] Joined (tx: $DIGEST)"
JSON=$(tx_json "$DIGEST")
report_gas "join_game" "$JSON"

# White plays e2→e4.
DIGEST=$(sui_call white-player make_move "$GAME_ID" 4 2 4 4 0)
echo "[White] e2→e4 (tx: $DIGEST)"
JSON=$(tx_json "$DIGEST")
report_gas "make_move" "$JSON"

IS_CHECK=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("MoveMade")) | .parsedJson.is_check')
echo "[Check] is_check=$IS_CHECK (expected: false)"

if [ "$IS_CHECK" = "false" ]; then
    echo "✓ Scenario 1 PASSED"
    PASS=$((PASS + 1))
else
    echo "✗ Scenario 1 FAILED"
    FAIL=$((FAIL + 1))
fi
echo ""

# ===== Scenario 2: Scholar's mate =====

echo "--- Scenario 2: Scholar's mate (7 moves) ---"
ensure_both_funded

# Create + join.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_game "$BLACK_ADDR" "$(bet_coin)")
JSON=$(tx_json "$DIGEST")
GAME_ID2=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID2"

sui client switch --address black-player > /dev/null
sui_call black-player join_game "$GAME_ID2" "$(bet_coin)" > /dev/null
echo "[Black] Joined"

# Play scholar's mate.
echo "[White] e2→e4"
sui_call white-player make_move "$GAME_ID2" 4 2 4 4 0 > /dev/null
echo "[Black] e7→e5"
sui_call black-player make_move "$GAME_ID2" 4 7 4 5 0 > /dev/null
echo "[White] Bf1→c4"
sui_call white-player make_move "$GAME_ID2" 5 1 2 4 0 > /dev/null
echo "[Black] Nb8→c6"
sui_call black-player make_move "$GAME_ID2" 1 8 2 6 0 > /dev/null
echo "[White] Qd1→h5"
sui_call white-player make_move "$GAME_ID2" 3 1 7 5 0 > /dev/null
echo "[Black] Ng8→f6??"
sui_call black-player make_move "$GAME_ID2" 6 8 5 6 0 > /dev/null

echo "[White] Qh5×f7# (CHECKMATE)"
DIGEST=$(sui_call_high_gas white-player make_move "$GAME_ID2" 7 5 5 7 0)
JSON=$(tx_json "$DIGEST")
report_gas "checkmate_move" "$JSON"

WINNER=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("GameEnded")) | .parsedJson.winner')
REASON=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("GameEnded")) | .parsedJson.reason' | cut -d. -f1)
IS_CHECKMATE=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("MoveMade")) | .parsedJson.is_checkmate')

echo "[Check] winner=$WINNER (expected: $WHITE_ADDR)"
echo "[Check] reason=$REASON (expected: 0 = checkmate)"
echo "[Check] is_checkmate=$IS_CHECKMATE (expected: true)"

if [ "$WINNER" = "$WHITE_ADDR" ] && [ "$REASON" = "0" ] && [ "$IS_CHECKMATE" = "true" ]; then
    echo "✓ Scenario 2 PASSED"
    PASS=$((PASS + 1))
else
    echo "✗ Scenario 2 FAILED"
    FAIL=$((FAIL + 1))
fi
echo ""

# ===== Scenario 3: Resignation =====

echo "--- Scenario 3: Resignation ---"
ensure_both_funded

# Create + join.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_game "$BLACK_ADDR" "$(bet_coin)")
JSON=$(tx_json "$DIGEST")
GAME_ID3=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID3"

sui client switch --address black-player > /dev/null
sui_call black-player join_game "$GAME_ID3" "$(bet_coin)" > /dev/null
echo "[Black] Joined"

# Black resigns.
echo "[Black] Resigning..."
DIGEST=$(sui_call black-player resign "$GAME_ID3")
JSON=$(tx_json "$DIGEST")
report_gas "resign" "$JSON"

WINNER=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("GameEnded")) | .parsedJson.winner')
REASON=$(echo "$JSON" | jq -r '.events[] | select(.type | contains("GameEnded")) | .parsedJson.reason' | cut -d. -f1)

echo "[Check] winner=$WINNER (expected: $WHITE_ADDR)"
echo "[Check] reason=$REASON (expected: 1 = resignation)"

if [ "$WINNER" = "$WHITE_ADDR" ] && [ "$REASON" = "1" ]; then
    echo "✓ Scenario 3 PASSED"
    PASS=$((PASS + 1))
else
    echo "✗ Scenario 3 FAILED"
    FAIL=$((FAIL + 1))
fi
echo ""

# ===== Summary =====

echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
    exit 1
fi
