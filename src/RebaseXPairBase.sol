// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXPair} from "./interfaces/IRebaseXPair/IRebaseXPair.sol";
import {RebaseXERC20} from "./RebaseXERC20.sol";

abstract contract RebaseXPairBase is IRebaseXPair, RebaseXERC20 {
    /**
     * @inheritdoc IRebaseXPair
     */
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /**
     * @dev Denominator for basis points.
     */
    uint256 internal constant BPS = 10_000;

    /**
     * @dev Minimum pool balance
     */
    uint256 internal constant POOL_MIN = 1;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public movingAverageWindow;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint16 public maxVolatilityBps;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public minTimelockDuration;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public maxTimelockDuration;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint16 public maxSwappableReservoirLimitBps;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public swappableReservoirGrowthWindow;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public minBasinDuration;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint32 public maxBasinDuration;

    /**
     * @inheritdoc IRebaseXPair
     */
    address public immutable factory;

    /**
     * @inheritdoc IRebaseXPair
     */
    address public immutable token0;

    /**
     * @inheritdoc IRebaseXPair
     */
    address public immutable token1;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint16 public immutable plBps; // This is the value of p_{L} in the form of (p_{L} * 10_000). Must divide by 10_000 when using.

    /**
     * @inheritdoc IRebaseXPair
     */
    uint16 public immutable feeBps; // 0.3% fee

    /**
     * @dev The active `token0` liquidity amount following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal pool0Last;

    /**
     * @dev The active `token1` liquidity amount following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal pool1Last;

    /**
     * @dev The total `token0` balance of the pair following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal total0Last;

    /**
     * @dev The total `token1` balance of the pair following the last swap.
     * This value is used to determine active liquidity balances after potential rebases until the next future swap.
     */
    uint112 internal total1Last;

    /**
     * @dev The timestamp of the block that the last swap occurred in.
     */
    uint32 internal blockTimestampLast;   

    /**
     * @inheritdoc IRebaseXPair
     */
    uint256 public price0CumulativeLast;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint256 public price1CumulativeLast;

    /**
     * @dev The value of `movingAveragePrice0` at the time of the last swap.
     */
    uint256 internal movingAveragePrice0Last;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint120 public singleSidedTimelockDeadline;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint120 public swappableReservoirLimitReachesMaxDeadline;

    /**
     * @inheritdoc IRebaseXPair
     */
    uint24 public protocolFeeMbps;

    /**
     * @dev Whether or not the pair is isPaused (paused = 1, unPaused = 0).
     * When paused, all operations other than dual-sided burning LP tokens are disabled.
     */
    uint8 internal isPaused;

    /**
     * @dev Value to track the state of the re-entrancy guard.
     */
    uint8 private unlocked = 1;

    /**
     * @dev Guards against re-entrancy.
     */
    modifier lock() {
        _lockPrefix();
        _;
        unlocked = 1;
    }

    /**
     * @dev Prefix to the lock function to prevent re-entrancy.
     */
    function _lockPrefix() internal {
        if (unlocked == 0) {
            revert Locked();
        }
        unlocked = 0;
    }
}