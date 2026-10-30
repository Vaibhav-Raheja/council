from app import logx


def signup(name):
    logx.legacy_log("signup", user=name)
    if not name:
        logx.legacy_log("empty name", level="warn")
    return bool(name)
