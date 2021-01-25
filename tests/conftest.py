import pytest
from brownie import Contract


@pytest.fixture
def gov(accounts):
    yield accounts[1]


@pytest.fixture
def lender(accounts):
    yield accounts.at("0x3B2cba3423199f73924AD609fa8EeC504E1FaC1f", force=True)


@pytest.fixture
def protocolProvider():
    yield Contract("0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d")


@pytest.fixture
def lendingProvider():
    yield Contract("0xb53c1a33016b2dc2ff3653530bff1848a515c8c5")


@pytest.fixture
def usdc():
    yield Contract("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")


@pytest.fixture
def weth():
    yield Contract("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")


@pytest.fixture
def vault():
    yield Contract("0xdCD90C7f6324cfa40d7169ef80b12031770B4325")


@pytest.fixture
def router(gov, Router, protocolProvider, lendingProvider):
    yield gov.deploy(Router, protocolProvider, lendingProvider)
