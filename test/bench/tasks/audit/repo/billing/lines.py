from decimal import Decimal

BULK_QTY = 10
BULK_RATE = Decimal("0.05")


def line_total(price: Decimal, qty: int) -> Decimal:
    total = price * qty
    if qty >= BULK_QTY:
        total -= total * BULK_RATE
    return total
