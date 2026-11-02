class_name Defs
extends RefCounted
## Static game data: balance constants and building definitions.

const CELL: float = 2.0            # metres per grid cell
const GRID: int = 48               # cells per side (96 m map)
const TICK_SECONDS: float = 5.0    # one in-game "day" at 1x speed
const FOOD_PER_PERSON: float = 0.4
const SOLDIER_UPKEEP: float = 0.5  # gold per soldier per day
const SOLDIERS_PER_BARRACKS: int = 8
const RECRUIT_COST := {"gold": 10, "wood": 5}

const TAX_NAMES := ["None", "Low", "Normal", "High", "Brutal"]
const TAX_COIN := [0.0, 0.5, 1.0, 1.5, 2.0]
const TAX_HAP := [10.0, 4.0, 0.0, -8.0, -18.0]
const RATION_NAMES := ["Half", "Normal", "Extra"]
const RATION_MULT := [0.5, 1.0, 1.5]
const RATION_HAP := [-15.0, 0.0, 10.0]

const BUILD_ORDER := ["house", "farm", "woodcutter", "quarry", "granary", "tower", "barracks", "chapel"]

const BUILDINGS := {
    "town_center": {
        "name": "Keep", "cost": {}, "size": Vector2i(5, 5), "housing": 10, "jobs": 0,
        "desc": "Your seat of power. Houses 10 peasants and adds 4 defense.",
    },
    "house": {
        "name": "House", "cost": {"wood": 20}, "size": Vector2i(2, 2), "housing": 5, "jobs": 0,
        "desc": "Houses 5 peasants. More housing lets the population grow.",
    },
    "farm": {
        "name": "Farm", "cost": {"wood": 30}, "size": Vector2i(3, 3), "housing": 0, "jobs": 2,
        "produces": {"food": 10.0},
        "desc": "Grows 10 food per day when fully staffed (2 workers).",
    },
    "woodcutter": {
        "name": "Woodcutter", "cost": {"wood": 20}, "size": Vector2i(2, 2), "housing": 0, "jobs": 2,
        "produces": {"wood": 6.0},
        "desc": "Fells trees for 6 wood per day (2 workers).",
    },
    "quarry": {
        "name": "Quarry", "cost": {"wood": 30}, "size": Vector2i(3, 3), "housing": 0, "jobs": 3,
        "produces": {"stone": 5.0},
        "desc": "Cuts 5 stone per day (3 workers).",
    },
    "granary": {
        "name": "Granary", "cost": {"wood": 40, "stone": 10}, "size": Vector2i(3, 3), "housing": 0, "jobs": 0,
        "storage": 200,
        "desc": "Raises wood, stone and food storage by 200.",
    },
    "tower": {
        "name": "Watchtower", "cost": {"wood": 20, "stone": 40}, "size": Vector2i(2, 2), "housing": 0, "jobs": 0,
        "defense": 8,
        "desc": "Adds 8 defense against raiders.",
    },
    "barracks": {
        "name": "Barracks", "cost": {"wood": 60, "stone": 30, "gold": 30}, "size": Vector2i(3, 3), "housing": 0, "jobs": 0,
        "desc": "Lets you recruit up to 8 soldiers (3 defense each, 0.5 gold/day upkeep).",
    },
    "chapel": {
        "name": "Chapel", "cost": {"wood": 40, "stone": 60, "gold": 40}, "size": Vector2i(3, 2), "housing": 0, "jobs": 0,
        "happiness": 8.0,
        "desc": "+8 happiness each (max +24). Content peasants work harder.",
    },
}
