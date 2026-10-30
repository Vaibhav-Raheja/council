"""Login sessions that expire after a fixed idle time."""
from .clock import SYSTEM
from .errors import NotFound


class Sessions:
    def __init__(self, idle_secs: float, clock=SYSTEM):
        if idle_secs <= 0:
            raise ValueError("idle_secs must be positive")
        self._idle = idle_secs
        self._clock = clock
        self._seen: dict[str, float] = {}

    def touch(self, sid: str) -> None:
        self._seen[sid] = self._clock.now()

    def get(self, sid: str) -> float:
        """Last-seen time of a live session."""
        t = self._seen.get(sid)
        if t is None or self._clock.now() - t >= self._idle:
            self._seen.pop(sid, None)
            raise NotFound(sid)
        return t
