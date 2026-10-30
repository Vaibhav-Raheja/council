from datetime import date, timedelta

from reports import dates
from reports.report import weekly_totals, render
from reports.streaks import longest_streak, active_this_week

MON = date(2026, 10, 19)
SUN = date(2026, 10, 25)


def test_week_start_every_weekday():
    for i in range(7):
        assert dates.week_start(MON + timedelta(days=i)) == MON


def test_week_end_is_sunday():
    for i in range(7):
        assert dates.week_end(MON + timedelta(days=i)) == SUN


def test_weekly_totals_labels_are_mondays():
    sales = [(MON, 100), (SUN, 300), (date(2026, 10, 26), 7)]
    assert weekly_totals(sales) == {"2026-10-19": 400, "2026-10-26": 7}


def test_render():
    assert render([(SUN, 1234)]) == "2026-10-19  12.34"


def test_streak_sunday_then_monday_is_two_weeks():
    assert longest_streak([SUN, date(2026, 10, 26)]) == 2


def test_streak_monday_and_sunday_same_week():
    assert longest_streak([MON, SUN]) == 1


def test_active_this_week_sunday():
    assert active_this_week([MON], SUN)
    assert not active_this_week([date(2026, 10, 18)], MON)


def test_weeks_between():
    assert dates.weeks_between(SUN, date(2026, 10, 26)) == 1
