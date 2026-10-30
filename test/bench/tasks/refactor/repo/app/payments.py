from app.logx import legacy_log as _log


def charge(amount, currency="EUR"):
    _log("charge", "info", amount=amount, currency=currency)
    if amount > 10_000:
        _log("large charge flagged", "warn", amount=amount)
    return round(amount, 2)
