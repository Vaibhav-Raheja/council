import pytest

from store.clock import ManualClock
from store.errors import NotFound, StoreError
from store.ttlcache import TTLCache


def make(maxsize=3, ttl=10):
    c = ManualClock()
    return TTLCache(maxsize, ttl, clock=c), c


def test_get_set():
    t, _ = make()
    t.set("a", 1)
    assert t.get("a") == 1


def test_missing_raises_notfound_with_key():
    t, _ = make()
    with pytest.raises(NotFound) as e:
        t.get("x")
    assert e.value.key == "x"
    assert isinstance(e.value, StoreError)


def test_expiry_uses_injected_clock():
    t, c = make(ttl=10)
    t.set("a", 1)
    c.advance(9.9)
    assert t.get("a") == 1
    c.advance(0.1)
    with pytest.raises(NotFound):
        t.get("a")


def test_set_restarts_lifetime():
    t, c = make(ttl=10)
    t.set("a", 1)
    c.advance(8)
    t.set("a", 2)
    c.advance(8)
    assert t.get("a") == 2


def test_get_does_not_extend_lifetime():
    t, c = make(ttl=10)
    t.set("a", 1)
    c.advance(6)
    t.get("a")
    c.advance(5)
    with pytest.raises(NotFound):
        t.get("a")


def test_delete():
    t, _ = make()
    t.set("a", 1)
    t.delete("a")
    with pytest.raises(NotFound):
        t.get("a")
    with pytest.raises(NotFound):
        t.delete("a")


def test_len_skips_expired():
    t, c = make(ttl=10)
    t.set("a", 1)
    c.advance(5)
    t.set("b", 2)
    assert len(t) == 2
    c.advance(5)
    assert len(t) == 1


def test_lru_eviction_counts_get():
    t, _ = make(maxsize=2)
    t.set("a", 1)
    t.set("b", 2)
    t.get("a")
    t.set("c", 3)
    assert t.get("a") == 1
    with pytest.raises(NotFound):
        t.get("b")


def test_expired_dropped_before_lru():
    t, c = make(maxsize=2, ttl=10)
    t.set("old", 1)
    c.advance(5)
    t.set("young", 2)
    c.advance(5)  # old expired, young alive
    t.set("new", 3)
    assert t.get("young") == 2
    assert t.get("new") == 3


@pytest.mark.parametrize("args", [(0, 1), (-1, 1), (1, 0), (1, -5)])
def test_rejects_non_positive(args):
    with pytest.raises(ValueError):
        TTLCache(*args, clock=ManualClock())


def test_default_clock_works():
    t = TTLCache(2, 60)
    t.set("a", 1)
    assert t.get("a") == 1
