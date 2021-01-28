import pytest
import brownie
from brownie import Wei, Contract, accounts


@pytest.mark.require_network("mainnet-fork")
def test_lending(
    chain,
    gov,
    router,
    vault,
    bob,
    alice,
    weth,
    protocolProvider,
    lendingPool,
    usdc,
    weth_whale,
):
    lp = lendingPool

    # Approve delegation
    variableToken = Contract(
        protocolProvider.getReserveTokensAddresses(weth).dict()[
            "variableDebtTokenAddress"
        ]
    )
    # Bob is all in!
    variableToken.approveDelegation(router, 2 ** 256 - 1, {"from": bob})

    # Alice is smarter. She doesn't trust us so much
    variableToken.approveDelegation(router, Wei("1 ether"), {"from": alice})

    # Add delegators
    router.addDelegator(alice, {"from": gov})
    router.addDelegator(bob, {"from": gov})
    assert alice in router.delegators()
    assert bob in router.delegators()

    # Check our borrowing power!
    print(f"Borrowing power is {router.ethBorrowingPower()/1e18}")
    assert router.ethBorrowingPower() > Wei("2.70 ether")

    # Invest the money
    router.invest(Wei("2 ether"), {"from": gov})

    # Travel to the future! 1W just in case
    chain.sleep(604_800)
    chain.mine(1)

    # Harvest the strategy to make sure there are profits
    vault = Contract("0xdCD90C7f6324cfa40d7169ef80b12031770B4325")
    vault_gov = accounts.at(vault.governance(), force=True)
    strategy = Contract(vault.withdrawalQueue(0))
    print(f"Price per share before harvest: {vault.pricePerShare()}")
    strategy.harvest({"from": vault_gov})
    print(f"Price per share after harvest: {vault.pricePerShare()}")

    # Stop the investment
    router.withdraw({"from": gov})

    # Make sure we made some money after returning the loan
    assert router.profit() > Wei("0.001 ether")
