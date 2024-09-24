// Copyright 2019-2023 Ferrum Inc.
// This file is part of Ferrum.

// Ferrum is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Ferrum is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ferrum.  If not, see <http://www.gnu.org/licenses/>

import child from 'child_process';

export const SECONDS = 1000;

export const BLOCK_TIME = 6 * SECONDS;

export const FERRUM_CHAIN_ENDPOINT = "ws://127.0.0.1:9933";

export const EVM_CHAIN_ENDPOINT = "https://bsc-testnet.publicnode.com";
export const HARDHAT_ACCOUNT_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
export const HARDHAT_ACCOUNT_PVT_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

export async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// a global variable to check if the node is already running or not.
// to avoid running multiple nodes with the same authority at the same time.
const __NODE_STATUS: {
  [authorityId: string]: {
    process: child.ChildProcess | null;
    isRunning: boolean;
  };
} = {
  alice: { isRunning: false, process: null },
  bob: { isRunning: false, process: null },
  evm: { isRunning: false, process: null },
};

export function startFerrumNode(authority: 'alice' | 'bob', config_file_path: string) {
  if (__NODE_STATUS[authority].isRunning) {
    return __NODE_STATUS[authority].process;
  }
  const gitRoot = child.execSync("git rev-parse --show-toplevel").toString().trim();
  const nodePath = `${gitRoot}/target/release/ferrum-network`;
  const ports = {
    alice: { ws: 9944, rpc: 9933, p2p: 30333 },
    bob: { ws: 9945, rpc: 9934, p2p: 30334 },
  };
  const proc = child.spawn(
    nodePath,
    [
      `--${authority}`,
      "--tmp",
      `--ws-port=${ports[authority].ws}`,
      `--rpc-port=${ports[authority].rpc}`,
      `--port=${ports[authority].p2p}`,
      `--config-file-path=.${config_file_path}`,
      ...(authority == "alice"
        ? ["--node-key", "0000000000000000000000000000000000000000000000000000000000000001"]
        : [
          "--bootnodes",
          `/ip4/127.0.0.1/tcp/${ports["alice"].p2p}/p2p/12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp`,
        ]),
    ],
    {
      cwd: gitRoot,
    }
  );

  __NODE_STATUS[authority].isRunning = true;
  __NODE_STATUS[authority].process = proc;
  sleep(10);
  console.log(`${authority} node started`);

  proc.on("close", (code) => {
    __NODE_STATUS[authority].isRunning = false;
    __NODE_STATUS[authority].process = null;
    console.log(`${authority} node exited with code ${code}`);
  });
  return proc;
}

export function startEVMNode() {
  console.log("starting evm node");
  if (__NODE_STATUS["evm"].isRunning) {
    return __NODE_STATUS["evm"].process;
  }

  const proc = child.spawn('npx', ['hardhat', 'node'], {
    cwd: process.cwd(),
    detached: true,
    stdio: "inherit"
  });

  __NODE_STATUS["evm"].isRunning = true;

  proc.on("close", (code) => {
    __NODE_STATUS["evm"].isRunning = false;
    __NODE_STATUS["evm"].process = null;
    console.log(`${"evm"} node exited with code ${code}`);
  });

  return proc;
}

export function deployQuantumPortal(network: string) {
  const proc = child.spawn('npx', ['hardhat', 'run', "--network", `${network}`, "../../quantum-portal-smart-contracts/scripts/quantumPortal/poc/deployQuantumPortal.ts"], {
    cwd: process.cwd(),
    detached: true,
    stdio: "inherit"
  });

  return proc;
}

export function deployMultiChainStaking(network: string, mode: string) {
  const proc = child.spawn(`MODE=${mode} npx`, ['hardhat', 'run', "--network", `${network}`, "../../quantum-portal-smart-contracts/scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts"], {
    cwd: process.cwd(),
    detached: true,
    stdio: "inherit"
  });

  return proc;
}