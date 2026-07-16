import math
import unittest
from contextlib import nullcontext
from types import SimpleNamespace
from unittest.mock import patch

from ibkr_cli import ib_service
from ibkr_cli.config import ProfileConfig


def contract(symbol, local_symbol, currency, con_id, sec_type="STK", exchange="SMART"):
    return SimpleNamespace(
        symbol=symbol,
        localSymbol=local_symbol,
        currency=currency,
        conId=con_id,
        secType=sec_type,
        exchange=exchange,
    )


def position(account, contract_value, quantity, average_cost):
    return SimpleNamespace(
        account=account,
        contract=contract_value,
        position=quantity,
        avgCost=average_cost,
    )


class FakeIB:
    def __init__(self):
        self.accounts = ["U13504061", "U19309952", "U23136609", "U15402220"]
        self.position_rows = [
            position("U13504061", contract("AAPL", "AAPL", "USD", 1), 10, 90),
            position("U19309952", contract("AAPL", "AAPL", "USD", 1), 5, 95),
            position("U19309952", contract("AAPL", "AAPL", "GBP", 2), 2, 80),
        ]
        self.portfolio_rows = [
            SimpleNamespace(
                account="U13504061",
                contract=contract("AAPL", "AAPL", "USD", 1),
                position=10,
                marketPrice=100,
                marketValue=1000,
                averageCost=90,
                unrealizedPNL=100,
                realizedPNL=20,
            ),
            SimpleNamespace(
                account="U19309952",
                contract=contract("AAPL", "AAPL", "USD", 1),
                position=5,
                marketPrice=100,
                marketValue=500,
                averageCost=95,
                unrealizedPNL=25,
                realizedPNL=3,
            ),
            SimpleNamespace(
                account="U19309952",
                contract=contract("AAPL", "AAPL", "GBP", 2),
                position=2,
                marketPrice=90,
                marketValue=180,
                averageCost=80,
                unrealizedPNL=20,
                realizedPNL=4,
            ),
        ]
        self.pnl_rows = {
            ("U13504061", 1): SimpleNamespace(
                dailyPnL=5, unrealizedPnL=100, realizedPnL=20, value=1000
            ),
            ("U19309952", 1): SimpleNamespace(
                dailyPnL=-2, unrealizedPnL=25, realizedPnL=3, value=500
            ),
            ("U19309952", 2): SimpleNamespace(
                dailyPnL=7, unrealizedPnL=20, realizedPnL=4, value=180
            ),
        }
        self.account_update_requests = []
        self.pnl_requests = []
        self.cancelled = []

    def managedAccounts(self):
        return self.accounts

    def positions(self):
        return self.position_rows

    def reqAccountUpdates(self, account):
        self.account_update_requests.append(account)

    def portfolio(self, account=""):
        if account:
            return [row for row in self.portfolio_rows if row.account == account]
        return self.portfolio_rows

    def reqPnLSingle(self, account, model_code, con_id):
        self.pnl_requests.append((account, model_code, con_id))
        return self.pnl_rows[(account, con_id)]

    def pnlSingle(self, account="", modelCode="", conId=0):
        row = self.pnl_rows.get((account, conId))
        return [] if row is None else [row]

    def sleep(self, _seconds):
        return True

    def cancelPnLSingle(self, account, model_code, con_id):
        self.cancelled.append((account, model_code, con_id))


class PositionDataTests(unittest.TestCase):
    profile = ProfileConfig(host="127.0.0.1", port=4005, client_id=12, mode="live")

    def test_positions_serialize_portfolio_and_daily_pnl_fields(self):
        ib = FakeIB()
        with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
            payload = ib_service.get_positions(self.profile)

        rows = {(row["account"], row["con_id"]): row for row in payload["rows"]}
        self.assertEqual(rows[("U13504061", 1)]["market_price"], 100.0)
        self.assertEqual(rows[("U13504061", 1)]["market_value"], 1000.0)
        self.assertEqual(rows[("U13504061", 1)]["unrealized_pnl"], 100.0)
        self.assertEqual(rows[("U13504061", 1)]["realized_pnl"], 20.0)
        self.assertEqual(rows[("U13504061", 1)]["daily_pnl"], 5.0)
        self.assertEqual(rows[("U19309952", 2)]["currency"], "GBP")
        self.assertEqual(ib.account_update_requests, self.accounts_for_positions(ib))
        self.assertEqual(len(ib.pnl_requests), 3)
        self.assertEqual(ib.cancelled, ib.pnl_requests)

    def test_position_identity_keeps_accounts_currencies_and_contracts_distinct(self):
        ib = FakeIB()
        with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
            payload = ib_service.get_positions(self.profile)

        keys = {
            (row["account"], row["symbol"], row["currency"], row["sec_type"], row["con_id"])
            for row in payload["rows"]
        }
        self.assertEqual(
            keys,
            {
                ("U13504061", "AAPL", "USD", "STK", 1),
                ("U19309952", "AAPL", "USD", "STK", 1),
                ("U19309952", "AAPL", "GBP", "STK", 2),
            },
        )
        self.assertFalse(any(math.isnan(row["daily_pnl"]) for row in payload["rows"]))

    @staticmethod
    def accounts_for_positions(ib):
        return ["U13504061", "U19309952"]

    def test_account_summary_selects_each_mapped_account(self):
        class SummaryIB(FakeIB):
            def accountSummary(self, account):
                return [SimpleNamespace(account=account, tag="NetLiquidation", value="100", currency="GBP")]

        for account in ["U13504061", "U19309952", "U23136609", "U15402220"]:
            ib = SummaryIB()
            with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
                payload = ib_service.get_account_summary(self.profile, account=account)
            self.assertEqual(payload["selected_account"], account)
            self.assertEqual(payload["rows"][0]["account"], account)


if __name__ == "__main__":
    unittest.main()
