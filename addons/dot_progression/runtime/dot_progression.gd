class_name DotProgression
extends RefCounted

## One player's live progression: the state Dictionary plus the signals a HUD wants. It holds no files and no nodes; [method to_dict] and [method load_dict] hand the state to whatever stores it (GameSpice Save, a server). Every change goes through the pure functions of [DotProgressionState], so a server running the same calls reaches the same numbers.

## XP was added. [param level] is the level after the grant.
signal xp_changed(xp: int, level: int)
## One or more levels were gained. [param unlocked] is what the unlock table opened.
signal leveled_up(level: int, levels_gained: int, unlocked: Array)
## A track tier was claimed.
signal reward_claimed(track_id: String, reward: String)

var config: DotProgressionConfig
var state: Dictionary = DotProgressionState.create()
## {id: level}, optional; see [DotProgressionUnlocks].
var unlocks: Dictionary = {}


func _init(p_config: DotProgressionConfig = null) -> void:
	config = p_config if p_config != null else DotProgressionConfig.new()


func xp() -> int:
	return int(state["xp"])


func level() -> int:
	return DotProgressionCurve.level_for(config, xp())


## {level, into, needed, fraction} for a progress bar.
func progress() -> Dictionary:
	return DotProgressionCurve.progress(config, xp())


## Adds XP. Fails like [method DotProgressionState.grant]; on success emits [signal xp_changed] and, when a level was gained, [signal leveled_up]. The value is the grant's {state, level_before, level_after, levels_gained}.
func grant(amount: int) -> DotResult:
	var r := DotProgressionState.grant(config, state, amount)
	if not r.ok:
		return r
	state = r.value["state"]
	xp_changed.emit(xp(), r.value["level_after"])
	if r.value["levels_gained"] > 0:
		leveled_up.emit(r.value["level_after"], r.value["levels_gained"], DotProgressionUnlocks.opened_between(unlocks, r.value["level_before"], r.value["level_after"]))
	return r


func is_unlocked(id: String) -> bool:
	return DotProgressionUnlocks.is_unlocked(unlocks, id, level())


## Claims a tier of [param track]; emits [signal reward_claimed]. The value is the reward id.
func claim(track: DotProgressionTrack, tier_level: int, premium_tier: bool = false, has_premium: bool = false) -> DotResult:
	var r := track.claim(config, state, tier_level, premium_tier, has_premium)
	if not r.ok:
		return r
	state = r.value["state"]
	reward_claimed.emit(track.id, r.value["reward"])
	return DotResult.success(r.value["reward"])


## The state to store.
func to_dict() -> Dictionary:
	return state.duplicate(true)


## Replaces the state with [param data] after validating it; a bad document leaves the current state untouched. A level that dropped (a lowered max_level) is simply the new level, nothing is announced.
func load_dict(data: Dictionary) -> DotResult:
	var ok := DotProgressionState.validate(data)
	if not ok.ok:
		return ok
	state = data.duplicate(true)
	return DotResult.success(self)
