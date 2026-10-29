import pytest

from store.clock import ManualClock
from store.errors import NotFound
from store.sessions import Sessions


def test_session_expires():
    c = ManualClock()
    s = Sessions(10, clock=c)
    s.touch("a")
    c.advance(9)
    assert s.get("a") == 0
    c.advance(1)
    with pytest.raises(NotFound):
        s.get("a")
