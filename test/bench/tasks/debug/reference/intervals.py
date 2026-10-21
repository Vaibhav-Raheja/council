"""Closed integer intervals [start, end]."""


def merge(intervals):
    """Merge overlapping or touching intervals.

    Returns a new sorted list of [start, end] pairs; the input is not modified.
    Touching intervals ([1, 3] and [3, 5]) merge into one.
    """
    out = []
    for start, end in sorted(intervals):
        if out and start <= out[-1][1]:
            out[-1][1] = max(out[-1][1], end)
        else:
            out.append([start, end])
    return out


def total_length(intervals):
    return sum(e - s for s, e in merge(intervals))
