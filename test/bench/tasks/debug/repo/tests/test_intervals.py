from intervals import merge


def test_merge_sorted():
    assert merge([[1, 3], [2, 6], [8, 10]]) == [[1, 6], [8, 10]]


def test_merge_touching():
    assert merge([[1, 3], [3, 5]]) == [[1, 5]]


def test_merge_unsorted():
    assert merge([[8, 10], [1, 3], [2, 6]]) == [[1, 6], [8, 10]]
