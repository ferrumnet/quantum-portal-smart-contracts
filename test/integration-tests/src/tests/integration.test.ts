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
// along with Ferrum.  If not, see <http://www.gnu.org/licenses/>.

import { BLOCK_TIME, startEVMNode, startFerrumNode, sleep, SECONDS, FERRUM_CHAIN_ENDPOINT, EVM_CHAIN_ENDPOINT, deployQuantumPortal } from "../utils/setup";
import { ChildProcess, execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

function importTest(name: string, path: string) {
	describe(name, function () {
		require(path);
	});
}

export let aliceNode: ChildProcess;
export let bobNode: ChildProcess;
export let evmNode: ChildProcess;

describe("Integration tests", function () {
  this.timeout(100 * BLOCK_TIME);
  this.slow(30 * BLOCK_TIME);

  before(async () => {
    const gitRoot = execSync("git rev-parse --show-toplevel").toString().trim();
    const tmpDir = `${gitRoot}/tmp`;
    if (fs.existsSync(tmpDir)) {
      fs.rmSync(tmpDir, { recursive: true });
    }
    aliceNode = startFerrumNode("alice", "alice_node_config.json")!;
    bobNode = startFerrumNode("bob", "bob_node_config.json")!;
    console.log("started miner finalizer nodes");

    evmNode = startEVMNode()!;
    console.log("started EVM node");    
  });

  describe("Test Suite: ", () => {
    console.log(
      "================================STARTING INTEGRATION TESTS================================"
    );

    importTest("Mining and Finalizing works", "./miner.test");

	  importTest("Mutichain Staking", "./multi-chain-staking.test");

  });

  after(async () => {
    aliceNode?.kill("SIGINT");
    bobNode?.kill("SIGINT");
    evmNode?.kill("SIGINT");
    await sleep(5 * SECONDS);
  });
});
