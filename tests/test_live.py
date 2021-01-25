import pytest
import brownie
from brownie import Wei, Contract


@pytest.mark.require_network("mainnet-fork")
def test_lending(gov, router, vault, lender, usdc, weth, protocolProvider):

    variableToken = Contract(
        protocolProvider.getReserveTokensAddresses(usdc).dict()[
            "variableDebtTokenAddress"
        ]
    )
    variableToken.approveDelegation(router, 2 ** 256 - 1, {"from": lender})
    router.addDelegator(usdc, {"from": lender})

    assert lender in router.delegators()

    assert router.ethBorrowingPower(weth) > Wei("5 ether")
