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

contract Router is Governable {
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal availableDelegators;
    IProtocolDataProvider public protocolProvider;
    ILendingPoolAddressesProvider public lendingPoolProvider;

    constructor(IProtocolDataProvider _protocolProvider, ILendingPoolAddressesProvider _lendingPoolProvider) public Governable(msg.sender) {
        protocolProvider = _protocolProvider;
        lendingPoolProvider = _lendingPoolProvider;
    }

    function addDelegator(address asset) public returns (bool) {
        // TODO: This doesn't work, I can't call the api to approve from my countract
        // The user needs to do it from outside
        // Not sure if there is a way around
        //(, , address variableDebtToken) = protocolProvider.getReserveTokensAddresses(asset);
        //IDebtToken(variableDebtToken).approveDelegation(address(this), uint(-1));
        availableDelegators.add(msg.sender);
    }

    function borrowAllowance(address delegator, address asset) public view returns (uint256) {
        (, , address variableDebtToken) = protocolProvider.getReserveTokensAddresses(asset);
        return IDebtToken(variableDebtToken).borrowAllowance(delegator, address(this));
    }

    function ethBorrowingPower(address asset) public view returns (uint256) {
        uint256 ethAmount = 0;
        address lendingPool = lendingPoolProvider.getLendingPool();

        for (uint256 i; i < availableDelegators.length(); i++) {
            (, , uint256 availableBorrowsETH, , , ) = ILendingPool(lendingPool).getUserAccountData(availableDelegators.at(i));

            // TODO: before adding we need to make sure we are allowed to take up to the availableBorrowsETH
            //borrowAllowance(availableDelegators.at(i), asset));
            ethAmount = ethAmount.add(availableBorrowsETH);
        }

        return ethAmount;
    }

    function delegators() public view returns (address[] memory _delegators) {
        _delegators = new address[](availableDelegators.length());
        for (uint256 i; i < availableDelegators.length(); i++) {
            _delegators[i] = availableDelegators.at(i);
        }
    }

    // Governable
    function setPendingGovernor(address _pendingGovernor) external override onlyGovernor {
        _setPendingGovernor(_pendingGovernor);
    }

    function acceptGovernor() external override onlyPendingGovernor {
        _acceptGovernor();
    }
}
