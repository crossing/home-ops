import math
import secrets
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
        self.account_update_cancelled = []
        self.pnl_requests = []
        self.cancelled = []
        self.sleep_calls = []
        self.fail_pnl_accounts = set()
        self.fail_sleep = False
        self.timeout_account_updates = False

    def managedAccounts(self):
        return self.accounts

    def positions(self):
        return self.position_rows

    def reqAccountUpdates(self, account):
        self.account_update_requests.append(account)
        if self.timeout_account_updates:
            self.seen_request_timeout = getattr(self, "RequestTimeout", None)
            if getattr(self, "RequestTimeout", 0) <= 0:
                raise AssertionError("account update request was not bounded")
            raise TimeoutError("account update request timed out")

    def cancelAccountUpdates(self, account):
        self.account_update_cancelled.append(account)

    def portfolio(self, account=""):
        if account:
            return [row for row in self.portfolio_rows if row.account == account]
        return self.portfolio_rows

    def reqPnLSingle(self, account, model_code, con_id):
        self.pnl_requests.append((account, model_code, con_id))
        if account in self.fail_pnl_accounts:
            raise RuntimeError("P&L request failed")
        return self.pnl_rows[(account, con_id)]

    def pnlSingle(self, account="", modelCode="", conId=0):
        row = self.pnl_rows.get((account, conId))
        return [] if row is None else [row]

    def sleep(self, _seconds):
        self.sleep_calls.append(_seconds)
        if self.fail_sleep:
            raise TimeoutError("P&L request timed out")
        return True

    def cancelPnLSingle(self, account, model_code, con_id):
        self.cancelled.append((account, model_code, con_id))


class SingleAccountUpdateIB(FakeIB):
    def __init__(self):
        super().__init__()
        self.active_account = None

    def reqAccountUpdates(self, account):
        if self.active_account is not None:
            raise AssertionError("account update subscriptions must not overlap")
        super().reqAccountUpdates(account)
        self.active_account = account

    def cancelAccountUpdates(self, account):
        super().cancelAccountUpdates(account)
        self.active_account = None


class FakeEvent:
    def __init__(self):
        self.listeners = []

    def connect(self, listener):
        self.listeners.append(listener)

    def disconnect(self, listener):
        self.listeners.remove(listener)

    def emit(self, *args):
        for listener in list(self.listeners):
            listener(*args)


class SessionIB(FakeIB):
    instances = []
    collision_ids = set()
    connection_error = None
    timeout_account_updates = False

    def __init__(self):
        super().__init__()
        self.connected = False
        self.connect_calls = []
        self.disconnect_calls = 0
        self.seen_request_timeout = None
        self.timeout_account_updates = type(self).timeout_account_updates
        self.errorEvent = FakeEvent()
        type(self).instances.append(self)

    def connect(self, host, port, clientId, timeout, readonly, fetchFields):
        self.connect_calls.append(
            {
                "host": host,
                "port": port,
                "client_id": clientId,
                "timeout": timeout,
                "readonly": readonly,
                "fetch_fields": fetchFields,
            }
        )
        if clientId in type(self).collision_ids:
            self.errorEvent.emit(0, 326, "client ID already in use", None)
            raise ConnectionError("socket closed")
        if type(self).connection_error is not None:
            raise type(self).connection_error
        self.connected = True

    def isConnected(self):
        return self.connected

    def disconnect(self):
        self.disconnect_calls += 1
        self.connected = False

    def accountSummary(self, account):
        return [SimpleNamespace(account=account, tag="NetLiquidation", value="100", currency="GBP")]


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
        self.assertEqual(ib.account_update_cancelled, self.accounts_for_positions(ib))
        self.assertEqual(len(ib.pnl_requests), 3)
        self.assertEqual(ib.cancelled, ib.pnl_requests)

    def test_account_update_subscriptions_are_sequential(self):
        ib = SingleAccountUpdateIB()
        with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
            payload = ib_service.get_positions(self.profile)

        self.assertEqual(len(payload["rows"]), 3)
        self.assertEqual(ib.account_update_cancelled, self.accounts_for_positions(ib))
        self.assertIsNone(ib.active_account)

    def test_pnl_request_error_cleans_account_and_completed_subscriptions(self):
        ib = FakeIB()
        ib.fail_pnl_accounts = {"U19309952"}
        with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
            ib_service.get_positions(self.profile)

        self.assertEqual(ib.account_update_cancelled, self.accounts_for_positions(ib))
        self.assertEqual(
            ib.cancelled,
            [("U13504061", "", 1)],
        )

    def test_pnl_timeout_cleans_all_subscriptions(self):
        ib = FakeIB()
        ib.fail_sleep = True
        with patch.object(ib_service, "ib_session", return_value=nullcontext(ib)):
            with self.assertRaises(TimeoutError):
                ib_service.get_positions(self.profile)

        self.assertEqual(ib.account_update_cancelled, self.accounts_for_positions(ib))
        self.assertEqual(ib.cancelled, ib.pnl_requests)

    def test_account_update_timeout_is_bounded_by_session_request_timeout(self):
        SessionIB.instances = []
        SessionIB.collision_ids = set()
        SessionIB.connection_error = None
        SessionIB.timeout_account_updates = True
        with patch.object(ib_service, "_ib_class", return_value=(SessionIB, object())):
            with patch.object(secrets, "randbelow", return_value=0):
                SessionIB.instances.clear()
                payload = ib_service.get_positions(self.profile, timeout=0.25)

        ib = SessionIB.instances[0]
        self.assertEqual(len(payload["rows"]), 3)
        self.assertEqual(ib.seen_request_timeout, 0.25)
        self.assertEqual(ib.disconnect_calls, 1)
        self.assertEqual(ib.account_update_cancelled, self.accounts_for_positions(ib))
        SessionIB.timeout_account_updates = False

    def test_client_id_collision_retries_once_with_a_new_random_id(self):
        SessionIB.instances = []
        SessionIB.collision_ids = {1}
        SessionIB.connection_error = None
        with patch.object(ib_service, "_ib_class", return_value=(SessionIB, object())):
            with patch.object(secrets, "randbelow", side_effect=[0, 1]):
                with ib_service.ib_session(self.profile, timeout=0.25) as ib:
                    self.assertIsInstance(ib, SessionIB)

        self.assertEqual(
            [instance.connect_calls[0]["client_id"] for instance in SessionIB.instances],
            [1, 2],
        )
        self.assertEqual([instance.disconnect_calls for instance in SessionIB.instances], [1, 1])

    def test_unrelated_connection_error_is_not_retried(self):
        SessionIB.instances = []
        SessionIB.collision_ids = set()
        SessionIB.connection_error = ConnectionError("authentication failed")
        with patch.object(ib_service, "_ib_class", return_value=(SessionIB, object())):
            with patch.object(secrets, "randbelow", return_value=0):
                with self.assertRaisesRegex(ConnectionError, "authentication failed"):
                    with ib_service.ib_session(self.profile, timeout=0.25):
                        pass

        self.assertEqual(len(SessionIB.instances), 1)
        self.assertEqual(SessionIB.instances[0].disconnect_calls, 1)

    def test_successful_one_shot_command_disconnects(self):
        SessionIB.instances = []
        SessionIB.collision_ids = set()
        SessionIB.connection_error = None
        with patch.object(ib_service, "_ib_class", return_value=(SessionIB, object())):
            with patch.object(secrets, "randbelow", return_value=0):
                payload = ib_service.get_account_summary(self.profile, timeout=0.25)

        self.assertEqual(payload["selected_account"], "U13504061")
        self.assertEqual(len(SessionIB.instances), 1)
        self.assertEqual(SessionIB.instances[0].disconnect_calls, 1)

    def test_streaming_mode_is_explicitly_marked_and_still_releases_on_exit(self):
        SessionIB.instances = []
        SessionIB.collision_ids = set()
        SessionIB.connection_error = None
        with patch.object(ib_service, "_ib_class", return_value=(SessionIB, object())):
            with patch.object(secrets, "randbelow", return_value=0):
                with ib_service.ib_session(self.profile, timeout=0.25, streaming=True) as ib:
                    self.assertTrue(getattr(ib, "_ibkr_cli_streaming"))

        self.assertEqual(SessionIB.instances[0].disconnect_calls, 1)

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
