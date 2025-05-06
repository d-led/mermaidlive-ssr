#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

export MIX_ENV=prod

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"

mix setup
# redundant but works for multiple use-cases
mix deps.get --only prod
mix compile
mix phx.digest
mix release --force --overwrite
