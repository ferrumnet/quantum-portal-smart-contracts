// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./IBridgePool.sol";
import "./IBridgeRoutingTable.sol";
import "foundry-contracts/contracts/taxing/IGeneralTaxDistributor.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";
import "../../../../staking/library/TokenReceivable.sol";

/*
 * Bridge Pool Contract Version 1.2 - Ported to QP.
 * We need direct mining between two chains, for the bridge.
 * And for liquidity management, we can use the DATA_CHAIN (frm) to consolidate
 * assets.
 * This removes the nodes and signature requirements from the bridge.
 */
contract BridgePoolV12 is TokenReceivable, IBridgePool {
    uint64 public constant DEFAULT_FEE_X10000 = 50; // 0.5%
    uint256 public DATA_CHAIN = 2600; // FRM Chain

    event TransferBySignature(
        address receiver,
        address token,
        uint256 amount,
        uint256 fee);
    event BridgeLiquidityAdded(
        address actor,
        address token,
        uint256 amount);
    event BridgeLiquidityRemoved(
        address actor,
        address token,
        uint256 amountRemoved,
        uint256 owedNetwork,
        address owedToken,
        uint256 owedLiquidity);
    event BridgeSwap(
        address from,
        address originToken,
        address token,
        uint256 targetNetwork,
        address targetToken,
        address swapTargetTokenTo,
        address targetAddress,
        uint256 amount);

    mapping(address => mapping(address => uint256)) private liquidities; // TODO: DATA_CHAIN only
    address public feeDistributor;
    address public router;
    address public routingTable; // Locally managed. Move to centrally managed.

    modifier onlyRouter() {
        require(msg.sender == router, "BP: Only router method");
        _;
    }

    constructor() EIP712(NAME, VERSION) {}

    /*
     *************** Owner only operations ***************
     */

    /**
     @notice Sets the fee distributor
     */
    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        // zero is allowed
        feeDistributor = _feeDistributor;
    }

    /**
     @notice sets the router
     */
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "BP: router requried");
        router = _router;
    }

    /**
     @notice Sets the routing table
     */
    function setRoutingTable(address _routingTable) external onlyOwner {
        require(_routingTable != address(0), "BP: routingTable requried");
        routingTable = _routingTable;
    }

    /**
     *************** Public operations ***************
     */

    /**
     @notice Generates a swap log
     @param to The receiver of the swap
     @param token The local token
     @param targetNetwork The target chain ID
     @param targetToken The target token
     @param swapTargetTokenTo The target token after swap
     @param targetAddress Address of the receiver
     @param originToken The origin token if it was swaped
     */
    function swap(
        address to,
        address token,
        uint256 targetNetwork,
        address targetToken,
        address swapTargetTokenTo,
        address targetAddress,
        address originToken // Just for record
    ) external override returns (uint256) {
        return
            _swap(
                to,
                originToken,
                token,
                targetNetwork,
                targetToken,
                swapTargetTokenTo,
                targetAddress
            );
    }

    bytes32 constant WITHDRAW_SIGNED_METHOD =
        keccak256(
            "WithdrawSigned(address token,address payee,uint256 amount,address toToken,uint32 sourceChainId,bytes32 swapTxId)"
        );
    /**
     @notice Withdraw with signature
     @param token The token
     @param payee Receier of the payment
     @param amount The amount
     @param swapToToken The final target token
     @param sourceChainId The source chain ID
     @param swapTxId Te swap tx ID
     @param multiSignature The multisig validator signature
     */
    function withdrawSigned(
        address token,
        address payee,
        uint256 amount,
        address swapToToken,
        uint32 sourceChainId,
        bytes32 swapTxId,
        bytes memory multiSignature
    ) external override returns (uint256) {
        require(token != address(0), "BP: bad token");
        require(payee != address(0), "BP: bad payee");
        require(amount != 0, "BP: bad amount");
        require(swapTxId != 0, "BP: bad swapTxId");
        require(sourceChainId != 0, "BP: bad sourceChainId");
        bytes32 message = withdrawSignedMessage(
            token,
            payee,
            amount,
            swapToToken,
            sourceChainId,
            swapTxId
        );
        IBridgeRoutingTable.TokenWithdrawConfig
            memory conf = IBridgeRoutingTable(routingTable).withdrawConfig(
                token
            );
        verifyUniqueSalt(message, swapTxId, conf.groupId, multiSignature);

        uint256 fee = 0;
        address _feeDistributor = feeDistributor;
        if (_feeDistributor != address(0)) {
            uint256 feeRatio = conf.noFee != 0 ? 0 : conf.feeX10000 != 0
                ? conf.feeX10000
                : DEFAULT_FEE_X10000;
            fee = amount * feeRatio / 10000;
            amount = amount - fee;
            if (fee != 0) {
                sendToken(token, _feeDistributor, fee);
                IGeneralTaxDistributor(_feeDistributor).distributeTax(token);
            }
        }
        sendToken(token, payee, amount);
        emit TransferBySignature(payee, token, amount, fee);
        return amount;
    }

    /**
     @notice Verify the withdraw signature
     @param token The token
     @param payee Receier of the payment
     @param amount The amount
     @param swapToToken The final target token
     @param sourceChainId The source chain ID
     @param swapTxId Te swap tx ID
     @param multiSignature The multisig validator signature
     */
    function withdrawSignedVerify(
        address token,
        address payee,
        uint256 amount,
        address swapToToken,
        uint32 sourceChainId,
        bytes32 swapTxId,
        bytes calldata multiSignature
    ) external view returns (bytes32, bool) {
        bytes32 message = withdrawSignedMessage(
            token,
            payee,
            amount,
            swapToToken,
            sourceChainId,
            swapTxId
        );
        IBridgeRoutingTable.TokenWithdrawConfig
            memory conf = IBridgeRoutingTable(routingTable).withdrawConfig(
                token
            );
        (bytes32 digest, bool result) = tryVerify(
            message,
            conf.groupId,
            multiSignature
        );
        return (digest, result);
    }

    bytes32 constant REMOVE_LIQUIDITY_SIGNED_METHOD =
        keccak256(
            "RemoveLiquiditySigned(address token,address payee,uint256 amount,uint32 sourceChainId,bytes32 txId)"
        );
    /**
     @notice Remove liquidity using signature
     @param token The token
     @param payee Receier of the payment
     @param amount The amount
     @param sourceChainId The source chain ID
     @param txId Te swap tx ID
     @param multiSignature The multisig validator signature
     */
    function removeLiquiditySigned(
        address token,
        address payee,
        uint256 amount,
        uint32 sourceChainId,
        bytes32 txId,
        bytes memory multiSignature
    ) external override returns (uint256) {
        require(token != address(0), "BP: Bad token");
        require(payee != address(0), "BP: Bad payee");
        require(amount != 0, "BP: Bad amount");
        require(sourceChainId != 0, "BP: Bad sourceChainId");
        require(txId != 0, "BP: Bad txId");
        bytes32 message = keccak256(
            abi.encode(
                REMOVE_LIQUIDITY_SIGNED_METHOD,
                token,
                payee,
                amount,
                sourceChainId,
                txId
            )
        );
        IBridgeRoutingTable.TokenWithdrawConfig
            memory conf = IBridgeRoutingTable(routingTable).withdrawConfig(
                token
            );
        verifyUniqueSalt(message, txId, conf.groupId, multiSignature);

        sendToken(token, payee, amount);
        emit TransferBySignature(payee, token, amount, 0);
        return amount;
    }

    /**
     @notice Adds liquidity
     @param to The liquidity owner
     @param token The token
     */
    function addLiquidity(address to, address token
    ) external override {
        require(token != address(0), "Bad token");
        require(to != address(0), "Bad to");
        uint256 amount = sync(token);
        require(amount != 0, "BP: Amount must be positive");
        liquidities[token][to] = liquidities[token][to] + amount;
        emit BridgeLiquidityAdded(to, token, amount);
    }

    /**
       @notice If there is not enough liquidity in this network, a log is issued for the bridge nodes to provide
          removeLiquiditySigned messages on the target network for the owed amount.
        @param to The receiver of liquidity
        @param token The token
        @param amount The amount
        @param targetNetwork The target network
        @param targetToken The target token
     */
    function removeLiquidity(
        address to,
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken
    ) external nonReentrant override {
        // Using tx.origin in case we are calling this from router.
        // A malicious sc can call remove liquidity for the origin but
        // cannot steal their assets
        (uint256 actualLiq, uint256 owed) = _removeLiquidity(
            to,
            token,
            amount,
            true
        );
        if (actualLiq != 0) {
            sendToken(token, to, actualLiq);
        }
        if (owed != 0) {
            require(targetToken != address(0), "BP: targetToken required");
            require(targetNetwork != 0, "BP: targetNetwork required");
            // We owe more liquidity. To be taken out of the target network
            IBridgeRoutingTable(routingTable).verifyRoute(
                token,
                targetNetwork,
                targetToken
            );
            emit BridgeLiquidityRemoved(
                to,
                token,
                amount,
                targetNetwork,
                targetToken,
                owed
            );
        } else {
            emit BridgeLiquidityRemoved(to, token, amount, 0, address(0), 0);
        }
    }

    /**
     @notice Removes the liquidity only as much as is possible on this network
     @param to The receiver of the liquidity
     @param token The token
     @param amount The amount
     */
    function removeLiquidityIfPossible(
        address to,
        address token,
        uint256 amount
    ) external override onlyRouter {
        (uint256 actualLiq, ) = _removeLiquidity(to, token, amount, false);
        if (actualLiq != 0) {
            sendToken(token, to, actualLiq);
            emit BridgeLiquidityRemoved(to, token, amount, 0, address(0), 0);
        }
    }

    /**
     @notice Returns the address liquidity
     @param token The token
     @param liquidityAdder The liquidity adder
     @return The liquidity
     */
    function liquidity(address token, address liquidityAdder
    ) external view override returns (uint256) {
        return liquidities[token][liquidityAdder];
    }

    /**
     @notice Removes liquidity
     @param to To address
     @param token The token
     @param amount The amount
     @param force Should the removal be forced or not
     @return removed The amount of liquidity removed
     @return owed The amount still owed
     */
    function _removeLiquidity(
        address to,
        address token,
        uint256 amount,
        bool force
    ) internal returns (uint256 removed, uint256 owed) {
        require(to != address(0), "BP: to required");
        require(amount != 0, "BP: amount must be positive");
        require(token != address(0), "BP: bad token");
        uint256 liq = liquidities[token][to];
        require(liq >= amount, "BP: not enough liquidity");
        uint256 balance = IERC20(token).balanceOf(address(this));
        removed = balance > amount ? amount : balance;
        liquidities[token][to] = liq - (force ? amount : removed);
        owed = amount - removed;
    }

    /**
     @notice Run a swap
     @param from From address
     @param originToken The origin token
     @param token The token
     @param targetNetwork The target chain ID
     @param targetToken the target token
     @param swapTargetTokenTo The target token info
     @param targetAddress The target address
     @return The amount swapped
     */
    function _swap(
        address from,
        address originToken,
        address token,
        uint256 targetNetwork,
        address targetToken,
        address swapTargetTokenTo,
        address targetAddress
    ) internal returns (uint256) {
        require(from != address(0), "BP: bad from");
        require(targetAddress != address(0), "BP: bad targetAddress");
        require(token != address(0), "BP: bad token");
        require(targetToken != address(0), "BP: bad targetToken");
        require(targetNetwork != 0, "BP: targetNetwork is requried");
        IBridgeRoutingTable(routingTable).verifyRoute(
            token,
            targetNetwork,
            targetToken
        );
        uint256 amount = sync(token);
        require(amount != 0, "BP: amount must be positive");
        emit BridgeSwap(
            from,
            originToken,
            token,
            targetNetwork,
            targetToken,
            swapTargetTokenTo,
            targetAddress,
            amount
        );
        return amount;
    }

    /**
     @notice Creates a withdraw message hash
     @param token The token
     @param payee Receiver
     @param amount The amount
     @param swapToToken The final token to swap to
     @param sourceChainId The source network ID
     @param swapTxId The source swap tx id
     @return The message hash
     */
    function withdrawSignedMessage(
        address token,
        address payee,
        uint256 amount,
        address swapToToken,
        uint32 sourceChainId,
        bytes32 swapTxId
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    WITHDRAW_SIGNED_METHOD,
                    token,
                    payee,
                    amount,
                    swapToToken,
                    sourceChainId,
                    swapTxId
                )
            );
    }

}
