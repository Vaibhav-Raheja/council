from app import logx


def signup(name):
    logx.log.emit("info", "signup", user=name)
    if not name:
        logx.log.emit("warn", "empty name")
    return bool(name)
