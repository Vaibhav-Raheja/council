# TTLCache

A bounded cache whose entries expire, for the `store` package.

    TTLCache(maxsize, ttl, ...)

- `maxsize` is the most entries the cache holds; `ttl` is how many seconds an
  entry lives after it was last set. Both must be positive numbers; anything
  else is rejected with `ValueError`.
- `set(key, value)` stores a value. Setting an existing key replaces the value
  and restarts its lifetime.
- `get(key)` returns the value. A key that is missing or has expired fails the
  same way every other lookup in this package fails for a missing key.
- `delete(key)` removes a key; a missing key fails like `get`.
- `len(cache)` counts entries that have not expired.
- When a `set` would exceed `maxsize`, expired entries are dropped first; if it
  is still full, the least recently used entry is evicted. Both `get` and `set`
  count as use.
- Time is handled the way the rest of the package handles it, so tests can
  control it.
