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
}