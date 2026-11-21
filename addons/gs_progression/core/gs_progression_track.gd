class_name GSProgressionTrack
extends RefCounted

## A reward track (a season, a battle pass, an unlock table) as a document: {id, tiers: [{level, reward, premium}]}. A tier unlocks at a level; a premium tier also needs the premium entitlement. A server checks claims with no art loaded.

var id: String = ""
var tiers: Array = []


## Build a track from [param doc], failing on an empty id, a repeated level+premium pair, a level under 1 or an empty reward.
static func from_dict(doc: Dictionary) -> GSResult:
	var t := GSProgressionTrack.new()
	t.id = str(doc.get("id", ""))
	if t.id.is_empty():
		return GSResult.fail(GSError.CODE_INVALID, "track has no id")
	if not (doc.get("tiers") is Array):
		return GSResult.fail(GSError.CODE_INVALID, "track '%s' has no tiers list" % t.id)
	var seen := {}
	for raw in doc["tiers"]:
		if not (raw is Dictionary):
			return GSResult.fail(GSError.CODE_INVALID, "track '%s' has a tier that is not an object" % t.id)
		var level := int(raw.get("level", 0))
		var reward := str(raw.get("reward", ""))
		var premium := bool(raw.get("premium", false))
		if level < 1 or reward.is_empty():
			return GSResult.fail(GSError.CODE_INVALID, "track '%s' tier needs a level of at least 1 and a reward" % t.id)
		var key := "%d:%s" % [level, premium]
		if seen.has(key):
			return GSResult.fail(GSError.CODE_CONFLICT, "track '%s' has two %s tiers at level %d" % [t.id, "premium" if premium else "free", level])
		seen[key] = true
		t.tiers.append({"level": level, "reward": reward, "premium": premium})
	t.tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["level"] < b["level"])
	return GSResult.success(t)


func _key(tier: Dictionary) -> String:
	return "%s:%d:%s" % [id, tier["level"], tier["premium"]]


## Tiers a player at [param level] may claim and has not: reached, premium only with [param premium].
func claimable(state: Dictionary, level: int, premium: bool) -> Array:
	var out: Array = []
	for tier: Dictionary in tiers:
		if tier["level"] <= level and (premium or not tier["premium"]) and not (state["claimed"] as Array).has(_key(tier)):
			out.append(tier)
	return out


## Claim the tier at [param tier_level]. The value is {state, reward}; claiming twice, claiming early or claiming premium without it fails.
func claim(cfg: GSProgressionConfig, state: Dictionary, tier_level: int, premium_tier: bool, has_premium: bool) -> GSResult:
	var ok := GSProgressionState.validate(state)
	if not ok.ok:
		return ok
	for tier: Dictionary in tiers:
		if tier["level"] != tier_level or tier["premium"] != premium_tier:
			continue
		if premium_tier and not has_premium:
			return GSResult.fail(GSError.CODE_FORBIDDEN, "tier %d of '%s' needs premium" % [tier_level, id])
		if GSProgressionCurve.level_for(cfg, int(state["xp"])) < tier_level:
			return GSResult.fail(GSError.CODE_STATE, "level %d is not reached yet" % tier_level)
		if (state["claimed"] as Array).has(_key(tier)):
			return GSResult.fail(GSError.CODE_CONFLICT, "tier %d of '%s' is already claimed" % [tier_level, id])
		var next := state.duplicate(true)
		(next["claimed"] as Array).append(_key(tier))
		return GSResult.success({"state": next, "reward": tier["reward"]})
	return GSResult.fail(GSError.CODE_INVALID, "'%s' has no such tier at level %d" % [id, tier_level])
