#!/bin/sh

set -e

echo "##### Running unit tests #####"

aptos move test \
  --package-dir move \
  --dev
