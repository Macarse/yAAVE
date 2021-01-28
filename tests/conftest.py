import pytest
from brownie import Contract


@pytest.fixture
def gov(accounts):
    yield accounts[1]


@pytest.fixture
def usdc():
    yield Contract("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")


@pytest.fixture
def ausdc():
    yield Contract("0xbcca60bb61934080951369a648fb03df4f96263c")


@pytest.fixture
def usdc_whale(accounts):
    yield accounts.at("0x59e123195cc785f0a61ba4545b7d1ddb978a7a36", force=True)


@pytest.fixture
def weth():
    yield Contract("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")


@pytest.fixture
def weth_whale(accounts):
    yield accounts.at("0x1840c62fd7e2396e470377e6b2a833f3a1e96221", force=True)


@pytest.fixture
def bob(accounts, usdc, usdc_whale, ausdc, lendingPool):
    bob = accounts[2]
    usdc.transfer(bob, 10_000 * 1e6, {"from": usdc_whale})
    usdc.approve(lendingPool, 2 ** 256 - 1, {"from": bob})
    lendingPool.deposit(usdc, usdc.balanceOf(bob), bob, 0, {"from": bob})
    yield bob


@pytest.fixture
def alice(accounts, usdc, usdc_whale, ausdc, lendingPool):
    alice = accounts[3]
    usdc.transfer(alice, 20_000 * 1e6, {"from": usdc_whale})
    usdc.approve(lendingPool, 2 ** 256 - 1, {"from": alice})
    lendingPool.deposit(usdc, usdc.balanceOf(alice), alice, 0, {"from": alice})
    yield alice


@pytest.fixture
def protocolProvider():
    yield Contract("0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d")


@pytest.fixture
def lendingPool(lendingProvider):
    yield Contract(lendingProvider.getLendingPool())


@pytest.fixture
def lendingProvider():
    yield Contract("0xb53c1a33016b2dc2ff3653530bff1848a515c8c5")


@pytest.fixture
def vault():
    yield Contract("0xdCD90C7f6324cfa40d7169ef80b12031770B4325")


@pytest.fixture
def router(gov, Router, protocolProvider, lendingProvider):
    yield gov.deploy(Router, protocolProvider, lendingProvider)
