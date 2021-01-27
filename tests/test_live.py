import pytest
import brownie
from brownie import Wei, Contract


@pytest.mark.require_network("mainnet-fork")
def test_lending(
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
    router.addDelegator({"from": alice})
    router.addDelegator({"from": bob})
    assert alice in router.delegators()
    assert bob in router.delegators()

    # Check our borrowing power!
    print(f"Borrowing power is {router.ethBorrowingPower()/1e18}")
    assert router.ethBorrowingPower() > Wei("2.70 ether")

    # Invest the money
    assert 1 == 2
    router.invest(Wei("2 ether"))

    # Mock profit by sending weth
    weth.transfer(router, Wei("10 ether"), {"from": weth_whale})
    router.payback(Wei("200 ether"))
