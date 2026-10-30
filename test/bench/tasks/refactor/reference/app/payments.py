from app.logx import log


def charge(amount, currency="EUR"):
    log.emit("info", "charge", amount=amount, currency=currency)
    if amount > 10_000:
        log.emit("warn", "large charge flagged", amount=amount)
    return round(amount, 2)
