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
import "../interfaces/IWeth.sol";

contract Router is Governable {
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant DEFAULT_SLIPPAGE = 50;

    EnumerableSet.AddressSet internal availableDelegators;
    IProtocolDataProvider public protocolProvider;
    ILendingPoolAddressesProvider public lendingPoolProvider;

    IZapSteth public zap = IZapSteth(address(0x15e5405B90Abba31F29c618f9dC8D65E95257660));
    IWeth public weth = IWeth(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 public yVault = IERC20(address(0xdCD90C7f6324cfa40d7169ef80b12031770B4325));

    uint256 public maxUsage = 50000;
    uint256 public base = 100000;

    constructor(IProtocolDataProvider _protocolProvider, ILendingPoolAddressesProvider _lendingPoolProvider) public Governable(msg.sender) {
        protocolProvider = _protocolProvider;
        lendingPoolProvider = _lendingPoolProvider;
        weth.approve(lendingPoolProvider.getLendingPool(), uint256(-1));
        yVault.approve(address(zap), uint256(-1));
    }

    function addDelegator(address _delegator) public onlyGovernor {
        require(borrowAllowance(_delegator) > 0, "!allowance");
        availableDelegators.add(_delegator);
    }

    function borrowAllowance(address delegator) public view returns (uint256) {
        (, , address variableDebtToken) = protocolProvider.getReserveTokensAddresses(address(weth));
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

            lendingPool.borrow(address(weth), toBorrow, 2, 0, delegator);
            borrowed = borrowed.add(toBorrow);

            if (borrowed == loanAmount) {
                break;
            }
        }
    }

    function depositInVault() internal {
        weth.withdraw(weth.balanceOf(address(this)));
        zap.zapEthIn{value: address(this).balance}(DEFAULT_SLIPPAGE);
    }

    function withdrawFromVault() internal {
        zap.zapEthOut(yVault.balanceOf(address(this)), DEFAULT_SLIPPAGE);
        weth.deposit{value: address(this).balance}();
    }

    function payback(uint256 amount) internal {
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());
        // We are paying back the min between the amount requested and our balance
        uint256 balance = Math.min(amount, weth.balanceOf(address(this)));

        for (uint256 i; i < availableDelegators.length(); i++) {
            address delegator = availableDelegators.at(i);
            (, uint256 ethDebt, , , , ) = lendingPool.getUserAccountData(delegator);
            uint256 toRepay = Math.min(ethDebt, balance);

            // This delegator doesn't owe anything! Move on.
            if (toRepay == 0) {
                continue;
            }

            lendingPool.repay(address(weth), toRepay, 2, delegator);
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

    function withdraw() public onlyGovernor {
        withdrawFromVault();
        payback(weth.balanceOf(address(this)));
    }

    function profit() public view returns (uint256) {
        return weth.balanceOf(address(this));
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
