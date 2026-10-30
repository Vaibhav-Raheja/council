from decimal import Decimal, ROUND_HALF_EVEN

from .coupons import coupon_value
from .lines import line_total
from .shipping import shipping_for

TAX = Decimal("0.08")
LOYALTY = Decimal("0.10")
CENT = Decimal("0.01")


def total(lines, coupon=None, loyalty=False) -> Decimal:
    """lines: iterable of (price: Decimal, qty: int)."""
    subtotal = sum((line_total(p, q) for p, q in lines), Decimal("0"))
    subtotal = max(subtotal - coupon_value(coupon), Decimal("0"))
    tax = subtotal * TAX
    if loyalty:
        subtotal -= subtotal * LOYALTY
    amount = subtotal + tax + shipping_for(subtotal)
    return amount.quantize(CENT, rounding=ROUND_HALF_EVEN)
