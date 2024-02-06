// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IWorkerInvestor.sol";

/**
 * @notice This contract maintains relationship between an investor and a worker.
 * Investor puts the money, and worker does the work.
 */
contract WorkerInvestor is IWorkerInvestor {
    mapping(address => address) public worker;
    mapping(address => IWorkerInvestor.ReverseDelegation) public investorLookup;
    event WorkerInvestor(address investor, address worker);

    /**
     * @inheritdoc IWorkerInvestor
     */
    function getInvestor(
        address worker
    ) external view override returns (IWorkerInvestor.Relationship memory) {
        return investorLookup[worker];
    }

    /**
     * @notice Assigns a worker to the given address from the `msg.sender`. A worker can be used once
     * @param to The worker
     */
    function assignWorker(address to) external {
        address currentWorker = worker[msg.sender];
        if (to == address(0)) {
            require(currentWorker != address(0), "D: nothing to delete");
            delete worker[msg.sender];
            investorLookup[currentWorker].deleted = uint8(1);
            emit WorkerInvestor(msg.sender, address(0));
            return;
        }
        require(
            investorLookup[to].worker == address(0),
            "D: to is already in investor"
        );
        require(worker[to] == address(0), "D: to is an investor");
        require(currentWorker != to, "M: nothing will change");
        worker[msg.sender] = to;
        investorLookup[currentWorker].deleted = uint8(1);
        investorLookup[to].investor = msg.sender;
        emit WorkerInvestor(msg.sender, to);
    }
}
