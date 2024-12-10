// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXPair} from "./interfaces/IRebaseXPair/IRebaseXPair.sol";
import {IRebaseXFactory} from "./interfaces/IRebaseXFactory/IRebaseXFactory.sol";
import {IRebaseXERC20} from "./interfaces/IRebaseXERC20/IRebaseXERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RebaseXERC20} from "./RebaseXERC20.sol";
import {Math} from "./libraries/Math.sol";

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

    /**
     * @dev Calls `_singleSidedTimelock()` before executing the function.
     */
    modifier singleSidedTimelock() {
        _singleSidedTimelock();
        _;
    }

    /**
     * @dev Prevents certain operations from being executed if the price volatility induced timelock has yet to conclude.
     */
    function _singleSidedTimelock() internal view {
        if (block.timestamp < singleSidedTimelockDeadline) {
            revert SingleSidedTimelock();
        }
    }

    /**
     * @dev Calls `_checkPaused()` before executing the function.
     */
    modifier checkPaused() {
        _checkPaused();
        _;
    }

    /**
     * @dev Prevents operations from being executed if the Pair is currently paused.
     */
    function _checkPaused() internal view {
        if (isPaused == 1) {
            revert Paused();
        }
    }

    /**
     * @dev Calls `_sendOrRefundFee()` before executing the function.
     */
    modifier sendOrRefundFee() {
        _sendOrRefundFee();
        _;
    }

    /**
     * @dev Called whenever an LP wants to burn their LP tokens to make sure they get their fair share of fees.
     * If `feeTo` is defined, `balanceOf(address(this))` gets transferred to `feeTo`.
     * If `feeTo` is not defined, `balanceOf(address(this))` gets burned and the LP tokens all grow in value.
     */
    function _sendOrRefundFee() internal {
        if (balanceOf[address(this)] > 0) {
            address feeTo = IRebaseXFactory(factory).feeTo();
            if (feeTo != address(0)) {
                _transfer(address(this), feeTo, balanceOf[address(this)]);
            } else {
                _burn(address(this), balanceOf[address(this)]);
            }
        }
    }

    /**
     * @dev Calls `_onlyFactory()` before executing the function.
     */
    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    /**
     * @dev Prevents operations from being executed if the caller is not the factory.
     */
    function _onlyFactory() internal view {
        if (msg.sender != factory) {
            revert Forbidden();
        }
    }

    constructor() {
        factory = msg.sender;
        IRebaseXFactory.PairCreationParameters memory pairCreationParameters;

        (token0, token1, plBps, feeBps, pairCreationParameters) =
            IRebaseXFactory(factory).lastCreatedTokensAndParameters();
        movingAverageWindow = pairCreationParameters.movingAverageWindow;
        maxVolatilityBps = pairCreationParameters.maxVolatilityBps;
        minTimelockDuration = pairCreationParameters.minTimelockDuration;
        maxTimelockDuration = pairCreationParameters.maxTimelockDuration;
        maxSwappableReservoirLimitBps = pairCreationParameters.maxSwappableReservoirLimitBps;
        swappableReservoirGrowthWindow = pairCreationParameters.swappableReservoirGrowthWindow;
        protocolFeeMbps = pairCreationParameters.protocolFeeMbps;
        minBasinDuration = pairCreationParameters.minBasinDuration;
        maxBasinDuration = pairCreationParameters.maxBasinDuration;
    }

    /**
     * @inheritdoc IRebaseXERC20
     */
    function name() external view override(RebaseXERC20, IRebaseXERC20) returns (string memory _name) {
        _name = IRebaseXFactory(factory).tokenName();
    }

    /**
     * @inheritdoc IRebaseXERC20
     */
    function symbol() external view override(RebaseXERC20, IRebaseXERC20) returns (string memory _symbol) {
        _symbol = IRebaseXFactory(factory).tokenSymbol();
    }

    /**
     * @dev Utility function to get the total amount of `token0` and `token1` held by the Pair.
     * @return total0 The total amount of `token0` held by the Pair
     * @return total1 The total amount of `token1` held by the Pair
     */
    function _getTotals() internal view returns (uint256 total0, uint256 total1) {
        total0 = IERC20(token0).balanceOf(address(this));
        total1 = IERC20(token1).balanceOf(address(this));
    }

    /**
     * @dev Updates `price0CumulativeLast` and `price1CumulativeLast` based on the current timestamp.
     * @param pool0 The `token0` active liquidity balance at the start of the ongoing swap
     * @param pool1 The `token1` active liquidity balance at the start of the ongoing swap
     */
    function _updatePriceCumulative(uint256 pool0, uint256 pool1) internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            // underflow is desired
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        if (timeElapsed > 0 && pool0 != 0 && pool1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast += _price(pool1, pool0) * timeElapsed;
                price1CumulativeLast += _price(pool0, pool1) * timeElapsed;
            }
            blockTimestampLast = blockTimestamp;
        }
    }

    /**
     * @param poolALower The lower bound for the active liquidity balance of the non-fixed token
     * @param poolB The active liquidity balance of the fixed token
     * @param _poolALast The active liquidity balance at the end of the last swap for the non-fixed token
     * @param _poolBLast The active liquidity balance at the end of the last swap for the fixed token
     * @return closestBound The bound for the active liquidity balance of the non-fixed token that produces a price ratio closest to last swap price
     */
    function _closestBound(uint256 poolALower, uint256 poolB, uint256 _poolALast, uint256 _poolBLast)
        internal
        pure
        returns (uint256 closestBound)
    {
        if ((2 * poolALower * _poolBLast) + _poolBLast < 2 * _poolALast * poolB) {
            closestBound = poolALower + 1;
        } else {
            closestBound = poolALower;
        }
    }

    function _adjustedTotal(uint256 total, uint256 poolLast, uint256 totalLast)
        internal
        view
        returns (uint256 adjustedTotal)
    {
        if (poolLast == 0 || totalLast == 0 || maxBasinDuration == 0) {
            adjustedTotal = total;
        } else {
            uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
            uint256 numerator;
            unchecked {
                numerator = blockTimestamp - blockTimestampLast;
            }
            // If leq than minBasinDuration has past, timeDelta <= minBasinDuration, return pool = total * (pool0Last / total0Last)
            // If entire maxBasinDuration has past, timeDelta >= maxBasinDuration, return total
            numerator = Math.min(Math.max(numerator, minBasinDuration), maxBasinDuration) - minBasinDuration;
            uint256 pool = (total * poolLast) / totalLast;
            adjustedTotal = pool + ((total - pool) * numerator) / (maxBasinDuration - minBasinDuration);
        }
    }
    
    /**
     * @param total0 The total amount of `token0` held by the Pair
     * @param total1 The total amount of `token1` held by the Pair
     * @return lb The current active and inactive liquidity balances
     */
    function _getLiquidityBalances(uint256 total0, uint256 total1)
        internal
        view
        returns (LiquidityBalances memory lb)
    {
        uint256 _pool0Last = uint256(pool0Last);
        uint256 _pool1Last = uint256(pool1Last);
        uint256 _total0Last = uint256(total0Last);
        uint256 _total1Last = uint256(total1Last);

        if (_pool0Last == 0 || _pool1Last == 0 || _total0Last == 0 || _total1Last == 0) {
            // Before Pair is initialized by first dual mint just return zeroes
        } else if (total0 == 0 || total1 == 0) {
            // Save the extra calculations and just return zeroes
        } else {
            uint256 adjustedTotal0 = _adjustedTotal(total0, _pool0Last, _total0Last);
            uint256 adjustedTotal1 = _adjustedTotal(total1, _pool1Last, _total1Last);

            if (adjustedTotal0 * _pool1Last < adjustedTotal1 * _pool0Last) {
                lb.pool0 = adjustedTotal0;
                // pool0Last/pool1Last == pool0/pool1 => pool1 == (pool0*pool1Last)/pool0Last
                // pool1Last/pool0Last == pool1/pool0 => pool1 == (pool0*pool1Last)/pool0Last
                lb.pool1 = (lb.pool0 * _pool1Last) / _pool0Last;
                lb.pool1 = _closestBound(lb.pool1, lb.pool0, _pool1Last, _pool0Last);
                // reservoir0 is zero, so no need to set it
                lb.reservoir1 = adjustedTotal1 - lb.pool1;
                lb.basin0 = total0 - adjustedTotal0;
                lb.basin1 = total1 - adjustedTotal1;
            } else {
                lb.pool1 = adjustedTotal1;
                // pool0Last/pool1Last == pool0/pool1 => pool0 == (pool1*pool0Last)/pool1Last
                // pool1Last/pool0Last == pool1/pool0 => pool0 == (pool1*pool0Last)/pool1Last
                lb.pool0 = (lb.pool1 * _pool0Last) / _pool1Last;
                lb.pool0 = _closestBound(lb.pool0, lb.pool1, _pool0Last, _pool1Last);
                // reservoir1 is zero, so no need to set it
                lb.reservoir0 = adjustedTotal0 - lb.pool0;
                lb.basin0 = total0 - adjustedTotal0;
                lb.basin1 = total1 - adjustedTotal1;
            }
            if (lb.pool0 > type(uint112).max || lb.pool1 > type(uint112).max) {
                revert Overflow();
            }
        }
    }

    function _price(uint256 pool0, uint256 pool1) internal view virtual returns (uint256 price);

    function _k(uint256 pool0, uint256 pool1) internal view virtual returns (uint256 k);

    /**
     * @dev Calculates current price volatility and initiates a timelock scaled to the volatility size.
     * This timelock prohibits single-sided operations from being executed until enough time has passed for the timelock
     *   to conclude.
     * This protects against attempts to manipulate the price that the reservoir is valued at during single-sided operations.
     * @param _movingAveragePrice0 The current `movingAveragePrice0` value
     * @param pool0New The `token0` active liquidity balance at the end of the ongoing swap
     * @param pool1New The `token1` active liquidity balance at the end of the ongoing swap
     */
    function _updateSingleSidedTimelock(uint256 _movingAveragePrice0, uint112 pool0New, uint112 pool1New) internal {
        uint256 newPrice0 = _price(pool1New, pool0New);
        uint256 priceDifference;
        if (newPrice0 > _movingAveragePrice0) {
            priceDifference = newPrice0 - _movingAveragePrice0;
        } else {
            priceDifference = _movingAveragePrice0 - newPrice0;
        }
        // priceDifference / ((_movingAveragePrice0 * maxVolatilityBps)/BPS)
        uint32 _minTimelockDuration = minTimelockDuration;
        uint32 _maxTimelockDuration = maxTimelockDuration;
        uint256 timelock = Math.min(
            _minTimelockDuration
                + (
                    (priceDifference * BPS * (_maxTimelockDuration - _minTimelockDuration))
                        / (_movingAveragePrice0 * maxVolatilityBps)
                ),
            _maxTimelockDuration
        );
        uint120 timelockDeadline = uint120(block.timestamp + timelock);
        if (timelockDeadline > singleSidedTimelockDeadline) {
            singleSidedTimelockDeadline = timelockDeadline;
        }
    }

    /**
     * @dev Calculates the current limit on the number of reservoir tokens that can be exchanged during a single-sided
     *   operation.
     * This is based on corresponding active liquidity size and time since and size of the last single-sided operation.
     * @param poolA The active liquidity balance for the non-zero reservoir token
     * @return swappableReservoir The amount of non-zero reservoir token that can be exchanged as part of a single-sided operation
     */
    function _getSwappableReservoirLimit(uint256 poolA) internal view returns (uint256 swappableReservoir) {
        // Calculate the maximum the limit can be as a fraction of the corresponding active liquidity
        uint256 maxSwappableReservoirLimit = (poolA * maxSwappableReservoirLimitBps) / BPS;
        uint256 _swappableReservoirLimitReachesMaxDeadline = swappableReservoirLimitReachesMaxDeadline;
        if (_swappableReservoirLimitReachesMaxDeadline > block.timestamp) {
            // If the current deadline is still active then calculate the progress towards reaching it
            uint32 _swappableReservoirGrowthWindow = swappableReservoirGrowthWindow;
            uint256 progress =
                _swappableReservoirGrowthWindow - (_swappableReservoirLimitReachesMaxDeadline - block.timestamp);
            // The greater the progress, the closer to the max limit we get
            swappableReservoir = (maxSwappableReservoirLimit * progress) / _swappableReservoirGrowthWindow;
        } else {
            // If the current deadline has expired then the full limit is available
            swappableReservoir = maxSwappableReservoirLimit;
        }
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function getSwappableReservoirLimit() external view returns (uint256 swappableReservoirLimit) {
        (uint256 total0, uint256 total1) = _getTotals();
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);

        if (lb.reservoir0 > 0) {
            swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool0);
        } else {
            swappableReservoirLimit = _getSwappableReservoirLimit(lb.pool1);
        }
    }

    /**
     * @dev Updates the value of `swappableReservoirLimitReachesMaxDeadline` which is the time at which the maximum
     *   amount of inactive liquidity tokens can be exchanged during a single-sided operation.
     * @dev Assumes `swappedAmountA` is less than or equal to `maxSwappableReservoirLimit`
     * @param poolA The active liquidity balance for the non-zero reservoir token
     * @param swappedAmountA The amount of non-zero reservoir tokens that were exchanged during the ongoing single-sided
     *   operation
     */
    function _updateSwappableReservoirDeadline(uint256 poolA, uint256 swappedAmountA) internal {
        // Calculate the maximum the limit can be as a fraction of the corresponding active liquidity
        uint256 maxSwappableReservoirLimit = (poolA * maxSwappableReservoirLimitBps) / BPS;
        // Calculate how much time delay the swap instigates
        uint256 delay;
        // Check non-zero to avoid div by zero error
        if (maxSwappableReservoirLimit > 0) {
            // Since `swappedAmountA/maxSwappableReservoirLimit <= 1`, `delay <= swappableReservoirGrowthWindow`
            delay = (swappableReservoirGrowthWindow * swappedAmountA + maxSwappableReservoirLimit - 1)
                / maxSwappableReservoirLimit;
        } else {
            // If it is zero then it's in an extreme condition and a delay is most appropriate way to handle it
            delay = swappableReservoirGrowthWindow;
        }
        // Apply the delay
        uint256 _swappableReservoirLimitReachesMaxDeadline = swappableReservoirLimitReachesMaxDeadline;
        if (_swappableReservoirLimitReachesMaxDeadline > block.timestamp) {
            // If the current deadline hasn't expired yet then add the delay to it
            swappableReservoirLimitReachesMaxDeadline = uint120(_swappableReservoirLimitReachesMaxDeadline + delay);
        } else {
            // If the current deadline has expired already then add the delay to the current time, so that the full
            //   delay is still applied
            swappableReservoirLimitReachesMaxDeadline = uint120(block.timestamp + delay);
        }
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function getIsPaused() external view returns (bool _isPaused) {
        _isPaused = isPaused == 1;
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function setIsPaused(bool isPausedNew) external onlyFactory {
        if (isPausedNew) {
            isPaused = 1;
        } else {
            singleSidedTimelockDeadline = uint120(block.timestamp + maxTimelockDuration);
            isPaused = 0;
        }
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function getLiquidityBalances()
        external
        view
        returns (
            uint112 _pool0,
            uint112 _pool1,
            uint112 _reservoir0,
            uint112 _reservoir1,
            uint112 _basin0,
            uint112 _basin1,
            uint32 _blockTimestampLast
        )
    {
        (uint256 total0, uint256 total1) = _getTotals();
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        _pool0 = uint112(lb.pool0);
        _pool1 = uint112(lb.pool1);
        _reservoir0 = uint112(lb.reservoir0);
        _reservoir1 = uint112(lb.reservoir1);
        _basin0 = uint112(lb.basin0);
        _basin1 = uint112(lb.basin1);
        _blockTimestampLast = blockTimestampLast;
    }
}
