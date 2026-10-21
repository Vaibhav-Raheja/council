from app import orders, users


def test_place_ok():
    assert orders.place("a1", 2)


def test_signup():
    assert users.signup("ann")
