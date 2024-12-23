// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXPairErrors} from "./IRebaseXPairErrors.sol";
import {IRebaseXPairEvents} from "./IRebaseXPairEvents.sol";
import {IRebaseXERC20} from "../IRebaseXERC20/IRebaseXERC20.sol";

interface IRebaseXPair is IRebaseXPairErrors, IRebaseXPairEvents, IRebaseXERC20 {
    /**
     * @dev A set of liquidity values.
     * @param pool0 The active `token0` liquidity
     * @param pool1 The active `token1` liquidity
     * @param reservoir0 The inactive `token0` liquidity
     * @param reservoir1 The inactive `token1` liquidity
     * @param basin0 The temporarily locked `token0` liquidity
     * @param basin1 The temporarily locked `token1` liquidity
     */
    struct LiquidityBalances {
        uint256 pool0;
        uint256 pool1;
        uint256 reservoir0;
        uint256 reservoir1;
        uint256 basin0;
        uint256 basin1;
    }

    /**
     * @notice The smallest value that {IRebaseXERC20-totalSupply} can be.
     * @dev After the first mint the total liquidity (represented by the liquidity token total supply) can never drop below this value.
     *
     * This is to protect against an attack where the attacker mints a very small amount of liquidity, and then donates pool tokens to skew the ratio.
     * This results in future minters receiving no liquidity tokens when they deposit.
     * By enforcing a minimum liquidity value this attack becomes prohibitively expensive to execute.
     * @return MINIMUM_LIQUIDITY The MINIMUM_LIQUIDITY value
     */
    function MINIMUM_LIQUIDITY() external pure returns (uint256 MINIMUM_LIQUIDITY);

    /**
     * @notice The duration for which the moving average is calculated for.
     * @return _movingAverageWindow The value of movingAverageWindow
     */
    function movingAverageWindow() external view returns (uint32 _movingAverageWindow);

    /**
     * @notice Updates the movingAverageWindow parameter of the pair.
     * This can only be called by the Factory address.
     * @param newMovingAverageWindow The new value for movingAverageWindow
     */
    function setMovingAverageWindow(uint32 newMovingAverageWindow) external;

    /**
     * @notice Numerator (over 10_000) of the threshold when price volatility triggers maximum single-sided timelock duration.
     * @return _maxVolatilityBps The value of maxVolatilityBps
     */
    function maxVolatilityBps() external view returns (uint16 _maxVolatilityBps);

    /**
     * @notice Updates the maxVolatilityBps parameter of the pair.
     * This can only be called by the Factory address.
     * @param newMaxVolatilityBps The new value for maxVolatilityBps
     */
    function setMaxVolatilityBps(uint16 newMaxVolatilityBps) external;

    /**
     * @notice How long the minimum singled-sided timelock lasts for.
     * @return _minTimelockDuration The value of minTimelockDuration
     */
    function minTimelockDuration() external view returns (uint32 _minTimelockDuration);

    /**
     * @notice Updates the minTimelockDuration parameter of the pair.
     * This can only be called by the Factory address.
     * @param newMinTimelockDuration The new value for minTimelockDuration
     */
    function setMinTimelockDuration(uint32 newMinTimelockDuration) external;

    /**
     * @notice How long the maximum singled-sided timelock lasts for.
     * @return _maxTimelockDuration The value of maxTimelockDuration
     */
    function maxTimelockDuration() external view returns (uint32 _maxTimelockDuration);

    /**
     * @notice Updates the maxTimelockDuration parameter of the pair.
     * This can only be called by the Factory address.
     * @param newMaxTimelockDuration The new value for maxTimelockDuration
     */
    function setMaxTimelockDuration(uint32 newMaxTimelockDuration) external;

    /**
     * @notice Numerator (over 10_000) of the fraction of the pool balance that acts as the maximum limit on how much of the reservoir
     * can be swapped in a given timeframe.
     * @return _maxSwappableReservoirLimitBps The value of maxSwappableReservoirLimitBps
     */
    function maxSwappableReservoirLimitBps() external view returns (uint16 _maxSwappableReservoirLimitBps);

    /**
     * @notice Updates the maxSwappableReservoirLimitBps parameter of the pair.
     * This can only be called by the Factory address.
     * @param newMaxSwappableReservoirLimitBps The new value for maxSwappableReservoirLimitBps
     */
    function setMaxSwappableReservoirLimitBps(uint16 newMaxSwappableReservoirLimitBps) external;

    /**
     * @notice How much time it takes for the swappable reservoir value to grow from nothing to its maximum value.
     * @return _swappableReservoirGrowthWindow The value of swappableReservoirGrowthWindow
     */
    function swappableReservoirGrowthWindow() external view returns (uint32 _swappableReservoirGrowthWindow);

    /**
     * @notice Updates the swappableReservoirGrowthWindow parameter of the pair.
     * This can only be called by the Factory address.
     * @param newSwappableReservoirGrowthWindow The new value for swappableReservoirGrowthWindow
     */
    function setSwappableReservoirGrowthWindow(uint32 newSwappableReservoirGrowthWindow) external;

    /**
     * @notice The address of the {RebaseXFactory} instance used to create this Pair.
     * @dev Set to `msg.sender` in the Pair constructor.
     * @return factory The factory address
     */
    function factory() external view returns (address factory);

    /**
     * @notice The address of the first sorted token.
     * @return token0 The token address
     */
    function token0() external view returns (address token0);

    /**
     * @notice The address of the second sorted token.
     * @return token1 The token address
     */
    function token1() external view returns (address token1);

    /**
     * @notice The time-weighted average price of the Pair.
     * The price is of `token0` in terms of `token1`.
     * @dev The price is represented as a [UQ112x112](https://en.wikipedia.org/wiki/Q_(number_format)) to maintain precision.
     * Consequently this value must be divided by `2^112` to get the actual price.
     *
     * Because of the time weighting, `price0CumulativeLast` must also be divided by the total Pair lifetime to get the average price over that time period.
     * @return price0CumulativeLast The current cumulative `token0` price
     */
    function price0CumulativeLast() external view returns (uint256 price0CumulativeLast);

    /**
     * @notice The time-weighted average price of the Pair.
     * The price is of `token1` in terms of `token0`.
     * @dev The price is represented as a [UQ112x112](https://en.wikipedia.org/wiki/Q_(number_format)) to maintain precision.
     * Consequently this value must be divided by `2^112` to get the actual price.
     *
     * Because of the time weighting, `price1CumulativeLast` must also be divided by the total Pair lifetime to get the average price over that time period.
     * @return price1CumulativeLast The current cumulative `token1` price
     */
    function price1CumulativeLast() external view returns (uint256 price1CumulativeLast);

    /**
     * @notice The timestamp for when the single-sided timelock concludes.
     * The timelock is initiated based on price volatility of swaps over the last `movingAverageWindow`, and can be
     *   extended by new swaps if they are sufficiently volatile.
     * The timelock protects against attempts to manipulate the price that is used to valuate the reservoir tokens during
     *   single-sided operations.
     * It also guards against general legitimate volatility, as it is preferable to defer single-sided operations until
     *   it is clearer what the market considers the price to be.
     * @return singleSidedTimelockDeadline The current deadline timestamp
     */
    function singleSidedTimelockDeadline() external view returns (uint120 singleSidedTimelockDeadline);

    /**
     * @notice The timestamp by which the amount of reservoir tokens that can be exchanged during a single-sided operation
     *   reaches its maximum value.
     * This maximum value is not necessarily the entirety of the reservoir, instead being calculated as a fraction of the
     *   corresponding token's active liquidity.
     * @return swappableReservoirLimitReachesMaxDeadline The current deadline timestamp
     */
    function swappableReservoirLimitReachesMaxDeadline()
        external
        view
        returns (uint120 swappableReservoirLimitReachesMaxDeadline);

    /**
     * @notice Returns the current limit on the number of reservoir tokens that can be exchanged during a single-sided mint/burn operation.
     * @return swappableReservoirLimit The amount of reservoir token that can be exchanged
     */
    function getSwappableReservoirLimit() external view returns (uint256 swappableReservoirLimit);

    /**
     * @notice Whether the Pair is currently paused
     * @return _isPaused The paused state
     */
    function getIsPaused() external view returns (bool _isPaused);

    /**
     * @notice Updates the pause state.
     * This can only be called by the Factory address.
     * @param isPausedNew The new value for isPaused
     */
    function setIsPaused(bool isPausedNew) external;

    /**
     * @notice The current `movingAveragePrice0` value, based on the current block timestamp.
     * @dev This is the `token0` price, time weighted to prevent manipulation.
     *
     * The price is represented as a [UQ112x112](https://en.wikipedia.org/wiki/Q_(number_format)) to maintain precision.
     * It is used to valuate the reservoir tokens that are exchanged during single-sided operations.
     * @return _movingAveragePrice0 The current `movingAveragePrice0` value
     */
    function movingAveragePrice0() external view returns (uint256 _movingAveragePrice0);

    /**
     * @notice Mints new liquidity tokens to `to` based on `amountIn0` of `token0` and `amountIn1  of`token1` deposited.
     * Expects both tokens to be deposited in a ratio that matches the current Pair price.
     * @dev The token deposits are deduced to be the delta between token balance before and after the transfers in order to account for unusual tokens.
     * @param amountIn0 The amount of `token0` that should be transferred in from the user
     * @param amountIn1 The amount of `token1` that should be transferred in from the user
     * @param to The account that receives the newly minted liquidity tokens
     * @return liquidityOut THe amount of liquidity tokens minted
     */
    function mint(uint256 amountIn0, uint256 amountIn1, address to) external returns (uint256 liquidityOut);

    /**
     * @notice Mints new liquidity tokens to `to` based on how much `token0` or `token1` has been deposited.
     * The token transferred is the one that the Pair does not have a non-zero inactive liquidity balance for.
     * Expects only one token to be deposited, so that it can be paired with the other token's inactive liquidity.
     * @dev The token deposits are deduced to be the delta between token balance before and after the transfers in order to account for unusual tokens.
     * @param amountIn The amount of tokens that should be transferred in from the user
     * @param to The account that receives the newly minted liquidity tokens
     * @return liquidityOut THe amount of liquidity tokens minted
     */
    function mintWithReservoir(uint256 amountIn, address to) external returns (uint256 liquidityOut);

    /**
     * @notice Burns `liquidityIn` liquidity tokens to redeem to `to` the corresponding `amountOut0` of `token0` and `amountOut1` of `token1`.
     * @param liquidityIn The amount of liquidity tokens to burn
     * @param to The account that receives the redeemed tokens
     * @return amountOut0 The amount of `token0` that the liquidity tokens are redeemed for
     * @return amountOut1 The amount of `token1` that the liquidity tokens are redeemed for
     */
    function burn(uint256 liquidityIn, address to) external returns (uint256 amountOut0, uint256 amountOut1);

    /**
     * @notice Burns `liquidityIn` liquidity tokens to redeem to `to` the corresponding `amountOut0` of `token0` and `amountOut1` of `token1`.
     * Only returns tokens from the non-zero inactive liquidity balance, meaning one of `amountOut0` and `amountOut1` will be zero.
     * @param liquidityIn The amount of liquidity tokens to burn
     * @param to The account that receives the redeemed tokens
     * @return amountOut0 The amount of `token0` that the liquidity tokens are redeemed for
     * @return amountOut1 The amount of `token1` that the liquidity tokens are redeemed for
     */
    function burnFromReservoir(uint256 liquidityIn, address to)
        external
        returns (uint256 amountOut0, uint256 amountOut1);

    /**
     * @notice Swaps one token for the other, taking `amountIn0` of `token0` and `amountIn1` of `token1` from the sender and sending `amountOut0` of `token0` and `amountOut1` of `token1` to `to`.
     * The price of the swap is determined by maintaining the "K Invariant".
     * A 0.3% fee is collected to distribute between liquidity providers and the protocol.
     * @dev The token deposits are deduced to be the delta between the current Pair contract token balances and the last stored balances.
     * Optional calldata can be passed to `data`, which will be used to confirm the output token transfer with `to` if `to` is a contract that implements the {IRebaseXCallee} interface.
     * @param amountIn0 The amount of `token0` that the sender sends
     * @param amountIn1 The amount of `token1` that the sender sends
     * @param amountOut0 The amount of `token0` that the recipient receives
     * @param amountOut1 The amount of `token1` that the recipient receives
     * @param to The account that receives the swap output
     */
    function swap(uint256 amountIn0, uint256 amountIn1, uint256 amountOut0, uint256 amountOut1, address to) external;

    /**
     * @notice The minimum price, p_{L}, in Bps form for the pair.
     * @return _plBps The value of the p_{L} in basis points
     */
    function plBps() external view returns (uint16 _plBps);

    /**
     * @notice Returns the fee for the pair.
     * @return _feeBps The fee in bps
     */
    function feeBps() external view returns (uint16 _feeBps);

    /**
     * @notice Returns the protocol fee for the pair.
     * @return _protocolFeeMbps The protocol fee in milli-bps (multiplied by 10^7)
     */
    function protocolFeeMbps() external view returns (uint24 _protocolFeeMbps);

    /**
     * @notice Updates protocolFeeMbps for the pair.
     * This can only be called by the Factory address. Must be less than or equal to feeBps * 1000.
     * @param newProtocolFeeMbps The new protocol fee in mill-bps
     */
    function setProtocolFeeMbps(uint24 newProtocolFeeMbps) external;

    /**
     * @notice Amount of time before any of the basin unlocks into the pools and reservoir from the the time of the last swap
     * @return _minBasinDuration The value of minBasinDuration
     */
    function minBasinDuration() external view returns (uint32 _minBasinDuration);

    /**
     * @notice Updates the minBasinDuration for the pair.
     * This can only be called by the Factory address.
     * @param newMinBasinDuration The new minBasinDuration value
     */
    function setMinBasinDuration(uint32 newMinBasinDuration) external;

    /**
     * @notice Amount of time before all of the basin unlocks into the pools and reservoir from the the time of the last swap
     * @return _maxBasinDuration The value of maxBasinDuration
     */
    function maxBasinDuration() external view returns (uint32 _maxBasinDuration);

    /**
     * @notice Updates the maxBasinDuration for the pair.
     * This can only be called by the Factory address.
     * @param newMaxBasinDuration The new maxBasinDuration value
     */
    function setMaxBasinDuration(uint32 newMaxBasinDuration) external;

    /**
     * @notice Returns the current spot price of the pair.
     * @return price The current spot price of the pair
     */
    function currentPrice() external view returns (uint256 price);

    /**
     * @notice Get the current liquidity values.
     * @return _pool0 The active `token0` liquidity
     * @return _pool1 The active `token1` liquidity
     * @return _reservoir0 The inactive `token0` liquidity
     * @return _reservoir1 The inactive `token1` liquidity
     * @return _basin0 The temporarily locked `token0` liquidity
     * @return _basin1 The temporarily locked `token1` liquidity
     * @return _blockTimestampLast The timestamp of when the price was last updated
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
        );
}
