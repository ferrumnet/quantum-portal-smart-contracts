#!/bin/bash
echo node running...

while [ true ]
do
  sleep 10
  npx hardhat run ./scripts/quantumPortal/poc/runNode.ts --network bsctestnet
done
