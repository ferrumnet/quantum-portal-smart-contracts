// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPriceOracle.sol";
import "../uniswap/IUniswapV2Factory.sol";
import "../uniswap/IUniswapV2Pair.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";

import "hardhat/console.sol";

contract UniswapOracle is IPriceOracle {
    uint256 constant Q112 = 2**112;
    uint256 constant _1MIN = 60;
    uint256 constant _1HOUR = _1MIN * 60;
    uint256 constant _1DAY = _1HOUR * 24;
    uint256 constant _25DAY = _1DAY * 25;
    uint256 constant _50DAY = _25DAY * 2;
    uint256 constant _100DAY = _50DAY * 2;
    uint256 constant NO_PRICE_CACHE = 3600; // Cache no price to prevent trying again on each request
    IUniswapV2Factory public uniV2Factory;

    struct EmaTimes { // Stores in one uint
        uint32 lastNoPriceFetchTime;
        uint32 lastCumuPriceFetch;
        uint32 _1Min;
        uint32 _1Hour;
        uint32 _1Day;
        uint32 _25Day;
        uint32 _50Day;
        uint32 _100Day;
    }
    mapping (bytes32=>uint256) public rawCumulativePrices;
    mapping (bytes32=>uint256[]) public emas;
    mapping (bytes32=>EmaTimes) public emaTimes;

    constructor() {
		(address factory) = abi.decode(IFerrumDeployer(msg.sender).initData(), (address));
        uniV2Factory = IUniswapV2Factory(factory);
    }

    function updatePrice(address[] calldata path) external override returns (bool) {
        require(path.length >= 2, "UO: path too short");
        console.log("UPDATING PRICE");
        for(uint i=0; i<path.length - 1; i++) {
            console.log("UPDATING PRICE FOR", path[i], path[i+1]);
            if (!updatePriceForPair(path[i], path[i+1])) {
                return false;
            }
        }
        return true;
    }

    function updatePriceForPair(address path0, address path1) internal returns (bool) {
        // Update all emas that are necessary.
        // Figure out which emas need to get updated
        bytes32 key = emaKey(path0, path1);
        EmaTimes memory lastTime = emaTimes[key];
        uint256 _now = block.timestamp;
        if (lastTime.lastNoPriceFetchTime != 0 && (_now - lastTime.lastNoPriceFetchTime) < NO_PRICE_CACHE) {
            return false;
        }
        console.log("UPDATING PRICE FOR PAIR", path0, path1);
        console.logBytes32(key);

        // First figure out if we need to update anything?
        // if so, fetch the price, and use it to update what
        // needs to be updated.
        uint256[6] memory periods = [_1MIN, _1HOUR, _1DAY, _25DAY, _50DAY, _100DAY];
        uint256[] memory diffs = new uint256[](6);
        uint256[6] memory times = [
            uint(lastTime._1Min),
            uint(lastTime._1Hour),
            uint(lastTime._1Day),
            uint(lastTime._25Day),
            uint(lastTime._50Day),
            uint(lastTime._100Day)];
        for(uint i=0; i<5; i++) {
            uint256 diff = newPeriod(times[i], _now, periods[i]);
            console.log("NEW PERIOD?", times[i], _now, periods[i]);
            console.log("DIFF", diff);
            if (diff == 0) {
                break;
            }
            diffs[i] = diff;
        }
        if (diffs[0] == 0) {
            return false;
        }

        // Update the cumulative price
        (uint256 cumuPriceX128, uint256  lastPriceFetchTime) = fetchCumuPriceX128(key, lastTime.lastCumuPriceFetch, path0, path1);
        console.log("Current price is", cumuPriceX128, lastPriceFetchTime);
        if (cumuPriceX128 == 0) {
            // Could not fetch the price...
            lastTime.lastNoPriceFetchTime = uint32(_now);
            emaTimes[key] = lastTime;
            return false;
        }
        lastTime.lastNoPriceFetchTime = 0;
        if (lastTime.lastCumuPriceFetch == 0) {
            console.log("First time updating the price");
            // This is the first time getting price, just update the timing
            rawCumulativePrices[key] = cumuPriceX128;
            lastTime.lastCumuPriceFetch = uint32(lastPriceFetchTime);
            emaTimes[key] = lastTime;
        } else {
            console.log("Updating price: ", rawCumulativePrices[key], cumuPriceX128);
            console.log("Diff: ", cumuPriceX128 - rawCumulativePrices[key]);
            console.log("Times: ", lastTime.lastCumuPriceFetch, lastPriceFetchTime);
            uint256 rawPrice = rawCumulativePrices[key];
            if (rawPrice == cumuPriceX128) { // No price update.
                console.log("No price update");
                return false;
            }
            uint priceX128 = calculatePriceX128(
                lastTime.lastCumuPriceFetch,
                rawPrice,
                lastPriceFetchTime,
                cumuPriceX128
            );
            console.log("New price: ", priceX128);
            lastTime.lastCumuPriceFetch = uint32(lastPriceFetchTime);
            rawCumulativePrices[key] = cumuPriceX128;
            
            // Now we have the new price. Lets update the periods.
            updateEmas(key, priceX128, diffs, times);

            lastTime._1Min = uint32(times[0]);
            lastTime._1Hour = uint32(times[1]);
            lastTime._1Day = uint32(times[2]);
            lastTime._25Day = uint32(times[3]);
            lastTime._50Day = uint32(times[4]);
            lastTime._100Day = uint32(times[5]);
            emaTimes[key] = lastTime;
        }
        return true;
    }

    function updateEmas(bytes32 key, uint256 priceX128, uint256[] memory diffs, uint256[6] memory times
    ) private {
        bool hasOldPrice = emas[key].length != 0;
        for(uint i=0; i<5; i++) {
            if (diffs[i] != 0) {
                // Update based on the new price
                uint256 oldPrice = hasOldPrice ? emas[key][i] : 0;
                uint256 newPrice = oldPrice == 0 ? priceX128 : calcEmaX128(i, oldPrice, priceX128);
                times[i] += diffs[i];
                if (hasOldPrice) {
                    emas[key][i] = newPrice;
                } else {
                    emas[key].push(newPrice);
                }
            } else if (!hasOldPrice) {
                emas[key].push(priceX128);
            }
        }
    }

    function calculatePriceX128(
        uint256 time1,
        uint256 cumuPrice1,
        uint256 time2,
        uint256 cumuPrice2
    ) internal pure returns(uint256) {
        return (cumuPrice2 - cumuPrice1) / (time2 - time1);
        // return FullMath.mulDiv(
        //     cumuPrice2 - cumuPrice1,
        //     FixedPoint128.Q128,
        //     time2 - time1);
    }

    function recentPriceX128(address[] calldata path) external override view returns (uint256) {
        return emaX128(path, EmaType(0));
    }

    function emaX128(address[] calldata path, EmaType emaType) public override view returns (uint256) {
        require(path.length > 1, "UO: path too short");
        uint256 emaIdx = uint256(emaType);
        uint256 latestPrice = FixedPoint128.Q128;
        for(uint i=0; i < path.length - 1; i++) {
            bytes32 key = emaKey(path[i], path[i+1]);
            console.log("Querying price for ", path[i], path[i+1]);
            console.logBytes32(key);
            uint256 recentPrice = emas[key][0];
            uint256 emaPrice = emas[key][emaIdx];
            console.log("EMA PRICE IS", emaPrice);
            if (emaIdx != 0) {
                recentPrice = calcEmaX128(emaIdx, emaPrice, recentPrice);
                console.log("Recent price is", recentPrice);
            }
            latestPrice = FullMath.mulDiv(latestPrice, recentPrice, FixedPoint128.Q128);
            console.log("lastest price is", latestPrice);
        }
        return latestPrice;
    }

    /**
     @notice Fetches the new cumulative price / time from uniswap. 
     @return New cumulative price or "0" if none
     @return New cumulative price timestamp
     */
    function fetchCumuPriceX128(bytes32 key, uint256 lastCumuPriceFetchTime, address path0, address path1
    ) internal view returns (uint256, uint256) {
        // Price calculation? For each pair get the cumulative 
        // To decide if we should use price0CumulativeLast, or price1,
        // consider price0 is the token1/token0.
        // First get the relevant cumulative price for a pair.
        address pair = uniV2Factory.getPair(path0, path1);
        console.log('Using PAIR ', pair);
        bool zero1 = IUniswapV2Pair(pair).token0() == path0;
        // Find the cumulative price for relevant pair
        uint256 cumuPrice = zero1 ?
            IUniswapV2Pair(pair).price1CumulativeLast() :
            IUniswapV2Pair(pair).price0CumulativeLast();
        (, ,uint256 newTimestamp) = IUniswapV2Pair(pair).getReserves();

        console.log("CUMU PRICE Uni format", cumuPrice);
        // Update the floating point to our model.
        cumuPrice = FullMath.mulDiv(cumuPrice, FixedPoint128.Q128, Q112);
        console.log("CUMU PRICE", cumuPrice);
        return (cumuPrice, newTimestamp);
    }

    function calcEmaX128(uint256 i, uint256 oldPriceX128, uint256 newPriceX128)
        internal pure returns (uint256) {
        // EMA = K * (Current Price - Previous EMA) + Previous EMA
        if (oldPriceX128 > newPriceX128) {
            return oldPriceX128 -
                FullMath.mulDiv(emaKx128(i), oldPriceX128 - newPriceX128, FixedPoint128.Q128) ;
        } else {
            return oldPriceX128 +
                FullMath.mulDiv(emaKx128(i), newPriceX128 - oldPriceX128, FixedPoint128.Q128);
        }
    }

    function emaKx128(uint256 i) private pure returns (uint256) {
        if (i==0 || i==1 || i==2) {
            return FixedPoint128.Q128 * 2 / 2;
        }
        if (i==3) {
            return FixedPoint128.Q128 * 2 / 26;
        }
        if (i==4) {
            return FixedPoint128.Q128 * 2 / 51;
        }
        if (i==5) {
            return FixedPoint128.Q128 * 2 / 101;
        }
        revert("UO: emaKx128-Can't happen");
    }

    function getEmaKey(address path0, address path1) external pure returns (bytes32) {
        return emaKey(path0, path1);
    }

    function emaKey(address path0, address path1) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(path0, path1));
    }

    function newPeriod(uint256 old, uint256 newTime, uint256 period) private pure returns (uint256) {
        return ((newTime - old) / period) * period;
    }
}