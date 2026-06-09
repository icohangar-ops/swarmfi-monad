#!/usr/bin/env bash
set -euo pipefail

# Ensure Foundry (not Atlassian Forge) is on PATH
if ! command -v forge >/dev/null 2>&1 || forge --version 2>&1 | grep -qi atlassian; then
  echo "Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
  echo "Then re-run: ./setup.sh"
  exit 1
fi

cd "$(dirname "$0")"
forge install foundry-rs/forge-std --no-git
forge install OpenZeppelin/openzeppelin-contracts --no-git
forge build
forge test
