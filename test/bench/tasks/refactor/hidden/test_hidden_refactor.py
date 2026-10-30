import ast
import pathlib

import pytest

from app import logx, orders, users, payments, reports, cli

APP = pathlib.Path(__file__).resolve().parent.parent / "app"


@pytest.fixture(autouse=True)
def clear():
    logx.log.records.clear()


def test_legacy_removed():
    assert not hasattr(logx, "legacy_log")


def test_no_code_references():
    for f in APP.glob("*.py"):
        tree = ast.parse(f.read_text())
        names = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}
        attrs = {n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)}
        imps = {a.name for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) for a in n.names}
        assert "legacy_log" not in names | attrs | imps, f


def test_orders_records():
    orders.place("a1", 0)
    orders.place("b2", 3)
    assert logx.log.records == [
        {"level": "info", "msg": "placing order", "order_id": "a1", "qty": 0},
        {"level": "error", "msg": "bad qty", "order_id": "a1"},
        {"level": "info", "msg": "placing order", "order_id": "b2", "qty": 3},
        {"level": "debug", "msg": "order b2 placed"},
    ]


def test_users_records():
    users.signup("")
    assert logx.log.records == [
        {"level": "info", "msg": "signup", "user": ""},
        {"level": "warn", "msg": "empty name"},
    ]


def test_payments_records():
    assert payments.charge(20000.456) == 20000.46
    assert logx.log.records == [
        {"level": "info", "msg": "charge", "amount": 20000.456, "currency": "EUR"},
        {"level": "warn", "msg": "large charge flagged", "amount": 20000.456},
    ]


def test_reports_records():
    reports.build([{"failed": True}, {}])
    assert logx.log.records == [{"level": "error", "msg": "report built", "n": 2, "failed": 1}]


def test_cli_records():
    assert cli.main(("x",)) == 0
    assert logx.log.records == [{"level": "info", "msg": "cli start", "argv": ["x"]}]
