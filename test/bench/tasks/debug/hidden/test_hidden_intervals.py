from intervals import merge, total_length


def test_unsorted():
    assert merge([[8, 10], [1, 3], [2, 6]]) == [[1, 6], [8, 10]]


def test_nested_keeps_outer_end():
    assert merge([[1, 10], [2, 3]]) == [[1, 10]]


def test_nested_unsorted():
    assert merge([[2, 3], [5, 6], [1, 10]]) == [[1, 10]]


def test_touching():
    assert merge([[3, 5], [1, 3]]) == [[1, 5]]


def test_empty():
    assert merge([]) == []


def test_input_not_mutated():
    data = [[1, 3], [2, 6]]
    merge(data)
    assert data == [[1, 3], [2, 6]]


def test_total_length_nested():
    assert total_length([[1, 10], [2, 3]]) == 9
