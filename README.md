# yAAVE

aaveProvider = Contract("0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d")
me = accounts.at("0x3B2cba3423199f73924AD609fa8EeC504E1FaC1f", force=True)

usdc = Contract("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
variableToken = Contract(aaveProvider.getReserveTokensAddresses(usdc).dict()['variableDebtTokenAddress'])
borrower = accounts.at("0x73f2f3A4fF97B6A6d7afc03C449f0e9a0c0d90aB", force=True)
variableToken.approveDelegation(borrower, 2**256-1, {'from': me})

lendingProvider = Contract("0xb53c1a33016b2dc2ff3653530bff1848a515c8c5")
lendingPool = Contract(lendingProvider.getLendingPool())
lendingPool.borrow(usdc, 50 * 1e6, 2, 0, me, {'from': borrower})
