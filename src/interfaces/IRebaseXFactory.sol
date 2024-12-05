// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXFactoryErrors} from "./IRebaseXFactoryErrors.sol";
import {IRebaseXFactoryEvents} from "./IRebaseXFactoryEvents.sol";

interface IRebaseXFactory is IRebaseXFactoryErrors, IRebaseXFactoryEvents {
    /**
     * @dev These are immutable parameters in a pair that define it as a category.
     * @param plBps The pL value in bps
     * @param feeBps The fee value in bps
     */
    struct CategoryParameters {
        uint16 plBps;
        uint16 feeBps;
    }

    /**
     * @dev The set of parameters used to create a new pair.
     * @param movingAverageWindow The moving average window
     * @param maxVolatilityBps The max volatility bps
     * @param minTimelockDuration The minimum time lock duration
     * @param maxTimelockDuration The maximum time lock duration
     * @param maxSwappableReservoirLimitBps The max swappable reservoir limit bps
     * @param swappableReservoirGrowthWindow The swappable reservoir growth window
     * @param protocolFeeMbps The protocol fee value in milli-bps
     * @param minBasinDuration The minimum basin duration
     * @param maxBasinDuration The maximum basin duration
     */
    struct PairCreationParameters {
        uint32 movingAverageWindow;
        uint16 maxVolatilityBps;
        uint32 minTimelockDuration;
        uint32 maxTimelockDuration;
        uint16 maxSwappableReservoirLimitBps;
        uint32 swappableReservoirGrowthWindow;
        uint24 protocolFeeMbps;
        uint32 minBasinDuration;
        uint32 maxBasinDuration;
    }

    /**
     * @notice Get the (unique) Pair address created for the given combination of `tokenA` and `tokenB`.
     * If the Pair does not exist then zero address is returned.
     * @param tokenA The first unsorted token
     * @param tokenB The second unsorted token
     * @param plBps The pL value in bps
     * @param feeBps The fee value in bps
     * @return pair The address of the Pair instance
     */
    function getPair(address tokenA, address tokenB, uint16 plBps, uint16 feeBps)
        external
        view
        returns (address pair);

    /**
     * @notice Get the total number of supported categories.
     */
    function supportedCategoriesLength() external view returns (uint256 count);

    /**
     * @notice Creates a new {ButtonswapPair} instance for the given unsorted tokens `tokenA` and `tokenB`.
     * @dev The tokens are sorted later, but can be provided to this method in either order.
     * @param tokenA The first unsorted token address
     * @param tokenB The second unsorted token address
     * @param plBps The pL value in bps
     * @param feeBps The fee value in bps
     * @return pair The address of the new {ButtonswapPair} instance
     */
    function createPair(address tokenA, address tokenB, uint16 plBps, uint16 feeBps) external returns (address pair);

    /**
     * @notice Updates the default parameters used for new pairs.
     * This can only be called by the `paramSetter` address.
     * @param plBps The plBps that the new default parameters will be associated with
     * @param feeBps The feeBps that the new default parameters will be associated with
     * @param newDefaultMovingAverageWindow The new defaultMovingAverageWindow
     * @param newDefaultMaxVolatilityBps The new defaultMaxVolatilityBps
     * @param newDefaultMinTimelockDuration The new defaultMinTimelockDuration
     * @param newDefaultMaxTimelockDuration The new defaultMaxTimelockDuration
     * @param newDefaultMaxSwappableReservoirLimitBps The new defaultMaxSwappableReservoirLimitBps
     * @param newDefaultSwappableReservoirGrowthWindow The new defaultSwappableReservoirGrowthWindow
     * @param newDefaultProtocolFeeMbps The new defaultProtocolFeeMbps
     */
    function setDefaultParameters(
        uint16 plBps,
        uint16 feeBps,
        uint32 newDefaultMovingAverageWindow,
        uint16 newDefaultMaxVolatilityBps,
        uint32 newDefaultMinTimelockDuration,
        uint32 newDefaultMaxTimelockDuration,
        uint16 newDefaultMaxSwappableReservoirLimitBps,
        uint32 newDefaultSwappableReservoirGrowthWindow,
        uint24 newDefaultProtocolFeeMbps,
        uint32 newDefaultMinBasinDuration,
        uint32 newDefaultMaxSipohDuration
    ) external;

    /**
     * @notice Removes the default parameters used for new pairs.
     * This can only be called by the `paramSetter` address.
     * @param plBps The plBps that the default parameters will be removed from
     * @param feeBps The feeBps that the default parameters will be removed from
     */
    function removeDefaultParameters(uint16 plBps, uint16 feeBps) external;

    /**
     * @notice Returns the last token pair created and the parameters used.
     * @return token0 The first token address
     * @return token1 The second token address
     * @return plBps The pL value in bps
     * @return feeBps The fee value in bps
     * @return pairCreationParameters The parameters used to create the last pair
     */
    function lastCreatedTokensAndParameters()
        external
        view
        returns (
            address token0,
            address token1,
            uint16 plBps,
            uint16 feeBps,
            PairCreationParameters memory pairCreationParameters
        );

    /**
     * @notice Updates the `protocolFeeMbps` value of given Pairs.
     * This can only be called by the `paramSetter` address.
     * @param pairs A list of addresses for the pairs that should be updated
     * @param newProtocolFeeMbps The new `protocolFeeMbps` value
     */
    function setProtocolFeeMbps(address[] calldata pairs, uint24 newProtocolFeeMbps) external;

    /**
     * @notice Updates the `minBasinDuration` value of given Pairs.
     * This can only be called by the `paramSetter` address.
     * @param pairs A list of addresses for the pairs that should be updated
     * @param newMinBasinDuration The new `minBasinDuration` value
     */
    function setMinBasinDuration(address[] calldata pairs, uint32 newMinBasinDuration) external;

    /**
     * @notice Updates the `maxBasinDuration` value of given Pairs.
     * This can only be called by the `paramSetter` address.
     * @param pairs A list of addresses for the pairs that should be updated
     * @param newMaxBasinDuration The new `maxBasinDuration` value
     */
    function setMaxBasinDuration(address[] calldata pairs, uint32 newMaxBasinDuration) external;

    /**
     * @notice Returns the default pair creation parameters associated with the given (plBps, feeBps) pair
     * @param plBps The pL value in bps
     * @param feeBps The fee value in bps
     * @return movingAverageWindow The default moving average window
     * @return maxVolatilityBps The default max volatility bps
     * @return minTimelockDuration The default minimum time lock duration
     * @return maxTimelockDuration The default maximum time lock duration
     * @return maxSwappableReservoirLimitBps The default max swappable reservoir limit bps
     * @return swappableReservoirGrowthWindow The default swappable reservoir growth window
     * @return protocolFeeMbps The default protocol fee value in milli-bps
     */
    function defaultPairCreationParameters(uint16 plBps, uint16 feeBps)
        external
        view
        returns (
            uint32 movingAverageWindow,
            uint16 maxVolatilityBps,
            uint32 minTimelockDuration,
            uint32 maxTimelockDuration,
            uint16 maxSwappableReservoirLimitBps,
            uint32 swappableReservoirGrowthWindow,
            uint24 protocolFeeMbps,
            uint32 minBasinDuration,
            uint32 maxBasinDuration
        );

    /**
     * @notice Returns the supported category parameters at the given index
     * @param index The index of the supported category
     * @return plBps The pL value in bps
     * @return feeBps The fee value in bps
     */
    function supportedCategories(uint256 index) external view returns (uint16 plBps, uint16 feeBps);
}
