// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface yVault {
    function pricePerShare() external view returns (uint);
    function deposit(uint) external returns (uint);
    function withdraw(uint) external returns (uint);
}
