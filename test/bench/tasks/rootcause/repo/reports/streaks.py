"""Activity streaks: consecutive weeks with at least one sale."""
from datetime import date

from . import dates


def longest_streak(days: list[date]) -> int:
    if not days:
        return 0
    weeks = sorted({dates.week_start(d) for d in days})
    best = run = 1
    for prev, cur in zip(weeks, weeks[1:]):
        run = run + 1 if dates.weeks_between(prev, cur) == 1 else 1
        best = max(best, run)
    return best


def active_this_week(days: list[date], today: date) -> bool:
    lo, hi = dates.week_start(today), dates.week_end(today)
    return any(lo <= d <= hi for d in days)
