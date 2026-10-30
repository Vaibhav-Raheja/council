import json
import pathlib

from pricing.engine import discount

CASES = json.loads((pathlib.Path(__file__).parent / "expected.json").read_text())


def test_bug_report_case():
    assert discount({"region": "EU", "total": 100, "items": 1, "customer_years": 0}) >= 5


def test_all_rules_match_documentation():
    wrong = [c for c in CASES if discount(c["order"]) != c["pct"]]
    assert not wrong, wrong[:5]
