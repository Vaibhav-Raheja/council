# ratelimit.py: token bucket

```python
class TokenBucket:
    def __init__(self, rate: float, capacity: int, clock=time.monotonic): ...
    def try_acquire(self, n: int = 1) -> bool: ...
    def wait_time(self, n: int = 1) -> float: ...
    @property
    def tokens(self) -> float: ...
```

- The bucket starts full (`capacity` tokens).
- Tokens refill continuously at `rate` tokens per second, never above `capacity`.
  Refill is computed lazily from `clock()` on every call; never use sleep or threads.
- `try_acquire(n)`: if at least `n` tokens are available, remove them and return True;
  otherwise remove nothing and return False.
- `wait_time(n)`: seconds until `n` tokens would be available (0.0 if available now).
  Does not consume tokens.
- `tokens`: current (refilled) token count as a float.
- Validation, all raising `ValueError`: `rate <= 0`, `capacity < 1`, `n < 1`, and
  `n > capacity` (for both `try_acquire` and `wait_time`, since it could never succeed).
- If the clock goes backwards, treat elapsed time as 0 (never lose or gain tokens).
- Thread safety: concurrent `try_acquire` calls must never hand out more tokens than
  exist. Use a `threading.Lock`.
