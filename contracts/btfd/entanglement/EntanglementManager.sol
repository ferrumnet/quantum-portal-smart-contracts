// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../QpErc20Token.sol";
import "./TxDecoder.sol";
import "../../quantumPortal/poc/IQuantumPortalPoc.sol";

interface IBitcoinRelay {
    function getProcessedTransaction(bytes calldata txHash) external view returns (uint32, bytes memory);
}

contract EntanglementManager is Ownable {
    using TxDecoder for bytes;

    QpErc20Token public qpBTC; // The QpBTC token contract
    IBitcoinRelay public bitcoinRelay;
    IQuantumPortalPoc public portal;

    struct StakerInfo {
        uint256 totalCapacity; // Total capacity (staked amount)
        bool isRegistered; // Indicates if the staker is registered
        uint256 index; // Index in the stakerList array
    }
    
    uint256 additionalCapacityFactor = 500; // basis points. 100bp = 1%
    mapping(address => StakerInfo) public stakers;
    mapping(address => bytes32) public stakerToEntangler;
    mapping(bytes32 => address) public entanglerToStaker;
    address[] public stakerList;
    uint256 public lastSelectedStakerIndex;

    struct WithdrawalRequest {
        bytes32 requestId;
        address user;
        address staker;
        bytes32 userBtcAddress;
        uint256 amount;
        bool processed;
    }

    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;
    mapping(bytes32 => bool) public processedDeposits;

    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event StakerRegistered(address indexed staker);
    event StakerDeregistered(address indexed staker);
    event DepositVerified(bytes32 indexed txHash, uint256 amount);
    event WithdrawalRequested(bytes32 indexed requestId, address indexed user, address indexed staker, bytes32 btcAddress, uint256 amount);
    event WithdrawalVerified(bytes32 indexed txHash, bytes32 requestId, address indexed user, address indexed staker, uint256 amount);


    constructor(address _qpBTC, address _bitcoinRelay, address _portal) Ownable(tx.origin) {
        qpBTC = QpErc20Token(_qpBTC);
        bitcoinRelay = IBitcoinRelay(_bitcoinRelay);
        portal = IQuantumPortalPoc(_portal);
    }

    /***************************************************************/
    // Staker Functions
    /***************************************************************/

    /**
     * @notice Stake QpBTC to become a staker.
     * @param amount The amount of QpBTC to stake.
     */
    function stakeQpBtc(uint256 amount) external {
        require(amount > 0, "Stake amount must be greater than zero");

        if (!stakers[msg.sender].isRegistered) {
            _registerStaker();
        }

        // Transfer QpBTC from staker to contract
        require(qpBTC.transferFrom(msg.sender, address(this), amount), "QpBTC transfer failed");

        // Update staker's total capacity
        stakers[msg.sender].totalCapacity += _capacityAdjustedAmount(amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake QpBTC.
     * @param amount The amount of QpBTC to unstake.
     */
    function unstakeQpBtc(uint256 amount) external {
        require(stakers[msg.sender].isRegistered, "Not a registered staker");
        require(amount > 0, "Unstake amount must be greater than zero");
        require(stakers[msg.sender].totalCapacity >= amount, "Insufficient staked amount");

        // Transfer QpBTC back to staker
        require(qpBTC.transfer(msg.sender, amount), "QpBTC transfer failed");

        // Update staker's total capacity
        stakers[msg.sender].totalCapacity -= _capacityAdjustedAmount(amount);

        if (stakers[msg.sender].totalCapacity == 0) {
            _deregisterStaker();
        }

        emit Unstaked(msg.sender, amount);
    }

    /***************************************************************/
    // User Functions
    /***************************************************************/

    /**
     * @notice Get a deposit address (entangler) for depositing BTC.
     * @return depositAddress The deposit address (bytes32) corresponding to a staker.
     */
    function getDepositAddress(uint256 amount) external view returns (bytes32 depositAddress) {
        address selectedStaker = _selectStaker(amount);
        require(selectedStaker != address(0), "No staker available");

        depositAddress = stakerToEntangler[selectedStaker];
    }

    /**
     * @notice Verify a BTC deposit and mint QpBTC to the user.
     * @param txHash The Bitcoin transaction hash.
     */
    function verifyDeposit(bytes32 txHash) external {
        require(!processedDeposits[txHash], "Deposit already processed");

        bytes memory data;
        (, data) = bitcoinRelay.getProcessedTransaction(abi.encodePacked(txHash));

        (
            uint64 blockNumber,
            uint64 timestamp,
            TxDecoder.Input[] memory inputs,
            TxDecoder.Output[] memory outputs,
            bytes memory encodedCall
        ) = data.parseRetrieveTx();

        (
            uint256 remoteChainId,
            address remoteContract,
            bytes memory remoteMethodCall,
            ,
            address beneficiary,,
        ) = abi.decode(encodedCall, (uint256, address, bytes, bytes32, address, uint256, uint256));

        // Find an output where the address matches a staker's entangler address
        address staker;
        uint256 amount;
        {
            bool valid = false;
            for (uint256 i = 0; i < outputs.length; i++) {
                bytes32 outputAddr = outputs[i].addr;
                address matchedStaker = entanglerToStaker[outputAddr];
                if (matchedStaker != address(0)) {
                    // Found a staker
                    staker = matchedStaker;
                    amount = outputs[i].amount;
                    valid = true;
                    break;
                }
            }

            require(valid, "No valid staker entangler address found in outputs");
        }
        require(stakers[staker].totalCapacity >= amount, "Staker does not have enough capacity");

        // Update staker's capacity
        stakers[staker].totalCapacity -= amount;

        // Mint QpBTC to user via QP
        // Do we need to burn the QpBTC from the staker?
        portal.run(uint64(remoteChainId), remoteContract, beneficiary, remoteMethodCall);

        // Mark txHash as processed
        processedDeposits[txHash] = true;

        emit DepositVerified(txHash, amount);
    }

    /**
     * @notice Request a withdrawal (burn QpBTC and record the request).
     * @param btcAddress The user's Bitcoin address to receive BTC.
     * @param amount The amount of BTC to withdraw.
     * @return requestId A unique identifier for the withdrawal request.
     */
    function requestWithdrawal(bytes32 btcAddress, uint256 amount) external returns (bytes32 requestId) {
        require(amount > 0, "Amount must be greater than zero");

        qpBTC.transferFrom(msg.sender, address(this), amount);

        address staker = _selectStaker(0);
        require(staker != address(0), "No staker available for withdrawal");

        requestId = keccak256(
            abi.encodePacked(
                msg.sender,
                btcAddress,
                amount,
                block.number
            )
        );

        // Create a withdrawal request
        WithdrawalRequest memory request = WithdrawalRequest({
            requestId: requestId,
            user: msg.sender,
            staker: staker,
            userBtcAddress: btcAddress,
            amount: amount,
            processed: false
        });

        withdrawalRequests[requestId] = request;

        emit WithdrawalRequested(requestId, msg.sender, staker, btcAddress, amount);
    }

    /**
     * @notice Verify that BTC has been sent to the user and update staker's capacity.
     * @param txHash The Bitcoin transaction hash.
     * @param requestId The withdrawal request ID.
     */
    function verifyWithdrawal(bytes32 requestId, bytes32 txHash) external {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(!request.processed, "Withdrawal already processed");

        bytes memory data;
        (, data) = bitcoinRelay.getProcessedTransaction(abi.encodePacked(txHash));

        (
            uint64 blockNumber,
            uint64 timestamp,
            TxDecoder.Input[] memory inputs,
            TxDecoder.Output[] memory outputs,
        ) = data.parseRetrieveTx();

        // Verify that the transaction includes an output to the user's BTC address with the specified amount
        bool valid = false;
        for (uint256 i = 0; i < outputs.length; i++) {
            if (outputs[i].addr == request.userBtcAddress && outputs[i].amount == request.amount) {
                valid = true;
                break;
            }
        }
        require(valid, "Invalid withdrawal transaction");

        stakers[request.staker].totalCapacity += request.amount;
        request.processed = true;

        emit WithdrawalVerified(txHash, requestId, request.user, request.staker, request.amount);
    }

    /***************************************************************/
    // Helper Functions
    /***************************************************************/

    /**
     * @notice Registers the sender as a staker.
     */
    function _registerStaker() internal {
        // Initialize entangler
        bytes32 entangler = calculateEntanglementWallet(msg.sender);
        stakerToEntangler[msg.sender] = entangler;
        entanglerToStaker[entangler] = msg.sender;

        // Initialize staker info
        stakers[msg.sender].isRegistered = true;
        stakers[msg.sender].index = stakerList.length;
        stakerList.push(msg.sender);

        emit StakerRegistered(msg.sender);
    }

    /**
     * @notice View function to select a staker
     * @return selectedStaker The address of the selected staker.
     */
    function _selectStaker(uint256 amount) internal view returns (address selectedStaker) {
        uint256 stakerCount = stakerList.length;
        if (stakerCount == 0) {
            return address(0);
        }

        uint256 startIndex = _pseudoRandom() % stakerCount;
        uint256 i = startIndex;

        do {
            address staker = stakerList[i];
            uint256 capacity = stakers[staker].totalCapacity;

            if (capacity >= amount) {
                // Found a staker with sufficient capacity
                selectedStaker = staker;
                break;
            }

            i = (i + 1) % stakerCount;
        } while (i != startIndex);
    }

    /**
     * @notice Deregister as a staker.
     */
    function _deregisterStaker() public {
        uint256 index = stakers[msg.sender].index;
        address lastStaker = stakerList[stakerList.length - 1];
        stakerList[index] = lastStaker;
        stakers[lastStaker].index = index;
        stakerList.pop();

        // Delete staker info
        delete entanglerToStaker[stakerToEntangler[msg.sender]];
        delete stakerToEntangler[msg.sender];
        delete stakers[msg.sender];

        emit StakerDeregistered(msg.sender);
    }

    function _pseudoRandom() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            blockhash(block.number - 1),
            block.timestamp
        )));
    }

    function _capacityAdjustedAmount(uint256 amount) internal view returns (uint256) {
        return amount + amount * additionalCapacityFactor / 10000;
    }

    /**
     * @notice Calculates the entanglement identifier (address) for a staker.
     * @param staker The staker's address.
     * @return The entangler identifier.
     */
    function calculateEntanglementWallet(address staker) public pure returns (bytes32) {
        // TODO: This is for testing only
        return keccak256(abi.encodePacked(staker));
    }

    function stakerListLength() external view returns (uint256) {
        return stakerList.length;
    }
}
