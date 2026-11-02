class_name Economy
extends Node
## Pure game-rules simulation: resources, population, taxes, happiness, raids.

signal changed
signal message(text: String)

var res: Dictionary = {"gold": 100.0, "wood": 150.0, "stone": 50.0, "food": 80.0}
var last_delta: Dictionary = {"gold": 0.0, "wood": 0.0, "stone": 0.0, "food": 0.0}
var pop: int = 8
var soldiers: int = 0
var happiness: float = 55.0
var day: int = 1
var tax_level: int = 1
var ration_level: int = 1
var counts: Dictionary = {}
var next_raid_day: int = 12
var raid_count: int = 0
var breakdown: String = ""
var time_scale: float = 1.0
var _acc: float = 0.0
var _raid_penalty: float = 0.0
var _warned: bool = false

func _process(delta: float) -> void:
    if time_scale <= 0.0:
        return
    _acc += delta * time_scale
    while _acc >= Defs.TICK_SECONDS:
        _acc -= Defs.TICK_SECONDS
        tick()

func day_progress() -> float:
    return _acc / Defs.TICK_SECONDS

# ---- queries -------------------------------------------------------------
func count(id: String) -> int:
    return int(counts.get(id, 0))

func _sum_def(key: String) -> float:
    var total: float = 0.0
    for id in counts:
        var def: Dictionary = Defs.BUILDINGS[id]
        total += float(def.get(key, 0)) * float(counts[id])
    return total

func housing_capacity() -> int:
    return int(_sum_def("housing"))

func jobs() -> int:
    return int(_sum_def("jobs"))

func storage_capacity() -> int:
    return 300 + int(_sum_def("storage"))

func soldier_capacity() -> int:
    return count("barracks") * Defs.SOLDIERS_PER_BARRACKS

func worker_efficiency() -> float:
    var j: int = jobs()
    if j <= 0:
        return 1.0
    return minf(1.0, float(pop) / float(j))

func production_multiplier() -> float:
    return clampf(0.5 + happiness / 100.0, 0.5, 1.2)

func defense_rating() -> int:
    var d: int = soldiers * 3 + count("tower") * 8
    if count("town_center") > 0:
        d += 4
    return d

func raid_strength() -> int:
    return 8 + 6 * raid_count

func can_afford(cost: Dictionary) -> bool:
    for k in cost:
        if float(res.get(k, 0.0)) < float(cost[k]):
            return false
    return true

func spend(cost: Dictionary) -> void:
    for k in cost:
        res[k] = float(res[k]) - float(cost[k])
    changed.emit()

func add_building(id: String) -> void:
    counts[id] = count(id) + 1
    changed.emit()

func remove_building(id: String) -> void:
    counts[id] = maxi(0, count(id) - 1)
    var def: Dictionary = Defs.BUILDINGS[id]
    var cost: Dictionary = def["cost"]
    for k in cost:
        res[k] = float(res[k]) + float(cost[k]) * 0.5
    message.emit("%s demolished (50%% refund)." % def["name"])
    _clamp_pop()
    changed.emit()

# ---- player decisions ----------------------------------------------------
func set_tax(level: int) -> void:
    tax_level = clampi(level, 0, Defs.TAX_NAMES.size() - 1)
    changed.emit()

func set_ration(level: int) -> void:
    ration_level = clampi(level, 0, Defs.RATION_NAMES.size() - 1)
    changed.emit()

func recruit() -> bool:
    if soldiers >= soldier_capacity():
        message.emit("Build a barracks (or a bigger one) to recruit more soldiers.")
        return false
    if pop <= 2:
        message.emit("Too few peasants to recruit.")
        return false
    if not can_afford(Defs.RECRUIT_COST):
        message.emit("Not enough gold/wood to equip a soldier.")
        return false
    spend(Defs.RECRUIT_COST)
    pop -= 1
    soldiers += 1
    message.emit("A peasant took up arms. Soldiers: %d" % soldiers)
    changed.emit()
    return true

# ---- simulation ----------------------------------------------------------
func _clamp_pop() -> void:
    var cap: int = housing_capacity()
    if pop > cap:
        message.emit("%d peasants lost their homes and left." % (pop - cap))
        pop = cap

func tick() -> void:
    day += 1
    var before: Dictionary = res.duplicate()
    var eff: float = worker_efficiency()
    var mult: float = production_multiplier()
    for id in counts:
        var def: Dictionary = Defs.BUILDINGS[id]
        if def.has("produces"):
            var prod: Dictionary = def["produces"]
            for k in prod:
                res[k] = float(res[k]) + float(prod[k]) * float(counts[id]) * eff * mult

    # Food
    var need: float = float(pop + soldiers) * Defs.FOOD_PER_PERSON * float(Defs.RATION_MULT[ration_level])
    res["food"] = float(res["food"]) - need
    var starving: bool = false
    if float(res["food"]) < 0.0:
        res["food"] = 0.0
        starving = true

    # Taxes and upkeep
    res["gold"] = float(res["gold"]) + float(pop) * float(Defs.TAX_COIN[tax_level]) - float(soldiers) * Defs.SOLDIER_UPKEEP
    if float(res["gold"]) < 0.0:
        res["gold"] = 0.0
        if soldiers > 0:
            soldiers -= 1
            message.emit("Unpaid soldiers deserted!")

    # Storage cap
    var cap: float = float(storage_capacity())
    for k in ["wood", "stone", "food"]:
        if float(res[k]) > cap:
            res[k] = cap

    # Happiness
    var parts: PackedStringArray = []
    var target: float = 50.0
    var tax_mod: float = Defs.TAX_HAP[tax_level]
    var ration_mod: float = Defs.RATION_HAP[ration_level]
    target += tax_mod + ration_mod
    parts.append("Taxes %+d" % int(tax_mod))
    parts.append("Rations %+d" % int(ration_mod))
    var chapel_bonus: float = minf(24.0, _sum_def("happiness"))
    if chapel_bonus > 0.0:
        target += chapel_bonus
        parts.append("Chapels %+d" % int(chapel_bonus))
    if starving:
        target -= 25.0
        parts.append("Starvation -25")
    elif float(res["food"]) < need * 3.0:
        target -= 5.0
        parts.append("Low food -5")
    if _raid_penalty > 0.0:
        target -= _raid_penalty
        parts.append("Raid trauma -%d" % int(_raid_penalty))
        _raid_penalty = maxf(0.0, _raid_penalty - 3.0)
    target = clampf(target, 0.0, 100.0)
    breakdown = "Target %d: base 50, %s" % [int(target), ", ".join(parts)]
    happiness = move_toward(happiness, target, 6.0)

    # Population
    if starving and pop > 0:
        var lost: int = maxi(1, int(ceil(float(pop) * 0.1)))
        pop = maxi(0, pop - lost)
        message.emit("Famine! %d peasants starved or fled." % lost)
    elif happiness < 25.0 and pop > 1:
        pop -= 1
        message.emit("Unrest: a peasant family emigrated.")
    elif happiness >= 40.0 and pop < housing_capacity() and float(res["food"]) > float(pop) * 2.0:
        var growth: int = 1
        if happiness >= 70.0:
            growth = 2
        pop = mini(housing_capacity(), pop + growth)
    _clamp_pop()

    # Raids
    if day == next_raid_day - 2 and not _warned:
        _warned = true
        message.emit("Scouts report raiders (strength ~%d) arriving in 2 days!" % raid_strength())
    if day >= next_raid_day:
        _resolve_raid()

    for k in res:
        last_delta[k] = float(res[k]) - float(before[k])
    changed.emit()

func _resolve_raid() -> void:
    var strength: int = raid_strength()
    var defense: int = defense_rating()
    raid_count += 1
    next_raid_day = day + 10
    _warned = false
    if defense >= strength:
        happiness = minf(100.0, happiness + 5.0)
        var lost_s: int = int(float(soldiers) * 0.1)
        soldiers -= lost_s
        message.emit("Raiders repelled! Defense %d vs %d." % [defense, strength])
        return
    var deficit: float = float(strength - defense)
    var frac: float = minf(0.6, deficit / float(strength))
    res["gold"] = float(res["gold"]) * (1.0 - frac)
    res["food"] = float(res["food"]) * (1.0 - frac)
    var dead: int = mini(pop, int(ceil(deficit / 3.0)))
    pop -= dead
    soldiers = int(float(soldiers) * 0.5)
    _raid_penalty = 15.0
    message.emit("RAID! Defense %d < %d. Lost %d%% gold/food and %d peasants." % [defense, strength, int(frac * 100.0), dead])

# ---- persistence ---------------------------------------------------------
func to_dict() -> Dictionary:
    return {
        "res": res, "pop": pop, "soldiers": soldiers, "happiness": happiness, "day": day,
        "tax": tax_level, "ration": ration_level, "next_raid": next_raid_day, "raids": raid_count,
        "penalty": _raid_penalty,
    }

func from_dict(d: Dictionary) -> void:
    var r: Dictionary = d.get("res", {})
    for k in res:
        res[k] = float(r.get(k, res[k]))
    pop = int(d.get("pop", 8))
    soldiers = int(d.get("soldiers", 0))
    happiness = float(d.get("happiness", 55.0))
    day = int(d.get("day", 1))
    tax_level = int(d.get("tax", 1))
    ration_level = int(d.get("ration", 1))
    next_raid_day = int(d.get("next_raid", 12))
    raid_count = int(d.get("raids", 0))
    _raid_penalty = float(d.get("penalty", 0.0))
    _warned = false
    _acc = 0.0
    changed.emit()
