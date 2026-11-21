class_name GSProgressionChallenges
extends RefCounted

## Daily and weekly challenges as pure functions: which period a time falls in, a deterministic deal from a pool, and progress that resets when the period turns. A pool entry is {id, goal}; the deal is the same on server and client.

const DAILY := "daily"
const WEEKLY := "weekly"


## The period number [param unix] falls in. It changes at each reset.
static func period_key(cfg: GSProgressionConfig, unix: int, kind: String) -> int:
	var length := cfg.week_seconds if kind == WEEKLY else cfg.day_seconds
	return int(floor(float(unix - cfg.reset_offset_seconds) / float(length)))


## Pick [param count] ids from [param pool], the same ones for the same [param seed_text] and period. A count of 0 deals the whole pool.
static func deal(pool: Array, seed_text: String, count: int) -> Array:
	var ranked: Array = []
	for entry: Dictionary in pool:
		ranked.append([GSHash.sha256_text(seed_text + "|" + str(entry["id"])), str(entry["id"])])
	ranked.sort()
	var out: Array = []
	for r: Array in ranked:
		if count > 0 and out.size() >= count:
			break
		out.append(r[1])
	return out


## What a player is dealt now: {period, ids}. [param player_seed] is a stable pseudonymous id.
static func assign(cfg: GSProgressionConfig, pool: Array, player_seed: String, unix: int, kind: String) -> Dictionary:
	var period := period_key(cfg, unix, kind)
	var count := cfg.weekly_count if kind == WEEKLY else cfg.daily_count
	return {"period": period, "ids": deal(pool, "%s|%s|%d" % [player_seed, kind, period], count)}


## Progress for a dealt set: keeps entries when [param dealt] is the period already held in [param held], otherwise starts every id at 0. Returns {period, entries: {id: {progress, done}}}.
static func roll(held: Dictionary, dealt: Dictionary) -> Dictionary:
	if held.get("period") == dealt["period"] and held.get("entries") is Dictionary:
		var entries: Dictionary = (held["entries"] as Dictionary).duplicate(true)
		for id in dealt["ids"]:
			if not entries.has(id):
				entries[id] = {"progress": 0, "done": false}
		return {"period": dealt["period"], "entries": entries}
	var fresh := {}
	for id in dealt["ids"]:
		fresh[id] = {"progress": 0, "done": false}
	return {"period": dealt["period"], "entries": fresh}


## Add [param amount] to a challenge of [param goal]. Progress stops at the goal; the value is the new entry. Negative amounts and unknown ids fail.
static func advance(rolled: Dictionary, id: String, goal: int, amount: int) -> GSResult:
	if amount < 0:
		return GSResult.fail(GSError.CODE_INVALID, "challenge progress %d is negative" % amount)
	if not (rolled["entries"] as Dictionary).has(id):
		return GSResult.fail(GSError.CODE_INVALID, "challenge '%s' is not dealt this period" % id)
	var e: Dictionary = (rolled["entries"] as Dictionary)[id]
	var p := mini(int(e["progress"]) + amount, goal)
	return GSResult.success({"progress": p, "done": p >= goal})
