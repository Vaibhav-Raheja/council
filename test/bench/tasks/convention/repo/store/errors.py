"""Errors raised by the store package."""


class StoreError(Exception):
    """Base class for store errors."""


class NotFound(StoreError, LookupError):
    """A key is missing (or no longer valid). Carries the key."""

    def __init__(self, key):
        super().__init__(key)
        self.key = key
