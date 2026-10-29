from datetime import date

from reports.report import weekly_totals


def test_weekly_totals_midweek():
    sales = [(date(2026, 10, 21), 500), (date(2026, 10, 22), 250)]
    assert list(weekly_totals(sales).values()) == [750]


def test_weekly_totals_two_weeks():
    sales = [(date(2026, 10, 14), 100), (date(2026, 10, 21), 200)]
    assert list(weekly_totals(sales).values()) == [100, 200]


def test_weekly_totals_sunday():
    # Monday 19th through Sunday 25th October 2026 is one ISO week.
    sales = [(date(2026, 10, 19), 100), (date(2026, 10, 25), 300)]
    assert weekly_totals(sales) == {"2026-10-19": 400}
