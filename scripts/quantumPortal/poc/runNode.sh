#!/bin/bash
echo node running...

while [ true ]
do
  sleep 10
  npx hardhat run ./runNode.ts
done

