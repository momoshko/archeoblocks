# Archeoblocks project rules

- Persistent UI belongs to Godot scenes as real nodes.
- Do not replace editor-authored layout with code drawing.
- Do not refactor visual layout into scripts.
- Keep gameplay logic separate from presentation.
- Read only files related to the current task.
- Work on one milestone at a time.
- Do not make unrelated refactors.
- Run targeted tests only unless broader validation is explicitly requested.
- Keep runtime and export filenames Latin ASCII, without spaces.
- Preserve the scene-first, beginner-readable Scene Tree.
- Never commit secrets, tokens, credentials, or private keys.
- Treat Web client code and resources as public.
- Production builds must not expose cheat or debug functionality.
- Debug reward providers must be guarded by `OS.is_debug_build()` and unavailable in release builds.
- Rewarded actions grant value only after a provider `reward_granted` callback, never on click/open/close.
- Every rewarded request must have a unique id and duplicate callbacks must be ignored.
- Debug-only gameplay testing options must require `OS.is_debug_build()` and have no effect in release builds.
