"""Bounded, expiring cache. See SPEC.md."""
from collections import OrderedDict

from .clock import SYSTEM
from .errors import NotFound


class TTLCache:
    def __init__(self, maxsize, ttl, clock=SYSTEM):
        if isinstance(maxsize, bool) or not isinstance(maxsize, (int, float)) or maxsize <= 0:
            raise ValueError("maxsize must be positive")
        if isinstance(ttl, bool) or not isinstance(ttl, (int, float)) or ttl <= 0:
            raise ValueError("ttl must be positive")
        self._max = maxsize
        self._ttl = ttl
        self._clock = clock
        self._d = OrderedDict()  # key -> (expires_at, value)

    def _live(self, key):
        item = self._d.get(key)
        if item is None:
            return None
        if self._clock.now() >= item[0]:
            del self._d[key]
            return None
        return item

    def set(self, key, value):
        now = self._clock.now()
        if key in self._d:
            del self._d[key]
        elif len(self._d) >= self._max:
            for k in [k for k, (exp, _) in self._d.items() if now >= exp]:
                del self._d[k]
            if len(self._d) >= self._max:
                self._d.popitem(last=False)
        self._d[key] = (now + self._ttl, value)

    def get(self, key):
        item = self._live(key)
        if item is None:
            raise NotFound(key)
        self._d.move_to_end(key)
        return item[1]

    def delete(self, key):
        if self._live(key) is None:
            raise NotFound(key)
        del self._d[key]

    def __len__(self):
        now = self._clock.now()
        return sum(1 for exp, _ in self._d.values() if now < exp)
