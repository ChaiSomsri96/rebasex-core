// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseXERC20} from "./interfaces/IRebaseXERC20/IRebaseXERC20.sol";

contract RebaseXERC20 is IRebaseXERC20 {
    /**
     * @inheritdoc IRebaseXERC20
     */
    uint8 public constant decimals = 18;

    /**
     * @inheritdoc IRebaseXERC20
     */
    uint256 public totalSupply;

    /**
     * @inheritdoc IRebaseXERC20
     */
    mapping(address => uint256) public balanceOf;

    /**
     * @inheritdoc IRebaseXERC20
     */
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * @inheritdoc IRebaseXERC20
     */
    bytes32 public immutable DOMAIN_SEPARATOR;
}