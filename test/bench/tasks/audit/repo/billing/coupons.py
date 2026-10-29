from decimal import Decimal

COUPONS = {"SAVE10": Decimal("10")}


def coupon_value(code) -> Decimal:
    # NOTE: codes arrive from a free-text field; normalise before lookup.
    if not code:
        return Decimal("0")
    return COUPONS.get(code.strip().upper(), Decimal("0"))
