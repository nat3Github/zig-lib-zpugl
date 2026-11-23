# Changelog

Every removed or renamed public API gets an entry here, newest first, with what to use instead.

## 2026-11-23
- `KeyEvent.native` and `View.passKey` are gone. The return value of the event callback decides about a key: `.success` on `key_press` means the key is used, any other status passes it to the host (parent view or window) before the native key handler returns. A `key_release` goes to the host when its press did. Upstream pugl ignores this return value for keys, so a callback that returns a non-success status for keys now passes them on.
