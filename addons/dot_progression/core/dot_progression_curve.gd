class_name GSProgressionCurve
extends RefCounted

## The XP curve as pure functions: what a level costs, what total XP a level needs and which level a total is. Levels count from 1.


## XP to go from [param level] to the next.
static func xp_to_next(cfg: GSProgressionConfig, level: int) -> int:
	if level < 1:
		return cfg.base_xp
	return maxi(1, int(floor(cfg.base_xp * pow(cfg.growth, level - 1) + 0.000001)))


## Total XP at which [param level] is reached. Level 1 is 0.
static func total_xp_for(cfg: GSProgressionConfig, level: int) -> int:
	if cfg.growth == 1.0:
		return maxi(0, level - 1) * cfg.base_xp
	var total := 0
	for l in range(1, level):
		total += xp_to_next(cfg, l)
	return total


## The level a total of [param xp] is, never above [member GSProgressionConfig.max_level] when that is set.
static func level_for(cfg: GSProgressionConfig, xp: int) -> int:
	if cfg.growth == 1.0:
		var flat := 1 + maxi(0, xp) / cfg.base_xp
		return mini(flat, cfg.max_level) if cfg.max_level > 0 else flat
	var level := 1
	var need := xp_to_next(cfg, 1)
	var left := maxi(0, xp)
	while left >= need:
		if cfg.max_level > 0 and level >= cfg.max_level:
			break
		left -= need
		level += 1
		need = xp_to_next(cfg, level)
	return level


## {level, into, needed, fraction}: where [param xp] sits inside its level. At the top level `needed` is 0 and `fraction` is 1.
static func progress(cfg: GSProgressionConfig, xp: int) -> Dictionary:
	var level := level_for(cfg, xp)
	var into := maxi(0, xp) - total_xp_for(cfg, level)
	if cfg.max_level > 0 and level >= cfg.max_level:
		return {"level": level, "into": into, "needed": 0, "fraction": 1.0}
	var needed := xp_to_next(cfg, level)
	return {"level": level, "into": into, "needed": needed, "fraction": float(into) / float(needed)}
