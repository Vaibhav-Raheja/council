"""Token bucket rate limiter. See SPEC.md."""
import time
import threading


class TokenBucket:
    def __init__(self, rate, capacity, clock=time.monotonic):
        if rate <= 0 or capacity < 1:
            raise ValueError("rate must be > 0 and capacity >= 1")
        self._rate, self._cap, self._clock = rate, capacity, clock
        self._tokens = float(capacity)
        self._last = clock()
        self._lock = threading.Lock()

    def _refill(self):
        now = self._clock()
        self._tokens = min(self._cap, self._tokens + max(0.0, now - self._last) * self._rate)
        self._last = now

    def _check(self, n):
        if n < 1 or n > self._cap:
            raise ValueError(n)

    def try_acquire(self, n=1):
        self._check(n)
        with self._lock:
            self._refill()
            if self._tokens >= n:
                self._tokens -= n
                return True
            return False

    def wait_time(self, n=1):
        self._check(n)
        with self._lock:
            self._refill()
            return max(0.0, (n - self._tokens) / self._rate)

    @property
    def tokens(self):
        with self._lock:
            self._refill()
            return self._tokens
