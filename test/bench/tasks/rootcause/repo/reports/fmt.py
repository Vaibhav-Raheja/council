"""Formatting for report output."""
from datetime import date


def label(d: date) -> str:
    return d.isoformat()


def money(cents: int) -> str:
    sign = "-" if cents < 0 else ""
    cents = abs(cents)
    return f"{sign}{cents // 100}.{cents % 100:02d}"
