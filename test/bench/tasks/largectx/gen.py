"""Generate the large-context task: ~40 discount-rule modules plus RULES.md.

usage: python3 gen.py <repo_dir> <hidden_dir>

Exactly one rule (rule_27) is generated with a strict `>` where RULES.md
documents `>=`. The hidden dir receives expected.json, computed from the
documented (correct) rules, so a fix that touches any other rule is caught.
"""
import json
import pathlib
import random
import sys

REGIONS = ["EU", "US", "APAC", "LATAM", "UK"]
FIELDS = ["total", "items", "customer_years"]
BUGGY = 27


def rules():
    rnd = random.Random(1234)
    out = []
    for k in range(40):
        field = FIELDS[k % 3]
        thr = {"total": rnd.choice([50, 75, 100, 150, 200, 250]),
               "items": rnd.randint(2, 12),
               "customer_years": rnd.randint(1, 6)}[field]
        out.append({"k": k, "region": REGIONS[(k * 7) % 5], "field": field,
                    "thr": thr, "pct": rnd.randint(1, 15)})
    # The bug report names this rule's case explicitly.
    out[BUGGY].update(region="EU", field="total", thr=100, pct=5)
    # No other EU total rule may cover 100, or it would mask the bug.
    for r in out:
        if r["k"] != BUGGY and r["region"] == "EU" and r["field"] == "total" and r["thr"] <= 100:
            r["thr"] = 150
    return out


def correct(order, rs):
    best = 0
    for r in rs:
        if order["region"] == r["region"] and order[r["field"]] >= r["thr"]:
            best = max(best, r["pct"])
    return best


FILLER = '''

def _audit_{k}(order):
    """Bookkeeping helper kept for the reporting pipeline; not part of pricing."""
    keys = sorted(order)
    return {{"rule": {k}, "keys": keys, "n": len(keys)}}


def _describe_{k}():
    return ("Rule {k} applies to region {region} when {field} reaches {thr}; "
            "it grants {pct} percent. Rules are evaluated independently and the "
            "engine keeps the largest discount, never the sum.")
'''


def module(r):
    op = ">" if r["k"] == BUGGY else ">="
    return (f'"""Discount rule {r["k"]}. See RULES.md."""\n\n\n'
            f'def rule_{r["k"]}(order):\n'
            f'    if order["region"] == "{r["region"]}" and order["{r["field"]}"] {op} {r["thr"]}:\n'
            f'        return {r["pct"]}\n'
            f'    return 0\n' + FILLER.format(**r))


def main(repo, hidden):
    repo, hidden = pathlib.Path(repo), pathlib.Path(hidden)
    pkg = repo / "pricing"
    (pkg / "rules").mkdir(parents=True, exist_ok=True)
    (repo / "tests").mkdir(exist_ok=True)
    rs = rules()
    (pkg / "__init__.py").write_text("")
    (pkg / "rules" / "__init__.py").write_text(
        "".join(f"from .r{r['k']:02d} import rule_{r['k']}\n" for r in rs)
        + "ALL = [" + ", ".join(f"rule_{r['k']}" for r in rs) + "]\n")
    for r in rs:
        (pkg / "rules" / f"r{r['k']:02d}.py").write_text(module(r))
    (pkg / "engine.py").write_text(
        '"""Apply every rule; the best (largest) discount wins."""\n'
        "from pricing.rules import ALL\n\n\n"
        "def discount(order):\n"
        "    return max((rule(order) for rule in ALL), default=0)\n")
    doc = ["# Discount rules\n",
           "Each rule applies when the order's region matches and the named field is "
           "**greater than or equal to** the threshold. The engine applies the largest "
           "single discount.\n"]
    for r in rs:
        doc.append(f"## Rule {r['k']}\n\n- Region: {r['region']}\n- Condition: "
                   f"`{r['field']} >= {r['thr']}`\n- Discount: {r['pct']}%\n\n"
                   f"Rationale: rule {r['k']} was introduced for {r['region']} "
                   f"customers to reward {r['field'].replace('_', ' ')}. It is "
                   "reviewed quarterly by the pricing team and must stay consistent "
                   "with the condition above, including the boundary value.\n")
    (repo / "RULES.md").write_text("\n".join(doc))
    (repo / "tests" / "__init__.py").write_text("")
    (repo / "tests" / "test_engine.py").write_text(
        "from pricing.engine import discount\n\n\n"
        "def test_no_match():\n"
        '    assert discount({"region": "XX", "total": 0, "items": 0, "customer_years": 0}) == 0\n')
    rnd = random.Random(99)
    cases = []
    for r in rs:
        for delta in (-1, 0, 1):
            o = {"region": r["region"], "total": 60, "items": 1, "customer_years": 0}
            o[r["field"]] = r["thr"] + delta
            cases.append(o)
    for _ in range(200):
        cases.append({"region": rnd.choice(REGIONS), "total": rnd.randint(0, 300),
                      "items": rnd.randint(0, 15), "customer_years": rnd.randint(0, 8)})
    hidden.mkdir(parents=True, exist_ok=True)
    (hidden / "expected.json").write_text(
        json.dumps([{"order": o, "pct": correct(o, rs)} for o in cases]))


if __name__ == "__main__":
    main(*sys.argv[1:3])
