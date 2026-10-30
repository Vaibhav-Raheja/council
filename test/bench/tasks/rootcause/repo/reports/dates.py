"""Calendar helpers shared by the reports package."""
from datetime import date, timedelta


def week_start(d: date) -> date:
    """First day of the week containing d."""
    return d - timedelta(days=d.isoweekday())


def week_end(d: date) -> date:
    """Last day of the week containing d (inclusive)."""
    return week_start(d) + timedelta(days=6)


def weeks_between(a: date, b: date) -> int:
    """Number of week boundaries crossed going from a to b (a <= b)."""
    return (week_start(b) - week_start(a)).days // 7
