import threading
import pytest
from ratelimit import TokenBucket


class Clock:
    def __init__(self): self.t = 100.0
    def __call__(self): return self.t


def test_starts_full():
    b = TokenBucket(1, 5, clock=Clock())
    assert b.tokens == pytest.approx(5)

def test_acquire_and_refuse():
    c = Clock(); b = TokenBucket(1, 3, clock=c)
    assert b.try_acquire(3)
    assert not b.try_acquire(1)
    assert b.tokens == pytest.approx(0)

def test_failed_acquire_takes_nothing():
    c = Clock(); b = TokenBucket(1, 3, clock=c)
    b.try_acquire(2)
    assert not b.try_acquire(2)
    assert b.tokens == pytest.approx(1)

def test_refill_capped():
    c = Clock(); b = TokenBucket(2, 4, clock=c)
    b.try_acquire(4); c.t += 1.0
    assert b.tokens == pytest.approx(2)
    c.t += 100
    assert b.tokens == pytest.approx(4)

def test_wait_time():
    c = Clock(); b = TokenBucket(2, 4, clock=c)
    b.try_acquire(4)
    assert b.wait_time(3) == pytest.approx(1.5)
    assert b.tokens == pytest.approx(0)
    c.t += 2
    assert b.wait_time(3) == 0.0

@pytest.mark.parametrize("kw", [dict(rate=0, capacity=1), dict(rate=-1, capacity=1), dict(rate=1, capacity=0)])
def test_ctor_validation(kw):
    with pytest.raises(ValueError):
        TokenBucket(**kw)

@pytest.mark.parametrize("n", [0, -1, 6])
def test_n_validation(n):
    b = TokenBucket(1, 5, clock=Clock())
    with pytest.raises(ValueError): b.try_acquire(n)
    with pytest.raises(ValueError): b.wait_time(n)

def test_clock_backwards():
    c = Clock(); b = TokenBucket(1, 5, clock=c)
    b.try_acquire(5); c.t -= 50
    assert b.tokens == pytest.approx(0)
    assert not b.try_acquire(1)

def test_default_clock_works():
    b = TokenBucket(1000, 2)
    assert b.try_acquire(2)

def test_threads_never_overdraw():
    c = Clock(); b = TokenBucket(0.0001, 50, clock=c)
    got = []
    def worker():
        for _ in range(20):
            if b.try_acquire(): got.append(1)
    ts = [threading.Thread(target=worker) for _ in range(8)]
    [t.start() for t in ts]; [t.join() for t in ts]
    assert len(got) == 50
