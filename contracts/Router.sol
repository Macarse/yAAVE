// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./Governable.sol";

// AAVE interfaces
import "../interfaces/IProtocolDataProvider.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IDebtToken.sol";
import "../interfaces/IZapSteth.sol";

contract Router is Governable {
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Set of people delegating credit
    EnumerableSet.AddressSet internal availableDelegators;
    IProtocolDataProvider public protocolProvider;
    ILendingPoolAddressesProvider public lendingPoolProvider;
    address public zap = 0x15e5405B90Abba31F29c618f9dC8D65E95257660;
    address public asset;
    uint256 public maxUsage = 50000;
    uint256 public base = 100000;

    constructor(
        IProtocolDataProvider _protocolProvider,
        ILendingPoolAddressesProvider _lendingPoolProvider,
        address _asset
    ) public Governable(msg.sender) {
        protocolProvider = _protocolProvider;
        lendingPoolProvider = _lendingPoolProvider;
        asset = _asset;
        IERC20(asset).approve(lendingPoolProvider.getLendingPool(), uint256(-1));
    }

    function addDelegator() public returns (bool) {
        require(borrowAllowance(msg.sender) > 0, "!allowance");
        availableDelegators.add(msg.sender);
    }

    function borrowAllowance(address delegator) public view returns (uint256) {
        (, , address variableDebtToken) = protocolProvider.getReserveTokensAddresses(asset);
        return IDebtToken(variableDebtToken).borrowAllowance(delegator, address(this));
    }

    function maxBorrowingPossible(address delegator) public view returns (uint256) {
        // We are using the min between:
        // maxUsage % of available borrowing and the allowance
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());

        (, , uint256 availableBorrowsETH, , , ) = lendingPool.getUserAccountData(delegator);
        uint256 maxAvailable = availableBorrowsETH.mul(maxUsage).div(base);

        return Math.min(maxAvailable, borrowAllowance(delegator));
    }

    function ethBorrowingPower() public view returns (uint256) {
        uint256 ethAmount = 0;

        for (uint256 i; i < availableDelegators.length(); i++) {
            ethAmount = ethAmount.add(maxBorrowingPossible(availableDelegators.at(i)));
        }

        return ethAmount;
    }

    function borrow(uint256 loanAmount) internal returns (uint256 borrowed) {
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());

        for (uint256 i; i < availableDelegators.length(); i++) {
            address delegator = availableDelegators.at(i);
            uint256 toBorrow = Math.min(loanAmount.sub(borrowed), maxBorrowingPossible(delegator));

            // Delegator might be exhausted!
            if (toBorrow == 0) {
                continue;
            }

            lendingPool.borrow(asset, toBorrow, 2, 0, delegator);
            borrowed = borrowed.add(toBorrow);

            if (borrowed == loanAmount) {
                break;
            }
        }
    }

    function depositInVault() internal {
        // TODO convert from weth to eth
        IZapSteth(zap).zapEthIn(50);
    }

    function payback(uint256 amount) public onlyGovernor {
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());
        // We are paying back the min between the amount requested and our balance
        uint256 balance = Math.min(amount, IERC20(asset).balanceOf(address(this)));

        for (uint256 i; i < availableDelegators.length(); i++) {
            address delegator = availableDelegators.at(i);
            (, uint256 ethDebt, , , , ) = lendingPool.getUserAccountData(delegator);
            uint256 toRepay = Math.min(ethDebt, balance);
            lendingPool.repay(asset, toRepay, 2, delegator);
            balance = balance.sub(toRepay);

            if (balance == 0) {
                break;
            }
        }
    }

    function invest(uint256 amount) public onlyGovernor {
        require(amount < ethBorrowingPower(), "not enough borrowing power");
        borrow(amount);
        depositInVault();
    }

    function delegators() public view returns (address[] memory _delegators) {
        _delegators = new address[](availableDelegators.length());
        for (uint256 i; i < availableDelegators.length(); i++) {
            _delegators[i] = availableDelegators.at(i);
        }
    }

    receive() external payable {}

    // Governable
    function setPendingGovernor(address _pendingGovernor) external override onlyGovernor {
        _setPendingGovernor(_pendingGovernor);
    }

    function acceptGovernor() external override onlyPendingGovernor {
        _acceptGovernor();
    }
}
