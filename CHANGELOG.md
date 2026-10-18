# Changelog

## 0.1.5-alpha - 18 October 2026

- Improved performance while the minimap is visible. A local Windows/Steam test reported an increase from 88–94 FPS to a steady 130–140 FPS after this update. Results vary by system and scene.
- Reuse the player controller for direction updates instead of repeatedly searching game objects on every arrow tick.
- Skip arrow widget updates when the displayed heading changes by less than 0.1 degrees; small turns still accumulate normally.
- Disable diagnostic pixel readback by default to avoid its rendering stall. Set `Diagnostics = true` in `Scripts/settings.lua` only when collecting troubleshooting logs.
- Keep arrow smoothing, map resolution and terrain refresh frequency unchanged.

Validation: 20 automated checks passed, followed by the local in-game performance test above.
