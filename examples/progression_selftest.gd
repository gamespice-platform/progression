extends Node

## dot-progression's headless suite (res://examples/progression_selftest.tscn).
## Counts sections run to their last line as well as checks, because a script error aborts a section and not the run.

const EXPECTED_SECTIONS := 7
const EXPECTED_CHECKS := 82

var _passed := 0
var _failed := 0
var _sections := 0


func _ready() -> void:
	print("dot-progression")
	_config()
	_curve()
	_state()
	_track()
	_challenges()
	_unlocks()
	_runtime()
	print("")
	_check(_sections == EXPECTED_SECTIONS, "every section ran to its last line (%d of %d)" % [_sections, EXPECTED_SECTIONS])
	_check(_passed + _failed == EXPECTED_CHECKS, "and the suite ran all %d of its checks (%d)" % [EXPECTED_CHECKS, _passed + _failed])
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _config() -> void:
	var c := DotProgressionConfig.new()
	_check(c.validate().ok, "defaults validate")
	_check(c.max_level == 0 and c.max_grant == 0, "limits default to unlimited")
	c.growth = 0.9
	_check(not c.validate().ok, "a growth under 1 is refused")
	c.growth = 1.0
	c.base_xp = 0
	_check(not c.validate().ok, "a zero base_xp is refused")
	c.base_xp = 50
	c.max_grant = -1
	_check(not c.validate().ok, "a negative limit is refused")
	c.max_grant = 0
	var applied := c.apply_dictionary({"base_xp": 250, "growth": 1.5, "max_level": 30})
	_check(applied.size() == 3 and c.base_xp == 250 and c.growth == 1.5 and c.max_level == 30, "a dictionary layer sets every type", str(applied))
	_check(c.env_prefix() == "DOT_PROGRESSION_" and c.cli_prefix() == "--progression-", "env and command-line prefixes")
	var r := DotProgressionConfig.from_files()
	_check(r.ok and r.value is DotProgressionConfig, "from_files returns a config")
	_sections += 1


func _curve() -> void:
	var c := DotProgressionConfig.new()
	_check(DotProgressionCurve.xp_to_next(c, 1) == 100 and DotProgressionCurve.xp_to_next(c, 2) == 115 and DotProgressionCurve.xp_to_next(c, 3) == 132, "each level costs growth times the last, rounded down")
	_check(DotProgressionCurve.total_xp_for(c, 1) == 0 and DotProgressionCurve.total_xp_for(c, 3) == 215, "total xp for a level adds the levels below")
	_check(DotProgressionCurve.level_for(c, 0) == 1 and DotProgressionCurve.level_for(c, 99) == 1 and DotProgressionCurve.level_for(c, 100) == 2, "level boundaries are inclusive")
	_check(DotProgressionCurve.level_for(c, 214) == 2 and DotProgressionCurve.level_for(c, 215) == 3, "level 3 starts at 215")
	_check(DotProgressionCurve.level_for(c, -5) == 1, "negative xp is level 1")
	var p := DotProgressionCurve.progress(c, 157)
	_check(p["level"] == 2 and p["into"] == 57 and p["needed"] == 115 and is_equal_approx(p["fraction"], 57.0 / 115.0), "progress says where xp sits in its level")
	_check(DotProgressionCurve.level_for(c, 100000000) > 50, "unlimited max_level goes as far as the xp does")
	c.max_level = 3
	_check(DotProgressionCurve.level_for(c, 100000000) == 3, "max_level stops the climb")
	var top := DotProgressionCurve.progress(c, 100000000)
	_check(top["level"] == 3 and top["needed"] == 0 and top["fraction"] == 1.0, "the top level is full")
	c.growth = 1.0
	c.max_level = 0
	_check(DotProgressionCurve.xp_to_next(c, 40) == 100 and DotProgressionCurve.level_for(c, 1000) == 11, "growth 1.0 is a flat curve")
	_sections += 1


func _state() -> void:
	var c := DotProgressionConfig.new()
	var s := DotProgressionState.create()
	_check(DotProgressionState.validate(s).ok, "a new state is valid")
	var g := DotProgressionState.grant(c, s, 120)
	_check(g.ok and g.value["state"]["xp"] == 120 and g.value["level_before"] == 1 and g.value["level_after"] == 2 and g.value["levels_gained"] == 1, "a grant reports the level change")
	_check(s["xp"] == 0, "the input state is not modified")
	_check(DotProgressionState.grant(c, s, 1000).value["levels_gained"] >= 4, "a big grant can gain several levels")
	_check(DotProgressionState.grant(c, s, -1).code() == DotError.CODE_INVALID, "a negative grant is refused")
	c.max_grant = 500
	_check(DotProgressionState.grant(c, s, 501).code() == DotError.CODE_FORBIDDEN and DotProgressionState.grant(c, s, 500).ok, "max_grant refuses an over-large grant rather than clipping it")
	c.max_grant = 0
	_check(DotProgressionState.grant(c, s, 2000000000).ok, "zero max_grant is unlimited")
	_check(not DotProgressionState.validate({"xp": -1, "claimed": []}).ok, "negative stored xp is invalid")
	_check(not DotProgressionState.validate({"xp": 1.5, "claimed": []}).ok, "fractional stored xp is invalid")
	_check(not DotProgressionState.validate({"xp": 1, "claimed": [3]}).ok, "a claimed list of non-strings is invalid")
	_check(not DotProgressionState.validate({"xp": 1}).ok, "a missing claimed list is invalid")
	c.enabled = false
	_check(DotProgressionState.grant(c, s, 1).code() == DotError.CODE_STATE, "disabled fails loudly")
	_sections += 1


func _track() -> void:
	var c := DotProgressionConfig.new()
	var doc := {"id": "season1", "tiers": [
		{"level": 3, "reward": "spray_a"},
		{"level": 2, "reward": "title_x"},
		{"level": 2, "reward": "skin_gold", "premium": true},
	]}
	var r := DotProgressionTrack.from_dict(doc)
	_check(r.ok, "a track builds")
	var t: DotProgressionTrack = r.value
	_check(t.tiers[0]["level"] == 2 and t.tiers[2]["level"] == 3, "tiers sort by level")
	_check(not DotProgressionTrack.from_dict({"tiers": []}).ok, "no id is refused")
	_check(not DotProgressionTrack.from_dict({"id": "x"}).ok, "no tiers list is refused")
	_check(not DotProgressionTrack.from_dict({"id": "x", "tiers": [{"level": 0, "reward": "a"}]}).ok, "level 0 is refused")
	_check(not DotProgressionTrack.from_dict({"id": "x", "tiers": [{"level": 1, "reward": ""}]}).ok, "an empty reward is refused")
	_check(DotProgressionTrack.from_dict({"id": "x", "tiers": [{"level": 1, "reward": "a"}, {"level": 1, "reward": "b"}]}).code() == DotError.CODE_CONFLICT, "two free tiers at one level conflict")
	var s := DotProgressionState.create()
	s["xp"] = 215
	_check(t.claimable(s, 3, false).size() == 2, "a free player can claim the free tiers reached")
	_check(t.claimable(s, 3, true).size() == 3, "a premium player can claim all three")
	_check(t.claimable(s, 1, true).is_empty(), "nothing is claimable before level 2")
	var early := t.claim(c, DotProgressionState.create(), 2, false, false)
	_check(early.code() == DotError.CODE_STATE, "claiming before the level is reached fails")
	var nopremium := t.claim(c, s, 2, true, false)
	_check(nopremium.code() == DotError.CODE_FORBIDDEN, "premium without premium fails")
	var got := t.claim(c, s, 2, true, true)
	_check(got.ok and got.value["reward"] == "skin_gold", "a premium claim returns its reward")
	var s2: Dictionary = got.value["state"]
	_check(t.claim(c, s2, 2, true, true).code() == DotError.CODE_CONFLICT, "claiming twice is a conflict")
	_check(t.claimable(s2, 3, true).size() == 2 and s["claimed"].is_empty(), "claimed tiers leave the list and the input is untouched")
	_check(t.claim(c, s, 9, false, true).code() == DotError.CODE_INVALID, "an unknown tier is refused")
	_sections += 1


func _challenges() -> void:
	var c := DotProgressionConfig.new()
	var pool: Array = []
	for i in 10:
		pool.append({"id": "ch%d" % i, "goal": 5})
	_check(DotProgressionChallenges.period_key(c, 0, "daily") == 0 and DotProgressionChallenges.period_key(c, 86399, "daily") == 0 and DotProgressionChallenges.period_key(c, 86400, "daily") == 1, "a day is a period of 86400 seconds")
	_check(DotProgressionChallenges.period_key(c, 604800, "weekly") == 1, "a week is a period of 604800 seconds")
	c.reset_offset_seconds = 3600
	_check(DotProgressionChallenges.period_key(c, 3599, "daily") == -1 and DotProgressionChallenges.period_key(c, 3600, "daily") == 0, "the reset offset shifts the boundary")
	c.reset_offset_seconds = 0
	var a := DotProgressionChallenges.assign(c, pool, "p1", 1000, "daily")
	var b := DotProgressionChallenges.assign(c, pool, "p1", 5000, "daily")
	_check(a["ids"].size() == 3 and a["ids"] == b["ids"], "the same player gets the same three all day")
	_check(a["ids"] != DotProgressionChallenges.assign(c, pool, "p1", 90000, "daily")["ids"] or a["period"] != 1, "the next day deals again")
	var others := 0
	for i in 20:
		if DotProgressionChallenges.assign(c, pool, "q%d" % i, 1000, "daily")["ids"] != a["ids"]:
			others += 1
	_check(others > 10, "different players are dealt different sets", str(others))
	c.daily_count = 0
	_check(DotProgressionChallenges.assign(c, pool, "p1", 1000, "daily")["ids"].size() == 10, "a count of 0 deals the whole pool")
	c.daily_count = 3
	var rolled := DotProgressionChallenges.roll({}, a)
	_check(rolled["entries"].size() == 3 and rolled["period"] == a["period"], "a fresh roll starts every id at 0")
	var id: String = a["ids"][0]
	var adv := DotProgressionChallenges.advance(rolled, id, 5, 3)
	_check(adv.ok and adv.value["progress"] == 3 and not adv.value["done"], "progress adds up")
	rolled["entries"][id] = adv.value
	var done := DotProgressionChallenges.advance(rolled, id, 5, 10)
	_check(done.value["progress"] == 5 and done.value["done"], "progress stops at the goal and marks done")
	_check(DotProgressionChallenges.advance(rolled, "nope", 5, 1).code() == DotError.CODE_INVALID, "an undealt challenge is refused")
	_check(DotProgressionChallenges.advance(rolled, id, 5, -1).code() == DotError.CODE_INVALID, "negative progress is refused")
	_check(DotProgressionChallenges.roll(rolled, a)["entries"][id]["progress"] == 3, "the same period keeps its progress")
	var next := DotProgressionChallenges.assign(c, pool, "p1", 90000, "daily")
	_check(DotProgressionChallenges.roll(rolled, next)["entries"][next["ids"][0]]["progress"] == 0, "a new period resets progress")
	_sections += 1


func _unlocks() -> void:
	var t := {"skin": 5, "map": 12, "hat": 5}
	_check(DotProgressionUnlocks.validate(t).ok, "a table validates")
	_check(not DotProgressionUnlocks.validate({"x": 0}).ok and not DotProgressionUnlocks.validate({"": 1}).ok, "level 0 and empty ids are refused")
	_check(DotProgressionUnlocks.is_unlocked(t, "skin", 5) and not DotProgressionUnlocks.is_unlocked(t, "skin", 4), "unlocks at its level")
	_check(not DotProgressionUnlocks.is_unlocked(t, "nope", 99), "an unknown id is never unlocked")
	_check(DotProgressionUnlocks.unlocked_at(t, 5) == ["hat", "skin"], "unlocked_at sorts by level then id")
	_check(DotProgressionUnlocks.opened_between(t, 5, 12) == ["map"], "opened_between excludes the lower bound")
	_check(DotProgressionUnlocks.level_of(t, "map") == 12 and DotProgressionUnlocks.level_of(t, "zz") == 0, "level_of")
	var c := DotProgressionConfig.new()
	c.growth = 1.0
	c.base_xp = 10
	_check(DotProgressionCurve.level_for(c, 2000000000) == 200000001, "a flat curve is closed form, not a loop")
	_check(DotProgressionCurve.total_xp_for(c, 4) == 30, "flat total xp")
	c.max_level = 5
	_check(DotProgressionCurve.level_for(c, 1000000) == 5, "a flat curve honours max_level")
	_sections += 1


func _runtime() -> void:
	var p := DotProgression.new()
	p.unlocks = {"skin": 2}
	var log := []
	p.xp_changed.connect(func(x, l): log.append("xp:%d:%d" % [x, l]))
	p.leveled_up.connect(func(l, n, u): log.append("up:%d:%d:%s" % [l, n, u]))
	_check(p.level() == 1 and p.xp() == 0, "starts at level 1")
	_check(p.grant(50).ok and log == ["xp:50:1"], "a small grant only changes xp")
	log.clear()
	_check(p.grant(60).ok and log == ["xp:110:2", "up:2:1:[\"skin\"]"], "a level-up announces what it unlocked")
	_check(p.is_unlocked("skin") and not p.is_unlocked("other"), "is_unlocked follows the level")
	_check(p.progress()["level"] == 2, "progress reports the level")
	_check(p.grant(-1).code() == DotError.CODE_INVALID and p.xp() == 110, "a refused grant changes nothing")
	var saved := p.to_dict()
	saved["xp"] = 5
	_check(p.xp() == 110, "to_dict is a copy")
	var q := DotProgression.new()
	_check(q.load_dict({"xp": 300, "claimed": []}).ok and q.xp() == 300, "load_dict restores a state")
	_check(not q.load_dict({"xp": -4, "claimed": []}).ok and q.xp() == 300, "a bad document leaves the state alone")
	var track: DotProgressionTrack = DotProgressionTrack.from_dict({"id": "s1", "tiers": [{"level": 2, "reward": "gem"}]}).value
	var claimed := []
	q.reward_claimed.connect(func(t, r): claimed.append(t + ":" + r))
	_check(q.claim(track, 2).value == "gem" and claimed == ["s1:gem"], "claim emits the reward")
	_check(q.claim(track, 2).code() == DotError.CODE_CONFLICT, "a second claim fails")
	_sections += 1


func _check(ok: bool, what: String, extra: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FAIL  ", what, "  ", extra)
