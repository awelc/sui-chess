#!/bin/bash
# Integration test: play chess games on the active Sui network via CLI.
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

for var in PACKAGE_ID WHITE_ADDR BLACK_ADDR LOBBY_ID; do
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

GAS_BUDGET=10000000
HIGH_GAS_BUDGET=50000000
BET_AMOUNT=1000000      # 0.001 SUI — bet per game
MIN_TOTAL=50000000      # 0.05 SUI — minimum total balance to run all 3 scenarios
FAUCET_TIMEOUT=120      # seconds to wait for faucet (devnet only)
NETWORK=$(sui client active-env)
PASS=0
FAIL=0

# ===== Coin management =====

# Get total balance in MIST across all coins for the current address.
total_balance() {
    sui client gas --json 2>/dev/null | jq '[.[].mistBalance] | add // 0'
}

# Merge all coins into one using pay-all-sui with explicit input coins.
consolidate_coins() {
    local alias=$1
    sui client switch --address "$alias" > /dev/null 2>&1

    local coins
    coins=$(sui client gas --json 2>/dev/null)
    local count
    count=$(echo "$coins" | jq 'length')

    if [ "$count" -le 1 ]; then
        return 0
    fi

    echo "  $alias: merging $count coins into 1..."
    local addr
    addr=$(sui client active-address)

    # Build array of coin IDs for --input-coins.
    local coin_ids=()
    local i=0
    while [ "$i" -lt "$count" ]; do
        coin_ids+=($(echo "$coins" | jq -r ".[$i].gasCoinId"))
        i=$((i + 1))
    done

    sui client pay-all-sui \
        --input-coins "${coin_ids[@]}" \
        --recipient "$addr" \
        --gas-budget 5000000 > /dev/null 2>&1
    sleep 2
}

# Ensure the given address has enough total balance to run the tests.
# On devnet: requests CLI faucet if needed.
# On other networks: prints actionable instructions if insufficient.
ensure_funded() {
    local alias=$1
    sui client switch --address "$alias" > /dev/null 2>&1

    local balance
    balance=$(total_balance)

    if [ "$balance" -ge "$MIN_TOTAL" ]; then
        return 0
    fi

    if [ "$NETWORK" = "devnet" ]; then
        echo "  $alias: balance ${balance} MIST, need ${MIN_TOTAL}. Requesting faucet..."
        sui client faucet > /dev/null 2>&1 || true
        sleep 2
        sui client faucet > /dev/null 2>&1 || true

        local elapsed=0
        while [ "$elapsed" -lt "$FAUCET_TIMEOUT" ]; do
            sleep 5
            elapsed=$((elapsed + 5))
            balance=$(total_balance)
            if [ "$balance" -ge "$MIN_TOTAL" ]; then
                echo "  $alias: funded (${balance} MIST)"
                return 0
            fi
            echo "  $alias: waiting... (${balance} MIST, ${elapsed}s elapsed)"
        done
        echo "  ERROR: $alias not funded after ${FAUCET_TIMEOUT}s"
        return 1
    fi

    # Non-devnet: can't auto-fund.
    local addr
    addr=$(sui client active-address)
    echo ""
    echo "  ERROR: $alias has ${balance} MIST, need at least ${MIN_TOTAL} MIST."
    echo "  Request tokens at: https://faucet.sui.io/?address=$addr"
    echo "  Then re-run this script."
    return 1
}

# Prepare both players: consolidate, fund if needed, re-consolidate.
prepare_players() {
    echo "Preparing accounts..."
    consolidate_coins white-player
    consolidate_coins black-player
    ensure_funded white-player
    ensure_funded black-player
    # Re-consolidate in case faucet created new coins.
    consolidate_coins white-player
    consolidate_coins black-player
    echo ""
}

# ===== Transaction helpers =====

# Execute a sui client call and return the transaction digest.
sui_call() {
    local addr_alias=$1
    local func=$2
    shift 2
    local args=("$@")

    sui client switch --address "$addr_alias" > /dev/null 2>&1

    local output
    output=$(sui client call \
        --package "$PACKAGE_ID" \
        --module chess \
        --function "$func" \
        --args "${args[@]}" \
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

    local output
    output=$(sui client call \
        --package "$PACKAGE_ID" \
        --module chess \
        --function "$func" \
        --args "${args[@]}" \
        --gas-budget $HIGH_GAS_BUDGET 2>&1)

    echo "$output" | grep "Transaction Digest:" | awk '{print $3}'
}

# Query transaction for structured JSON.
tx_json() {
    local digest=$1
    sleep 1
    sui client tx-block "$digest" --json 2>&1
}

# Split off a small bet coin by self-transferring BET_AMOUNT via pay-sui.
# Works with a single coin (pay-sui uses the input coin for gas).
# Returns the newly created coin's object ID.
bet_coin() {
    local addr
    addr=$(sui client active-address)
    local coin_id
    coin_id=$(sui client gas --json 2>/dev/null | jq -r 'sort_by(-.mistBalance) | .[0].gasCoinId')

    local output
    output=$(sui client pay-sui \
        --input-coins "$coin_id" \
        --amounts $BET_AMOUNT \
        --recipients "$addr" \
        --gas-budget 5000000 \
        --json 2>&1)

    echo "$output" | jq -r '.objectChanges[] | select(.type == "created") | .objectId'
}

# Report gas cost.
report_gas() {
    local label=$1
    local json=$2
    local compute=$(echo "$json" | jq -r '.effects.gasUsed.computationCost')
    local total=$((compute / 1000000))
    echo "  Gas ($label): ${total}M MIST"
}

# Consolidate coins and check funding once before all scenarios.
prepare_players

# ===== Scenario 1: Create + join + one move =====

echo "--- Scenario 1: Create, join, make a move ---"

# White creates open game via lobby.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_open_game "$LOBBY_ID" "$(bet_coin)")
echo "[White] Created open game (tx: $DIGEST)"
JSON=$(tx_json "$DIGEST")
GAME_ID=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID"
report_gas "create_open_game" "$JSON"

# Black joins via lobby.
sui client switch --address black-player > /dev/null
DIGEST=$(sui_call black-player join_open_game "$LOBBY_ID" "$GAME_ID" "$(bet_coin)")
echo "[Black] Joined (tx: $DIGEST)"
JSON=$(tx_json "$DIGEST")
report_gas "join_open_game" "$JSON"

# White plays e2→e4.
DIGEST=$(sui_call white-player make_move "$LOBBY_ID" "$GAME_ID" 4 2 4 4 0)
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

# Create + join via lobby.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_open_game "$LOBBY_ID" "$(bet_coin)")
JSON=$(tx_json "$DIGEST")
GAME_ID2=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID2"

sui client switch --address black-player > /dev/null
sui_call black-player join_open_game "$LOBBY_ID" "$GAME_ID2" "$(bet_coin)" > /dev/null
echo "[Black] Joined"

# Play scholar's mate.
echo "[White] e2→e4"
sui_call white-player make_move "$LOBBY_ID" "$GAME_ID2" 4 2 4 4 0 > /dev/null
echo "[Black] e7→e5"
sui_call black-player make_move "$LOBBY_ID" "$GAME_ID2" 4 7 4 5 0 > /dev/null
echo "[White] Bf1→c4"
sui_call white-player make_move "$LOBBY_ID" "$GAME_ID2" 5 1 2 4 0 > /dev/null
echo "[Black] Nb8→c6"
sui_call black-player make_move "$LOBBY_ID" "$GAME_ID2" 1 8 2 6 0 > /dev/null
echo "[White] Qd1→h5"
sui_call white-player make_move "$LOBBY_ID" "$GAME_ID2" 3 1 7 5 0 > /dev/null
echo "[Black] Ng8→f6??"
sui_call black-player make_move "$LOBBY_ID" "$GAME_ID2" 6 8 5 6 0 > /dev/null

echo "[White] Qh5×f7# (CHECKMATE)"
DIGEST=$(sui_call_high_gas white-player make_move "$LOBBY_ID" "$GAME_ID2" 7 5 5 7 0)
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

# Create + join via lobby.
sui client switch --address white-player > /dev/null
DIGEST=$(sui_call white-player create_open_game "$LOBBY_ID" "$(bet_coin)")
JSON=$(tx_json "$DIGEST")
GAME_ID3=$(echo "$JSON" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Game"))) | .objectId')
echo "[White] Game: $GAME_ID3"

sui client switch --address black-player > /dev/null
sui_call black-player join_open_game "$LOBBY_ID" "$GAME_ID3" "$(bet_coin)" > /dev/null
echo "[Black] Joined"

# Black resigns.
echo "[Black] Resigning..."
DIGEST=$(sui_call black-player resign "$LOBBY_ID" "$GAME_ID3")
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
