"""Structured logging."""

LEVELS = ("debug", "info", "warn", "error")


class Logger:
    def __init__(self):
        self.records = []

    def emit(self, level, msg, **ctx):
        if level not in LEVELS:
            raise ValueError(level)
        self.records.append({"level": level, "msg": msg, **ctx})


log = Logger()
