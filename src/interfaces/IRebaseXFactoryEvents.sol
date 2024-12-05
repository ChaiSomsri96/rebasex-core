// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseXFactoryEvents {
    /**
     * @notice Emitted when a new Pair is created.
     * @param token0 The first sorted token
     * @param token1 The second sorted token
     * @param plBps The pL value in bps
     * @param feeBps The fee value in bps
     * @param pair The address of the new {ButtonswapPair} contract
     * @param count The new total number of Pairs created
     */
    event PairCreated(
        address indexed token0, address indexed token1, uint16 indexed plBps, uint16 feeBps, address pair, uint256 count
    );

    /**
     * @notice Emitted when the default parameters for a new pair have been updated.
     * @param paramSetter The address that changed the parameters
     * @param plBps The pLBps that the new default parameters will correspond to
     * @param feeBps The feeBps that the new default parameters will correspond to
     * @param newDefaultMovingAverageWindow The new movingAverageWindow default value
     * @param newDefaultMaxVolatilityBps The new maxVolatilityBps default value
     * @param newDefaultMinTimelockDuration The new minTimelockDuration default value
     * @param newDefaultMaxTimelockDuration The new maxTimelockDuration default value
     * @param newDefaultMaxSwappableReservoirLimitBps The new maxSwappableReservoirLimitBps default value
     * @param newDefaultSwappableReservoirGrowthWindow The new swappableReservoirGrowthWindow default value
     * @param newDefaultProtocolFeeMbps The new protocol fee default value
     * @param newDefaultMinBasinDuration The new minBasinDuration default value
     * @param newDefaultMaxBasinDuration The new maxBasinDuration default value
     */
    event DefaultParametersUpdated(
        address indexed paramSetter,
        uint16 indexed plBps,
        uint16 indexed feeBps,
        uint32 newDefaultMovingAverageWindow,
        uint16 newDefaultMaxVolatilityBps,
        uint32 newDefaultMinTimelockDuration,
        uint32 newDefaultMaxTimelockDuration,
        uint16 newDefaultMaxSwappableReservoirLimitBps,
        uint32 newDefaultSwappableReservoirGrowthWindow,
        uint24 newDefaultProtocolFeeMbps,
        uint32 newDefaultMinBasinDuration,
        uint32 newDefaultMaxBasinDuration
    );
}
