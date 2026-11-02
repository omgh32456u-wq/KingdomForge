extends SceneTree
## Headless logic checks. Run once with `godot --headless --import` (builds the
## class cache), then:  godot --headless --script tests/run_checks.gd

var _fail: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_fail += 1

func _init() -> void:
	var e := Economy.new()
	e.counts["town_center"] = 1
	_check(e.housing_capacity() == 10, "keep houses 10")
	_check(e.can_afford({"wood": 20}), "can afford house")
	e.spend({"wood": 20})
	_check(is_equal_approx(float(e.res["wood"]), 130.0), "spend deducts")
	var food0: float = e.res["food"]
	e.tick()
	_check(float(e.res["food"]) < food0, "food consumed")
	_check(e.day == 2, "day advances")
	e.counts["farm"] = 1
	e.pop = 10
	var f1: float = e.res["food"]
	e.tick()
	_check(float(e.res["food"]) > f1 - 5.0, "farm offsets consumption")
	# starvation
	var s := Economy.new()
	s.counts["town_center"] = 1
	s.res["food"] = 0.0
	s.tick()
	_check(s.pop < 8, "starvation reduces population")
	# raid with no defense hurts, with towers is repelled
	var r := Economy.new()
	r.counts["town_center"] = 1
	r.next_raid_day = 2
	r.tick()
	_check(r.raid_count == 1, "raid resolved")
	var rd := Economy.new()
	rd.counts["town_center"] = 1
	rd.counts["tower"] = 2
	_check(rd.defense_rating() >= rd.raid_strength(), "two towers beat first raid")
	# world placement
	var w := World.new()
	root.add_child(w)
	_check(w.footprint_ok(Vector2i(22, 22), Vector2i(5, 5)), "keep site is buildable")
	var node := w.place("house", Vector2i(30, 22))
	_check(not w.footprint_ok(Vector2i(30, 22), Vector2i(2, 2)), "occupied cells reject placement")
	w.remove_building(node)
	_check(w.footprint_ok(Vector2i(30, 22), Vector2i(2, 2)), "removal frees cells")
	print("FAILURES: ", _fail)
	quit(_fail)
