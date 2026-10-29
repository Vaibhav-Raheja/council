from decimal import Decimal as D

from billing.checkout import total
from billing.coupons import coupon_value
from billing.shipping import shipping_for


# Real mismatch 1: loyalty must come before tax.
def test_loyalty_before_tax():
    # 300 -> loyalty 270 -> tax 21.60 -> free shipping -> 291.60
    assert total([(D("300"), 1)], loyalty=True) == D("291.60")


def test_loyalty_moves_order_under_free_shipping():
    # 210 -> loyalty 189 -> tax 15.12 -> shipping 15 -> 219.12
    assert total([(D("210"), 1)], loyalty=True) == D("219.12")


# Real mismatch 2: halves round up.
def test_half_cent_rounds_up():
    # 0.375 * 1.08 = 0.405; + 15 shipping = 15.405 -> 15.41 (half-up),
    # 15.40 (half-even)
    assert total([(D("0.375"), 1)]) == D("15.41")


# Decoys: these already match RULES.md and must stay as they are.
def test_exactly_200_pays_shipping():
    assert shipping_for(D("200")) == D("15")
    assert total([(D("200"), 1)]) == D("231.00")


def test_just_over_200_ships_free():
    assert shipping_for(D("200.01")) == D("0")


def test_coupon_case_and_spaces():
    assert coupon_value("  save10 ") == D("10")
    assert coupon_value("SaVe10") == D("10")
    assert coupon_value("nope") == D("0")
    assert coupon_value(None) == D("0")


def test_coupon_floor_at_zero():
    assert total([(D("5"), 1)], coupon="SAVE10") == D("15.00")


def test_bulk_exactly_ten():
    # 10 x 10 = 100 -> 95 -> tax 7.60 -> shipping 15 -> 117.60
    assert total([(D("10"), 10)]) == D("117.60")


def test_bulk_nine_no_discount():
    assert total([(D("10"), 9)]) == D("112.20")


def test_everything_together():
    # bulk: 12 x 20 = 240 -> 228; coupon -> 218; loyalty -> 196.20;
    # tax 15.696; shipping 15 (196.20 is not over 200) -> 226.896 -> 226.90
    assert total([(D("20"), 12)], coupon="save10", loyalty=True) == D("226.90")
