# Changelog

Every removed or renamed public API gets an entry here, newest first, with what to use instead.

## 2026-11-23
- `KeyEvent.native` and `View.passKey` are gone. Like pugl, zpugl keeps every key in the view and passes none to the host. A plugin that wants to hand a key to the host does so through its plugin API (VST3 `onKeyDown` returning `kResultFalse`).
