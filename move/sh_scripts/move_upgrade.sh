#!/bin/sh

set -e

echo "##### Deploy module under a new object #####"

# Profile is the account you used to execute transaction
# Run "aptos init" to create the profile, then get the profile name from .aptos/config.yaml
PUBLISHER_PROFILE=testnet-profile-1

PUBLISHER_ADDR=0x$(aptos config show-profiles --profile=$PUBLISHER_PROFILE | grep 'account' | sed -n 's/.*"account": \"\(.*\)\".*/\1/p')

# to fill, you can find it from the output of deployment script
APTOGOTCHI_CONTRACT_OBJECT_ADDR="0xdeeedb2706c7e07c02f4c09a991b367c17c4a058dc52a2e5277dc145e8ce8264"
aptos move upgrade-object-package \
  --object-address $APTOGOTCHI_CONTRACT_OBJECT_ADDR \
  --named-addresses "aptogotchi_addr=$APTOGOTCHI_CONTRACT_OBJECT_ADDR"\
  --profile $PUBLISHER_PROFILE \
  --assume-yes
