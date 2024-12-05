// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseXFactoryErrors {
    /**
     * @notice The given token addresses are the same
     */
    error TokenIdenticalAddress();

    /**
     * @notice The given token address is the zero address
     */
    error TokenZeroAddress();

    /**
     * @notice The given tokens already have a {ButtonswapPair} instance
     */
    error PairExists();

    /**
     * @notice User does not have permission for the attempted operation
     */
    error Forbidden();

    /**
     * @notice There was an attempt to update a parameter to an invalid value
     */
    error InvalidParameter();

    /**
     * @notice Pair creation failed because (plBps, feeBps) is not supported
     */
    error UnsupportedCategoryParameters();

    /**
     * @notice Pair creation failed because insufficient gas
     */
    error PairCreationFailed();
}
