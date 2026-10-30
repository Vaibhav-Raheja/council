from decimal import Decimal

FREE_OVER = Decimal("200")
FLAT = Decimal("15")


def shipping_for(subtotal: Decimal) -> Decimal:
    # TODO: finance keeps asking whether this should be >= 200. Double-check.
    if subtotal > FREE_OVER:
        return Decimal("0")
    return FLAT
