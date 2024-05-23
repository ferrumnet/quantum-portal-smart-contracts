// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./IBridgePool.sol";
import "./IBridgeRoutingTable.sol";
import "foundry-contracts/contracts/taxing/IGeneralTaxDistributor.sol";
import "../../../../staking/library/TokenReceivable.sol";
import "../../utils/WithQp.sol";
import "../../utils/WithRemotePeers.sol";

/*
 * Bridge Pool Contract Version 1.2 - Ported to QP.
 * We need direct mining between two chains, for the bridge.
 * And for liquidity management, we can use the DATA_CHAIN (frm) to consolidate
 * assets.
 * This removes the nodes and signature requirements from the bridge.
 */
contract BridgePoolV12 is TokenReceivable, IBridgePool, WithQp, WithRemotePeers {
    uint64 public constant DEFAULT_FEE_X10000 = 50; // 0.5%
    uint256 public DATA_CHAIN = 2600; // TODO: FRM Chain

    struct WithdrawItem {
        address token;
        address payee;
        uint256 amount;
    }

    event Withdraw(
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
        address targetAddress,
        uint256 amount);

    mapping(address => WithdrawItem[]) public withdrawItems;
    mapping(address => mapping(address => uint256)) public liquidities; // TODO: Move to DATA_CHAIN only, clients can request to change
    address public feeDistributor;
    address public router;
    address public routingTable; 

    modifier onlyRouter() {
        require(msg.sender == router, "BP: Only router method");
        _;
    }

    constructor() Ownable(msg.sender) {}

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
     @notice Calls the swap method on the remote chain.
     @param to The receiver of the swap
     @param token The local token
     @param targetNetwork The target chain ID
     @param targetToken The target token
     @param targetAddress Address of the receiver
     @param originToken The origin token if it was swaped
     */
    function swap(
        address to,
        address token,
        uint256 targetNetwork,
        address targetToken,
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
                targetAddress
            );
    }

    function withdraw(address payee) external override returns (uint256) {
        uint len = withdrawItems[payee].length;
        for(uint i=len-1; i >= 0; i--) {
            WithdrawItem memory item = withdrawItems[payee][withdrawItems[payee].length - 1];
            withdrawItems[payee].pop();
            _withdraw(item.token, payee, item.amount);
        }
    }

    /**
     @notice Withdraw with signature
     @param token The token
     @param payee Receier of the payment
     @param amount The amount
     */
    function _withdraw(
        address token,
        address payee,
        uint256 amount
    ) internal returns (uint256) {
        require(token != address(0), "BP: bad token");
        require(payee != address(0), "BP: bad payee");
        require(amount != 0, "BP: bad amount");
        IBridgeRoutingTable.TokenWithdrawConfig
            memory conf = IBridgeRoutingTable(routingTable).withdrawConfig(
                token
            );

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
        emit Withdraw(payee, token, amount, fee);
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
     @param targetAddress The target address
     @return The amount swapped
     */
    function _swap(
        address from,
        address originToken,
        address token,
        uint256 targetNetwork,
        address targetToken,
        address targetAddress
    ) internal returns (uint256) {
        require(from != address(0), "BP: bad from");
        require(targetAddress != address(0), "BP: bad targetAddress");
        require(token != address(0), "BP: bad token");
        require(targetToken != address(0), "BP: bad targetToken");
        require(targetNetwork != 0, "BP: targetNetwork is requried");
        address targetNetworkBridgeContract = remotePeers[targetNetwork];
        require(targetNetworkBridgeContract != address(0), "BP: target contract not set");
        IBridgeRoutingTable(routingTable).verifyRoute(
            token,
            targetNetwork,
            targetToken
        );
        uint256 amount = sync(token);
        require(amount != 0, "BP: amount must be positive");
        bytes memory method = abi.encodeWithSelector(
            BridgePoolV12.remoteSwap.selector,
            targetToken,
            targetAddress,
            amount,
            block.chainid
        );
        portal.run(
            uint64(targetNetwork),
            targetNetworkBridgeContract,
            msg.sender,
            method
        );
        emit BridgeSwap(
            from,
            originToken,
            token,
            targetNetwork,
            targetToken,
            targetAddress,
            amount
        );
        return amount;
    }

    function remoteSwap(
        address token,
        address payee,
        uint256 amount,
        uint32 sourceChainId
    ) external {
        (uint netId, address sourceMsgSender,) = portal
            .msgSender();
        address targetNetworkBridgeContract = remotePeers[sourceChainId];
        require(targetNetworkBridgeContract != address(0), "BP: target contract not set");
        require(sourceMsgSender == targetNetworkBridgeContract, "Not allowed"); // Caller must be a valid pre-configured remote.
        require(sourceChainId == netId, "BP: Unexpected source");
        // Adding to the swap list, so that it can be withdrawn.
        WithdrawItem memory item = WithdrawItem({
            token: token,
            payee: payee,
            amount: amount
        });
        withdrawItems[payee].push(item);
        // TODO: Emit event
    }
}
