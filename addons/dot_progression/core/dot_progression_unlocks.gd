class_name DotProgressionUnlocks
extends RefCounted

## An unlock table as pure functions: which things a level opens. A table is {id: level}, for example {"skin_red": 5, "map_dunes": 12}. Server and client agree because there is nothing but the level to look at.


## Checks a table: every id non-empty and every level at least 1.
static func validate(table: Dictionary) -> DotResult:
	for id in table:
		if not (id is String) or (id as String).is_empty():
			return DotResult.fail(DotError.CODE_INVALID, "unlock ids must be non-empty strings")
		if not (table[id] is int or table[id] is float) or int(table[id]) < 1:
			return DotResult.fail(DotError.CODE_INVALID, "unlock '%s' needs a level of at least 1" % id)
	return DotResult.success(table)


## True when [param id] is open at [param level]. An id that is not in the table is not unlocked.
static func is_unlocked(table: Dictionary, id: String, level: int) -> bool:
	return table.has(id) and int(table[id]) <= level


## Every id open at [param level], sorted by level then id.
static func unlocked_at(table: Dictionary, level: int) -> Array:
	return _between(table, 0, level)


## Ids that open when going from [param from_level] (exclusive) to [param to_level] (inclusive): what to announce after a level-up.
static func opened_between(table: Dictionary, from_level: int, to_level: int) -> Array:
	return _between(table, from_level, to_level)


## The level at which [param id] opens, or 0 when it is not in the table.
static func level_of(table: Dictionary, id: String) -> int:
	return int(table.get(id, 0))


static func _between(table: Dictionary, low: int, high: int) -> Array:
	var rows: Array = []
	for id in table:
		var l := int(table[id])
		if l > low and l <= high:
			rows.append([l, id])
	rows.sort()
	var out: Array = []
	for r: Array in rows:
		out.append(r[1])
	return out
