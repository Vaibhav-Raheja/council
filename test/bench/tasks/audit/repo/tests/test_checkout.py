from decimal import Decimal as D

from billing.checkout import total


def test_simple_order_pays_shipping_and_tax():
    assert total([(D("50"), 1)]) == D("69.00")


def test_free_shipping_over_200():
    assert total([(D("250"), 1)]) == D("270.00")


def test_coupon():
    assert total([(D("50"), 1)], coupon="SAVE10") == D("58.20")
