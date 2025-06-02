// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IRouter {
    struct route {
        /// @dev token from
        address from;
        /// @dev token to
        address to;
        /// @dev is stable route
        bool stable;
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract Utils is Ownable {
    IRouter constant router =
        IRouter(0x1D368773735ee1E678950B7A97bcA2CafB330CDc);

    constructor() Ownable(msg.sender) {}

    function multisend(
        address payable[] calldata recipients,
        uint256[] calldata values
    ) external payable {
        uint256 n = recipients.length;
        for (uint256 i = 0; i < n; i++) {
            recipients[i].call{value: values[i]}("");
        }
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        IRouter.route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        IERC20 from = IERC20(routes[0].from);
        if (amountIn == 0) {
            amountIn = from.balanceOf(msg.sender);
        }
        from.transferFrom(msg.sender, address(this), amountIn);

        if (from.allowance(address(this), address(router)) < amountIn) {
            from.approve(address(router), type(uint256).max);
        }
        return
            router.swapExactTokensForETH(
                amountIn,
                amountOutMin,
                routes,
                to,
                deadline
            );
    }

    function sweepToken(address token) external onlyOwner {
        if (token == 0x0000000000000000000000000000000000000000) {
            payable(owner()).call{value: payable(address(this)).balance}("");
        } else {
            IERC20(token).transfer(
                owner(),
                IERC20(token).balanceOf(address(this))
            );
        }
    }
}
