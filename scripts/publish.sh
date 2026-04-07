#!/bin/bash
# Publish the chess package to the active Sui network.
# Extracts the package ID and writes/updates it in .env.
# Safe to re-run — publishes a new version each time.
#
# Usage: ./publish.sh [network]
#   network: devnet, testnet, or mainnet (default: current active env)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOVE_DIR="$SCRIPT_DIR/../move"
ENV_FILE="$SCRIPT_DIR/.env"

# Switch to requested network if specified.
if [ -n "$1" ]; then
    sui client switch --env "$1" > /dev/null 2>&1 || {
        echo "Error: Could not switch to environment '$1'"
        exit 1
    }
fi

ACTIVE_NETWORK=$(sui client active-env)
echo "=== Publishing chess package ==="
echo "Network: $ACTIVE_NETWORK"

# Switch to white player (publisher).
if ! sui client switch --address white-player > /dev/null 2>&1; then
    echo "Error: 'white-player' address not found. Run setup-accounts.sh first."
    exit 1
fi
echo "Publisher: $(sui client active-address)"

# Remove stale publication files so republishing works.
rm -f "$MOVE_DIR"/Pub.*.toml
rm -f "$MOVE_DIR"/Published.toml

# Publish — capture text output to extract transaction digest.
echo ""
echo "Publishing..."
PUBLISH_TEXT=$(sui client publish "$MOVE_DIR" --gas-budget 500000000 -e "$ACTIVE_NETWORK" 2>&1)

# Extract transaction digest from text output.
TX_DIGEST=$(echo "$PUBLISH_TEXT" | grep "Transaction Digest:" | awk '{print $3}')

if [ -z "$TX_DIGEST" ]; then
    echo "Error: Could not find transaction digest."
    echo "$PUBLISH_TEXT"
    exit 1
fi

echo "Transaction: $TX_DIGEST"

# Query the transaction for structured JSON.
sleep 2  # wait for indexing
TX_JSON=$(sui client tx-block "$TX_DIGEST" --json 2>&1)

# Extract package ID.
PACKAGE_ID=$(echo "$TX_JSON" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

if [ -z "$PACKAGE_ID" ] || [ "$PACKAGE_ID" = "null" ]; then
    echo "Error: Could not extract package ID."
    echo "$TX_JSON" | head -20
    exit 1
fi

echo "Package: $PACKAGE_ID"

# Gas cost.
echo "Gas: $(echo "$TX_JSON" | jq -r '.effects.gasUsed | "\(.computationCost) compute + \(.storageCost) storage - \(.storageRebate) rebate"')"

# Update .env.
if [ -f "$ENV_FILE" ] && grep -q '^PACKAGE_ID=' "$ENV_FILE"; then
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|^PACKAGE_ID=.*|PACKAGE_ID=$PACKAGE_ID|" "$ENV_FILE"
    else
        sed -i "s|^PACKAGE_ID=.*|PACKAGE_ID=$PACKAGE_ID|" "$ENV_FILE"
    fi
else
    echo "PACKAGE_ID=$PACKAGE_ID" >> "$ENV_FILE"
fi

# Update frontend/.env.
FRONTEND_ENV="$SCRIPT_DIR/../frontend/.env"
ACTIVE_NETWORK=$(sui client active-env)
cat > "$FRONTEND_ENV" <<EOF
VITE_NETWORK=$ACTIVE_NETWORK
VITE_PACKAGE_ID=$PACKAGE_ID
EOF

echo ""
echo "=== $ENV_FILE ==="
cat "$ENV_FILE"
echo ""
echo "=== $FRONTEND_ENV ==="
cat "$FRONTEND_ENV"
echo ""
echo "Run ./test-game.sh to test."
