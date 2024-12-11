// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "./Math.sol";

library PairLogic {
    function getDualSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 totalA,
        uint256 totalB
    ) internal pure returns (uint256 liquidityOut) {
        liquidityOut = Math.min((totalLiquidity * amountInA) / totalA, (totalLiquidity * amountInB) / totalB);
    }

    function getSingleSidedMintLiquidityOutAmountA(
        uint256 totalLiquidity,
        uint256 mintAmountA,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 liquidityOut, uint256 swappedReservoirAmountB) {
        // movingAveragePriceA is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we risk `movingAveragePriceA * (totalA + mintAmountA)` overflowing since we multiple a uint224 by the sum
        //   of two uint112s, however:
        //   - `totalA + mintAmountA` don't exceed 2^112 without violating max pool size.
        //   - 2^256/2^112 = 144 bits spare for movingAveragePriceA
        //   - 2^144/2^112 = 2^32 is the maximum price ratio that can be expressed without overflowing
        // Is 2^32 sufficient? Consider a pair with 1 WBTC (8 decimals) and 30,000 USDX (18 decimals)
        // log2((30000*1e18)/1e8) = 48 and as such a greater price ratio that can be handled.
        // Consequently we require a mulDiv that can handle phantom overflow.
        uint256 tokenAToSwap =
            (mintAmountA * totalB) / (Math.mulDiv(movingAveragePriceA, (totalA + mintAmountA), 2 ** 112) + totalB);
        // Here we don't risk undesired overflow because if `tokenAToSwap * movingAveragePriceA` exceeded 2^256 then it
        //   would necessarily mean `swappedReservoirAmountB` exceeded 2^112, which would result in breaking the poolX uint112 limits.
        swappedReservoirAmountB = (tokenAToSwap * movingAveragePriceA) / 2 ** 112;
        // Update totals to account for the fixed price swap
        totalA += tokenAToSwap;
        totalB -= swappedReservoirAmountB;
        uint256 tokenARemaining = mintAmountA - tokenAToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, tokenARemaining, swappedReservoirAmountB, totalA, totalB);
    }

    function getSingleSidedMintLiquidityOutAmountB(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 liquidityOut, uint256 swappedReservoirAmountA) {
        // `movingAveragePriceA` is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow.
        uint256 tokenBToSwap =
            (mintAmountB * totalA) / (((2 ** 112 * (totalB + mintAmountB)) / movingAveragePriceA) + totalA);
        // Inverse price so again we can use it without overflow risk
        swappedReservoirAmountA = (tokenBToSwap * (2 ** 112)) / movingAveragePriceA;
        // Update totals to account for the fixed price swap
        totalA -= swappedReservoirAmountA;
        totalB += tokenBToSwap;
        uint256 tokenBRemaining = mintAmountB - tokenBToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, swappedReservoirAmountA, tokenBRemaining, totalA, totalB);
    }

    function getDualSidedBurnOutputAmounts(uint256 totalLiquidity, uint256 liquidityIn, uint256 totalA, uint256 totalB)
        internal
        pure
        returns (uint256 amountOutA, uint256 amountOutB)
    {
        amountOutA = (totalA * liquidityIn) / totalLiquidity;
        amountOutB = (totalB * liquidityIn) / totalLiquidity;
    }

    function getSingleSidedBurnOutputAmountA(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 amountOutA, uint256 swappedReservoirAmountA) {
        // Calculate what the liquidity is worth in terms of both tokens
        uint256 amountOutB;
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow (because amountOutB must be less than 2*2^112)
        swappedReservoirAmountA = (amountOutB * (2 ** 112)) / movingAveragePriceA;
        amountOutA = amountOutA + swappedReservoirAmountA;
    }

    function getSingleSidedBurnOutputAmountB(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 amountOutB, uint256 swappedReservoirAmountB) {
        // Calculate what the liquidity is worth in terms of both tokens
        uint256 amountOutA;
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Whilst we appear to risk overflow here, the final `swappedReservoirAmountB` needs to be smaller than the reservoir
        //   which soft-caps it at 2^112.
        // As such, any combination of amountOutA and movingAveragePriceA that would overflow would violate the next
        //   check anyway, and we can therefore safely ignore the overflow potential.
        swappedReservoirAmountB = (amountOutA * movingAveragePriceA) / 2 ** 112;
        amountOutB = amountOutB + swappedReservoirAmountB;
    }

    function getProtocolFeeLiquidityMinted(
        uint256 totalLiquidity,
        uint256 kNLast,
        uint256 kNCurr,
        uint24 feeBps,
        uint24 protocolFeeMbps
    ) internal pure returns (uint256 liquidityOut) {
        liquidityOut = (totalLiquidity * (kNCurr - kNLast))
            / ((((1000 * feeBps - protocolFeeMbps) * kNCurr) / protocolFeeMbps) + kNLast);
    }

    function kN(uint256 poolA, uint256 poolB, uint256 plBps) internal pure returns (uint256 _kN) {
        if (plBps == 0) {
            _kN = Math.sqrt(poolA * poolB);
        } else {
            uint256 t1 = plBps * (poolA + poolB);
            uint256 t2 = 4 * plBps * poolA * poolB;
            uint256 t3 = 10_000 - plBps;

            _kN = t1 * 50 + Math.sqrt((t1 * t1 + t2 * t3) * 2500); // The 1/50 was inverted and put into the numerator to keep precision.
        }
    }

    function kD(uint256 plBps) internal pure returns (uint256 _kD) {
        if (plBps == 0) {
            _kD = 1;
        } else {
            uint256 t3 = 10_000 - plBps;
            _kD = Math.sqrt(plBps * t3 * t3); // The 1/50 was inverted and put into the numerator to keep precision.
        }
    }

    function k(uint256 poolA, uint256 poolB, uint256 plBps) internal pure returns (uint256 _k) {
        return kN(poolA, poolB, plBps) / kD(plBps);
    }

    function price(uint256 poolA, uint256 poolB, uint256 plBps) internal pure returns (uint256 currentPrice) {
        if (plBps == 0) {
            currentPrice = (poolA * (2 ** 112)) / poolB;
        } else {
            bool poolAGreater = poolA > poolB;
            uint256 s1 = 20_000 * poolB;
            uint256 s2 = 20_000 * poolA;
            uint256 s3 = plBps * (poolAGreater ? poolA - poolB : poolB - poolA);
            uint256 s4 = Math.sqrt(s3 * s3 + 40_000 * plBps * poolA * poolB);

            if (poolAGreater) {
                currentPrice = ((s1 + s4 + s3) * (2 ** 112)) / (s2 + s4 - s3);
            } else {
                currentPrice = ((s1 + s4 - s3) * (2 ** 112)) / (s2 + s4 + s3);
            }
        }
    }
}
