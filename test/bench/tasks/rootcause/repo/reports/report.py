"""Weekly sales report."""
from collections import defaultdict
from datetime import date

from . import dates, fmt


def weekly_totals(sales: list[tuple[date, int]]) -> dict[str, int]:
    """Sum sale amounts (cents) per week, keyed by the week's start label."""
    totals: dict[date, int] = defaultdict(int)
    for day, cents in sales:
        totals[dates.week_start(day)] += cents
    return {fmt.label(k): totals[k] for k in sorted(totals)}


def render(sales: list[tuple[date, int]]) -> str:
    rows = [f"{wk}  {fmt.money(c)}" for wk, c in weekly_totals(sales).items()]
    return "\n".join(rows)
