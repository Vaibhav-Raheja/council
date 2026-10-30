"""A plain in-memory key/value store."""
from .errors import NotFound


class KV:
    def __init__(self):
        self._d = {}

    def put(self, key, value) -> None:
        self._d[key] = value

    def get(self, key):
        try:
            return self._d[key]
        except KeyError:
            raise NotFound(key) from None

    def delete(self, key) -> None:
        if key not in self._d:
            raise NotFound(key)
        del self._d[key]
