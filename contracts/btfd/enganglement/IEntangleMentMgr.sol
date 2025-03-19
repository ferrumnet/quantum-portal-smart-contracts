pragma solidity ^0.8.24;

/**
 * @notice An all-in-one interface for the Entanglement Manager. We need to break it down
 * The entanglement mgr is used by Engtangler nodes
 */
interface IEntanglementMgr {

    /***************************************************************/
    // General interface
    /***************************************************************/


    /**
     * @notice Stake QpBTC
     */
    function stakeBtc(uint amount) external;

    /**
     * @notice Returns a randomized entanglement address, which enough capacity for deposit, 
     * @param depositAmount The amount we expect to deposit
     */
    function getDepositAddress(uint depositAmount) external returns (bytes32);

    /**
     * @notice Reutrns the capacity for a given entangler
     * @param entangler The entangler address on native chain
     */
    function capacityOfEntangler(bytes32 entangler) external view returns (uint);

    /**
     * @notice The capcity of the staker
     * @param staker The staker
     */
    function capcityOfStaker(address staker) external view returns (uint);

    function stakerToEngangler(address staker) external view returns (bytes32);

    function entanglerToStaker(bytes32 entangler) external view returns (address);



    /***************************************************************/
    // Settlement interface
    /***************************************************************/

    /**
     * @notice Requests the settlement. Called by user application
     */
    function requestSettlement(bytes32 toAddress, uint amount) external;

    /**
     * @notice Find the deterministic candidate for settlement. NOTE: Same as QPMinerMembership.findMiner
     * @param settlementId  The settlement ID
     * @param timestamp The timestamp of the block
     */
    function findSettler(bytes32 settlementId, uint timestamp) external view returns (address);

    /**
     * @notice Selects a settler. To be used by other contracts. NOTE: Same as QPMinerMembership.selectMiner
     * @param requestedSettler The requested settler
     * @param settlementId The settlement ID
     * @param timestamp The timestamp of the block
     */
    function selectSettler(
        address requestedSettler,
        bytes32 settlementId,
        uint256 timestamp
    ) external returns (bool);

    struct SettlementInfo {
        bytes32 settlementId;
        bytes32 btcTransactionHash;
        address settler;
        bool complete;
    }

    /**
     * @notice Returns the status of a settlement
     * @param settlementId The settlement ID
     */
    function settlementStatus(bytes32 settlementId) external view returns (SettlementInfo memory);

    /**
     * @notice Registered the execution of a transaction on the base chain. TO be called only as part of the mining
     * where the settlement TX on btc chain is mined. A settlement tx, has the settlement id as OP_RETURN
     */
    function registerExecution(bytes32 settlementId, bytes32 btcTransactionHash) external;

    /***************************************************************/
    // Entanglement interface
    /***************************************************************/

    /**
     * @notice Creates an entanglement multisig wallet, by calling the wentanglement pallette pre-compile
     */
    function calculateEntanglementWallet(address staker) external pure returns (bytes32);

    /**
     * @notice Note: Called by the MGR. Updates the capacity
     */
    function updateCapacity(bytes32 entangler, uint entangledBalance) external;
}