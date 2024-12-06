// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseXERC20Errors {
    /**
     * @notice Permit deadline was exceeded
     */
    error PermitExpired();

    /**
     * @notice Permit signature invalid
     */
    error PermitInvalidSignature();   
}