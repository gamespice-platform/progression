class_name GSProgressionConfig
extends GSConfig

## Every tunable of progression. `cfg/addon/dot_progression/*.yml`, `DOT_PROGRESSION_*` and `--progression-*` layer over these defaults. A zero in a limit means unlimited.

const ADDON := "dot-progression"

## Master switch: off, every grant fails with a state error.
@export var enabled: bool = true

@export_group("Levels")
## XP needed to go from level 1 to level 2.
@export_range(1, 100000, 1) var base_xp: int = 100
## Each level needs this many times the XP of the one before. 1.0 is a flat curve.
@export_range(1.0, 3.0, 0.01) var growth: float = 1.15
## The top level; 0 is unlimited.
@export_range(0, 1000, 1) var max_level: int = 0
## The largest single XP grant a server accepts; 0 is unlimited. A bigger one is refused, never clipped.
@export_range(0, 1000000, 1) var max_grant: int = 0

@export_group("Challenges")
## How many daily challenges a player is dealt; 0 deals the whole pool.
@export_range(0, 64, 1) var daily_count: int = 3
## How many weekly challenges a player is dealt; 0 deals the whole pool.
@export_range(0, 64, 1) var weekly_count: int = 3
## Seconds in a day for challenge resets.
@export_range(60, 604800, 60) var day_seconds: int = 86400
## Seconds in a week for challenge resets.
@export_range(3600, 2678400, 3600) var week_seconds: int = 604800
## Shifts the reset moment, in seconds after the unix epoch's midnight (UTC). A week boundary also moves by this.
@export_range(0, 604800, 60) var reset_offset_seconds: int = 0


func env_prefix() -> String:
	return "DOT_PROGRESSION_"


func cli_prefix() -> String:
	return "--progression-"


func validate() -> GSResult:
	if base_xp < 1:
		return GSResult.fail(GSError.CODE_INVALID, "progression base_xp %d is below 1" % base_xp)
	if growth < 1.0:
		return GSResult.fail(GSError.CODE_INVALID, "progression growth %s is below 1.0, levels would get cheaper" % growth)
	if max_level < 0 or max_grant < 0 or daily_count < 0 or weekly_count < 0:
		return GSResult.fail(GSError.CODE_INVALID, "progression limits cannot be negative (0 is unlimited)")
	if day_seconds < 1 or week_seconds < 1:
		return GSResult.fail(GSError.CODE_INVALID, "progression periods must be at least one second")
	return GSResult.success(self)


## Defaults, then `cfg/addon/dot_progression/*.yml`, then environment and command line.
static func from_files() -> GSResult:
	var cfg := GSProgressionConfig.new()
	var files := GSAddonConfig.load_dir(ADDON)
	if not files.ok:
		return files
	cfg.apply_dictionary(files.value as Dictionary, "yml")
	return cfg.load_layered()
