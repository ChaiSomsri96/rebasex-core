// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "./Math.sol";

library PairLogic {
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
