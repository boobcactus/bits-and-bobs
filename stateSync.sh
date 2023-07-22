#!/bin/bash

echo "Provide an RPC with port:"
read RPC
echo "Minus blocks:"
read MOD

CHAIN_ID=$(curl -s $RPC/block | jq -r .result.block.header.chain_id); \
LATEST_HEIGHT=$(curl -s $RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - $MOD)); \
TRUST_HASH=$(curl -s "$RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

# Chain list, must be updated with find_chain()
osmosis=".osmosisd"
stargaze=".starsd"
evmos=".evmosd"
gravity_bridge=".gravity"
aura=".aura"

find_chain() {
    COIN=""
    for value in "${CHAIN_ID[@]}"; do
        case $value in
            "osmosis-1")
                COIN="$osmosis"
                ;;
            "stargaze-1")
                COIN="$stargaze"
                ;;
            "evmos_9001-2")
                COIN="$evmos"
                ;;
            "gravity-bridge-3")
                COIN="$gravity_bridge"
                ;;
            "xstaxy-1")
                COIN="$aura"
                ;;
            *)
                echo "Unknown chain ID: $CHAIN_ID"
                ;;
        esac
    done
}
find_chain

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC,$RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/$COIN/config/config.toml

echo "Statesync info has been updated for $CHAIN_ID"
echo "Don't forget to disable statesync after completion!"
sleep 2
