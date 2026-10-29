"""Time sources. Every time-dependent class takes clock=..., default SYSTEM."""
import time


class SystemClock:
    def now(self) -> float:
        return time.monotonic()


class ManualClock:
    """A clock tests move by hand."""

    def __init__(self, start: float = 0.0):
        self.t = start

    def now(self) -> float:
        return self.t

    def advance(self, secs: float) -> None:
        self.t += secs


SYSTEM = SystemClock()
