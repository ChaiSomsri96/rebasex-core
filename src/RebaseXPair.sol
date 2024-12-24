// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseXPairBase, IRebaseXPair, IERC20, SafeERC20} from "./RebaseXPairBase.sol";
import {PairLogic} from "./libraries/PairLogic.sol";

contract RebaseXPair is RebaseXPairBase {
    constructor() RebaseXPairBase() {}

    function _price(uint256 pool0, uint256 pool1) internal view override returns (uint256 price) {
        return PairLogic.price(pool0, pool1, plBps);
    }

    function _k(uint256 pool0, uint256 pool1) internal view override returns (uint256 k) {
        k = PairLogic.k(pool0, pool1, plBps);
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function currentPrice() external view returns (uint256 price) {
        (uint256 total0, uint256 total1) = _getTotals();
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        price = _price(lb.pool0, lb.pool1);
    }

    /**
     * @dev Always mints liquidity equivalent to protocolFeeBps/feeBps of the growth in K and allocates to address(this)
     * If there isn't a `feeTo` address defined, these LP tokens will get burned and this fraction gets reallocated to LPs
     * @param pool0 The `token0` active liquidity balance at the start of the ongoing swap
     * @param pool1 The `token1` active liquidity balance at the start of the ongoing swap
     * @param pool0New The `token0` active liquidity balance at the end of the ongoing swap
     * @param pool1New The `token1` active liquidity balance at the end of the ongoing swap
     */
    function _mintFee(uint256 pool0, uint256 pool1, uint256 pool0New, uint256 pool1New) internal {
        // If protocolFeeMbps == 0, then you can skip minting the protocol fee
        if (protocolFeeMbps != 0) {
            uint256 liquidityOut = PairLogic.getProtocolFeeLiquidityMinted(
                totalSupply,
                PairLogic.kN(pool0, pool1, plBps),
                PairLogic.kN(pool0New, pool1New, plBps),
                feeBps,
                protocolFeeMbps
            );
            if (liquidityOut > 0) {
                _mint(address(this), liquidityOut);
            }
        }
    }

    /**
     * @inheritdoc IRebaseXPair
     */
    function swap(uint256 amountIn0, uint256 amountIn1, uint256 amountOut0, uint256 amountOut1, address to)
        external
        lock
        checkPaused
    {
        if (amountOut0 == 0 && amountOut1 == 0) {
            revert InsufficientOutputAmount();
        }
        if (to == token0 || to == token1) {
            revert InvalidRecipient();
        }
        (uint256 total0, uint256 total1) = _getTotals();
        // Determine current pool liquidity
        LiquidityBalances memory lb = _getLiquidityBalances(total0, total1);
        if (amountOut0 > lb.pool0 - POOL_MIN || amountOut1 > lb.pool1 - POOL_MIN) {
            revert InsufficientLiquidity();
        }
        // Transfer in the specified input
        if (amountIn0 > 0) {
            SafeERC20.safeTransferFrom(IERC20(token0), msg.sender, address(this), amountIn0);
        }
        if (amountIn1 > 0) {
            SafeERC20.safeTransferFrom(IERC20(token1), msg.sender, address(this), amountIn1);
        }
        // Optimistically transfer output
        if (amountOut0 > 0) {
            SafeERC20.safeTransfer(IERC20(token0), to, amountOut0);
        }
        if (amountOut1 > 0) {
            SafeERC20.safeTransfer(IERC20(token1), to, amountOut1);
        }

        // Refresh balances
        (total0, total1) = _getTotals();

        // The reservoir and basin balances must remain unchanged during a swap, so all balance changes impact the pool balances
        uint256 pool0New = total0 - lb.reservoir0 - lb.basin0;
        uint256 pool1New = total1 - lb.reservoir1 - lb.basin1;
        if (pool0New < POOL_MIN || pool1New < POOL_MIN) {
            revert InvalidFinalPrice();
        }
        // Update to the actual amount of tokens the user sent in based on the delta between old and new pool balances
        if (pool0New > lb.pool0) {
            amountIn0 = pool0New - lb.pool0;
            amountOut0 = 0;
        } else {
            amountIn0 = 0;
            amountOut0 = lb.pool0 - pool0New;
        }
        if (pool1New > lb.pool1) {
            amountIn1 = pool1New - lb.pool1;
            amountOut1 = 0;
        } else {
            amountIn1 = 0;
            amountOut1 = lb.pool1 - pool1New;
        }
        // If after accounting for input and output cancelling one another out, fee on transfer, etc there is no
        //   input tokens in real terms then revert.
        if (amountIn0 == 0 && amountIn1 == 0) {
            revert InsufficientInputAmount();
        }

        uint256 pool0NewAdjusted = (pool0New * BPS) - (amountIn0 * feeBps);
        uint256 pool1NewAdjusted = (pool1New * BPS) - (amountIn1 * feeBps);
        if (
            PairLogic.kN(pool0NewAdjusted, pool1NewAdjusted, plBps)
                < PairLogic.kN(lb.pool0 * BPS, lb.pool1 * BPS, plBps)
        ) {
            revert KInvariant();
        }
        // Update moving average before `_updatePriceCumulative` updates `blockTimestampLast` and the new `poolXLast` values are set
        uint256 _movingAveragePrice0 = movingAveragePrice0();
        movingAveragePrice0Last = _movingAveragePrice0;
        _mintFee(lb.pool0, lb.pool1, pool0New, pool1New);
        _updatePriceCumulative(lb.pool0, lb.pool1);
        _updateSingleSidedTimelock(_movingAveragePrice0, uint112(pool0New), uint112(pool1New));
        // Update Pair last swap price
        pool0Last = uint112(pool0New);
        pool1Last = uint112(pool1New);
        // Update Pair totals
        total0Last = uint112(total0);
        total1Last = uint112(total1);
        emit Swap(msg.sender, amountIn0, amountIn1, amountOut0, amountOut1, lb.pool0, lb.pool1, to);
    }
}
