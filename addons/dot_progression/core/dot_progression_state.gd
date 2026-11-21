class_name DotProgressionState
extends RefCounted

## One player's progression as a small Dictionary a server can validate and store: {xp, claimed}. Pure functions; the caller owns where it lives.


static func create() -> Dictionary:
	return {"xp": 0, "claimed": []}


## A state a server can trust: integer xp of at least 0 and a list of strings.
static func validate(state: Dictionary) -> DotResult:
	if not (state.get("xp") is int or state.get("xp") is float) or float(state["xp"]) < 0.0 or float(state["xp"]) != floorf(float(state["xp"])):
		return DotResult.fail(DotError.CODE_INVALID, "progression xp must be a whole number of at least 0")
	if not (state.get("claimed") is Array):
		return DotResult.fail(DotError.CODE_INVALID, "progression claimed must be a list")
	for c in state["claimed"]:
		if not (c is String):
			return DotResult.fail(DotError.CODE_INVALID, "progression claimed entries must be strings")
	return DotResult.success(state)


## Add [param amount] XP. The value is {state, level_before, level_after, levels_gained}; the input is not modified. A negative amount or one over max_grant fails.
static func grant(cfg: DotProgressionConfig, state: Dictionary, amount: int) -> DotResult:
	if not cfg.enabled:
		return DotResult.fail(DotError.CODE_STATE, "progression is disabled")
	if amount < 0:
		return DotResult.fail(DotError.CODE_INVALID, "xp grant %d is negative" % amount)
	if cfg.max_grant > 0 and amount > cfg.max_grant:
		return DotResult.fail(DotError.CODE_FORBIDDEN, "xp grant %d is over max_grant %d" % [amount, cfg.max_grant])
	var ok := validate(state)
	if not ok.ok:
		return ok
	var before := DotProgressionCurve.level_for(cfg, int(state["xp"]))
	var next := state.duplicate(true)
	next["xp"] = int(state["xp"]) + amount
	var after := DotProgressionCurve.level_for(cfg, int(next["xp"]))
	return DotResult.success({"state": next, "level_before": before, "level_after": after, "levels_gained": after - before})
