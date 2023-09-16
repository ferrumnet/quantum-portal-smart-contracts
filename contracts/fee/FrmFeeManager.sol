// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFrmFeeManager.sol";
import "./IPriceOracle.sol";
import "../staking/library/TokenReceivable.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";

/**
 @notice Fee manager allows other "trusted" contracts to pay fees on their user's behalf.
 User deposits token into fee manager.
 Fee manager will collect fees, from the user based on the price of base (e.g. FRM) and the 
 price of the fee to be paid.
 */
contract FrmFeeManager is TokenReceivable, WithAdmin, IFrmFeeManager {
    struct PriceOracleInfo {
        address univ2Oracle;
        address[] pricePath;
    }
    mapping(address => PriceOracleInfo) public priceOracles;
    mapping(address => uint256) public balances;
    mapping(address => bool) public registeredOracles;
    mapping(address => bool) public trustedCallers;
    address feeToken;
    address liquidityBaseToken;
    address defaultPriceOracle;

    address constant FEE_REPO = address(0);

    /**
     @notice Deposit fee for an account
     @param to The fee receiver
     @return The deposited amount
     */
    function deposit(address to) external returns (uint256) {
        uint256 amount = sync(feeToken);
        balances[to] += amount;
        return amount;
    }

    /**
     @notice Withdraw deposited fee from an account
     @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external {
        uint256 balance = balances[msg.sender];
        require(amount >= balance, "FFM: not enough balance");
        balances[msg.sender] = balance - amount;
        sendToken(feeToken, msg.sender, amount);
    }

    /**
     @notice Add a trusted caller. Caller can charge fee from anybody.
     @param caller The caller
     */
    function allowTrustedCaller(address caller) external onlyOwner {
        trustedCallers[caller] = true;
    }

    /**
     @param caller The caller
     */
    function removeTrusterCaller(address caller) external onlyAdmin {
        delete trustedCallers[caller];
    }

    /**
     @notice Allows a univ2 oracle
     @param univ2Oracle The Univ2 oracle
     @param isDefault If the oracle is default
     */
    function allowUniV2Oracle(
        address univ2Oracle,
        bool isDefault
    ) external onlyAdmin {
        registeredOracles[univ2Oracle] = true;
        if (isDefault) {
            defaultPriceOracle = univ2Oracle;
        }
    }

    /**
     @notice Remoces a univ2 oracle
     @param univ2Oracle The univ2 orcale to remove
     */
    function removeUniV2Oracle(address univ2Oracle) external onlyAdmin {
        delete registeredOracles[univ2Oracle];
    }

    /**
     @notice Registers a path for an oracle. TODO: consider doing more check and open this method to public
     @param univ2Oracle The univ2 oracle. Must already be registered
     @param pricePath The price path
     */
    function registerPriceOracle(
        address univ2Oracle,
        address[] calldata pricePath
    ) external onlyAdmin {
        require(
            pricePath[pricePath.length - 1] == liquidityBaseToken,
            "FFM: pricePath should end in lp base token"
        );
        require(registeredOracles[univ2Oracle], "FFM: oracle not allowed");
        address token = pricePath[0];
        // Clean up
        uint256 len = priceOracles[token].pricePath.length;
        for (uint i = 0; i < len; i--) {
            priceOracles[token].pricePath.pop();
        }
        priceOracles[token].univ2Oracle = univ2Oracle;
        priceOracles[token].pricePath = pricePath;
    }

    /**
     @notice Pay fee on behalf of a user. This will allow caller to charge fee from the user
             One common usecase is to provide discouts for the fees if the user for example 
             uses FRM to pay the fee.
             This method will calculate the fee based on the price of the token vs the base token.
     @param user The user who will be paying the fee
     @param token The token to be used as fee
     @param amount The fee amount based on the provided token
     @return True if the fee charge was successful
     */
    function payFee(
        address user,
        address token,
        uint256 amount
    ) external override returns (bool) {
        require(user != address(0), "FFM: user requried");
        require(token != address(0), "FFM: token requried");
        require(trustedCallers[msg.sender], "FFM: caller not allowed");
        if (amount == 0) {
            return true;
        }
        address oracle = priceOracles[token].univ2Oracle;
        if (oracle == address(0)) {
            return false;
        }
        address[] memory path = priceOracles[token].pricePath;
        require(path[0] == token, "FFM: Invalid path start");
        require(
            path[path.length - 1] == liquidityBaseToken,
            "FFM: Invalid path end"
        );

        (uint256 feeAmount, bool success) = convertTokenToFee(token, amount);
        if (!success) {
            return false;
        }
        uint256 userBalance = balances[user];
        if (userBalance < feeAmount) {
            return false;
        }
        balances[FEE_REPO] += feeAmount;
        balances[user] = userBalance - feeAmount;
        return true;
    }

    /**
     @notice Sweeps the collected fees.
     @param to The receiver of the collected fees.
     */
    function sweep(address to) external onlyAdmin {
        uint256 balance = balances[FEE_REPO];
        balances[FEE_REPO] = 0;
        sendToken(feeToken, to, balance);
    }

    /**
     @notice amount * Token price / feeToken price
     To trouble shoot, (if function returns false) first make sure token path is set
     and token price can be retrieved. Then the same for feeToken
     */
    function convertTokenToFee(
        address token,
        uint256 amount
    ) internal returns (uint256, bool) {
        uint256 tokenPrice = getPriceX128(token);
        if (tokenPrice == 0) {
            return (0, false);
        }
        uint256 frmPrice = getPriceX128(feeToken);
        if (frmPrice == 0) {
            return (0, false);
        }
        uint256 ratio = FullMath.mulDiv(
            frmPrice,
            FixedPoint128.Q128,
            tokenPrice
        );
        return (FullMath.mulDiv(ratio, amount, FixedPoint128.Q128), true);
    }

    /**
     @notice Returns the token price. If token is not registered, tries the default oracle.
       If pair does notexist on the default oracle, caches the "0" as the result to avoid 
       repeated calls to the oracle.
       TODO: How to make this deterministic, so that fee does not change from the submission
             to mining time.
     */
    function getPriceX128(address token) internal returns (uint256) {
        PriceOracleInfo memory oracleInfo = priceOracles[token];
        address oracle = oracleInfo.univ2Oracle;
        address[] memory path = oracleInfo.pricePath;
        if (oracle == address(0)) {
            // Use the default oracle
            oracle = defaultPriceOracle;
            path = new address[](2);
            path[0] = token;
            path[1] = liquidityBaseToken;
        }
        if (IPriceOracle(oracle).updatePrice(path)) {
            return IPriceOracle(oracle).recentPriceX128(path);
        }
        return 0;
    }
}
