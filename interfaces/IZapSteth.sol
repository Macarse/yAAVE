// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IZapSteth {
    function zapEthIn(uint256) external payable;
    function zapEthOut(uint256, uint256) external;
}
