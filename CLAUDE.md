# GameSpice Progression

XP, levels, reward tracks and daily/weekly challenges as pure functions over a small state document. Read the family [CLAUDE.md](../../CLAUDE.md) first. **The distributable is `addons/gs_progression/`**; it requires [GameSpice Core](../gs-core) only (`ln -s ../../gs-core/addons/gs_core addons/gs_core`, gitignored).

| Path | What |
| --- | --- |
| `core/gs_progression_config.gd` | `GSProgressionConfig`: every tunable, `from_files()` |
| `core/gs_progression_curve.gd` | `GSProgressionCurve`: xp per level, total xp, level for xp, progress |
| `core/gs_progression_state.gd` | `GSProgressionState`: `{xp, claimed}`, validate, grant |
| `core/gs_progression_track.gd` | `GSProgressionTrack`: season/battle-pass tiers as a document, claim |
| `core/gs_progression_challenges.gd` | `GSProgressionChallenges`: period keys, deterministic deal, progress |
| `examples/progression_selftest.tscn` | the suite |

- **Boundary**: not gs-achievements (one-off goals over stats), not gs-stats (counters), not gs-economy (round buy money) or gs-store (selling). A tier names a reward id and never grants it; storage is gs-save or the game's backend. No class name overlaps any other addon.
- **No hard caps**: `max_level` and `max_grant` are 0 = unlimited; an over-limit grant is refused loudly, never clipped.
- **Float care**: the curve adds 1e-6 before flooring so 100 x 1.15 is 115, not 114.
- **Pack rules**: no `uid://`, load by path.
- **Validate**: `--import`, parse every `.gd`, run the suite.
