class_name BuildingFactory
extends RefCounted
## Procedurally assembles medieval building models from low-poly parts
## (stone plinths, timber framing, gabled roofs, crenellations, banners).
## All models are centred on the origin, base at y = 0, footprint = size * Defs.CELL.

const STONE := Color(0.56, 0.55, 0.51)
const STONE_D := Color(0.38, 0.37, 0.35)
const PLASTER := Color(0.82, 0.76, 0.62)
const TIMBER := Color(0.30, 0.19, 0.10)
const WOOD := Color(0.50, 0.34, 0.18)
const THATCH := Color(0.72, 0.60, 0.30)
const TILE := Color(0.60, 0.27, 0.17)
const SLATE := Color(0.28, 0.31, 0.36)
const BANNER := Color(0.70, 0.10, 0.10)
const DIRT := Color(0.34, 0.24, 0.13)
const CROP := Color(0.46, 0.64, 0.20)
const HAY := Color(0.80, 0.68, 0.30)
const DARK := Color(0.08, 0.06, 0.05)

static var _mats: Dictionary = {}

static func _mat(c: Color) -> StandardMaterial3D:
    var key: String = c.to_html()
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.95
    _mats[key] = m
    return m

static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    m.mesh = mesh
    m.material_override = _mat(c)
    m.position = pos
    m.rotation_degrees = rot
    parent.add_child(m)
    return m

## Box with its base at y.
static func b(p: Node3D, w: float, h: float, d: float, x: float, y: float, z: float, c: Color, rot_y: float = 0.0) -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(w, h, d)
    _mi(p, mesh, Vector3(x, y + h * 0.5, z), c, Vector3(0, rot_y, 0))

## Cylinder / cone (r_top = 0) with its base at y.
static func cyl(p: Node3D, r_top: float, r_bot: float, h: float, x: float, y: float, z: float, c: Color, segs: int = 12, rot_y: float = 0.0) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r_top
    mesh.bottom_radius = r_bot
    mesh.height = h
    mesh.radial_segments = segs
    mesh.rings = 1
    _mi(p, mesh, Vector3(x, y + h * 0.5, z), c, Vector3(0, rot_y, 0))

## Gabled roof: ridge runs along local Z, then rotated by rot_y.
static func roof(p: Node3D, w: float, h: float, d: float, x: float, y: float, z: float, c: Color, rot_y: float = 0.0) -> void:
    var mesh := PrismMesh.new()
    mesh.size = Vector3(w, h, d)
    _mi(p, mesh, Vector3(x, y + h * 0.5, z), c, Vector3(0, rot_y, 0))

static func log_pile(p: Node3D, x: float, z: float) -> void:
    for i in 3:
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.18
        mesh.bottom_radius = 0.18
        mesh.height = 1.4
        mesh.radial_segments = 6
        mesh.rings = 1
        _mi(p, mesh, Vector3(x + (i - 1) * 0.36, 0.2, z), WOOD, Vector3(90, 0, 0))
    var top := CylinderMesh.new()
    top.top_radius = 0.18
    top.bottom_radius = 0.18
    top.height = 1.4
    top.radial_segments = 6
    top.rings = 1
    _mi(p, top, Vector3(x, 0.55, z), WOOD, Vector3(90, 0, 0))

static func banner(p: Node3D, x: float, y: float, z: float, pole_h: float) -> void:
    cyl(p, 0.05, 0.06, pole_h, x, y, z, TIMBER, 5)
    b(p, 0.8, 0.5, 0.04, x + 0.42, y + pole_h - 0.6, z, BANNER)

static func merlons(p: Node3D, radius: float, count: int, x: float, y: float, z: float, c: Color) -> void:
    for i in count:
        var a: float = TAU * float(i) / float(count)
        b(p, 0.5, 0.55, 0.5, x + cos(a) * radius, y, z + sin(a) * radius, c, -rad_to_deg(a))

static func create(id: String) -> Node3D:
    var n := Node3D.new()
    n.name = id
    match id:
        "house": _house(n)
        "farm": _farm(n)
        "woodcutter": _woodcutter(n)
        "quarry": _quarry(n)
        "granary": _granary(n)
        "tower": _tower(n)
        "barracks": _barracks(n)
        "chapel": _chapel(n)
        "town_center": _keep(n)
        _: b(n, 2.0, 2.0, 2.0, 0, 0, 0, STONE)
    return n

static func _house(n: Node3D) -> void:
    b(n, 3.0, 0.9, 3.0, 0, 0, 0, STONE)
    b(n, 2.8, 1.3, 2.8, 0, 0.9, 0, PLASTER)
    for sx in [-1.45, 1.45]:
        for sz in [-1.45, 1.45]:
            b(n, 0.2, 2.2, 0.2, sx, 0, sz, TIMBER)
    for s in [-1.45, 1.45]:
        b(n, 3.0, 0.15, 0.15, 0, 0.85, s, TIMBER)
        b(n, 0.15, 0.15, 3.0, s, 0.85, 0, TIMBER)
    roof(n, 3.9, 1.5, 3.7, 0, 2.2, 0, THATCH)
    b(n, 0.6, 1.2, 0.1, 0, 0, 1.45, TIMBER)
    b(n, 0.4, 0.4, 0.1, -0.95, 1.1, 1.42, DARK)
    b(n, 0.4, 0.4, 0.1, 0.95, 1.1, 1.42, DARK)
    b(n, 0.4, 1.3, 0.4, 1.0, 1.9, -0.8, STONE_D)

static func _farm(n: Node3D) -> void:
    b(n, 5.6, 0.12, 5.6, 0, 0, 0, DIRT)
    for i in 5:
        b(n, 5.0, 0.3, 0.35, 0, 0.1, -0.4 + i * 0.7, CROP)
    b(n, 2.4, 1.3, 1.6, -1.5, 0.1, -2.2, WOOD)
    roof(n, 2.9, 1.0, 1.9, -1.5, 1.4, -2.2, TILE)
    b(n, 0.5, 0.6, 0.5, 1.7, 0.1, -2.2, HAY)
    b(n, 0.5, 0.6, 0.5, 2.3, 0.1, -2.0, HAY, 25.0)
    cyl(n, 0.05, 0.05, 1.5, 2.2, 0.1, 1.2, TIMBER, 5)
    b(n, 0.9, 0.12, 0.12, 2.2, 1.2, 1.2, TIMBER)

static func _woodcutter(n: Node3D) -> void:
    b(n, 2.0, 1.4, 1.8, -0.5, 0, -0.5, WOOD)
    roof(n, 2.5, 1.0, 2.1, -0.5, 1.4, -0.5, THATCH)
    b(n, 0.5, 0.9, 0.1, -0.5, 0, 0.42, TIMBER)
    log_pile(n, 1.0, 0.8)
    cyl(n, 0.35, 0.4, 0.5, -1.3, 0, 1.2, WOOD, 8)
    b(n, 0.08, 0.7, 0.08, -1.3, 0.5, 1.2, TIMBER)

static func _quarry(n: Node3D) -> void:
    b(n, 5.4, 0.1, 5.4, 0, 0, 0, STONE_D)
    b(n, 1.2, 0.8, 1.4, 0.5, 0.1, 0.6, STONE, 15.0)
    b(n, 1.0, 0.6, 1.0, 1.7, 0.1, 1.2, STONE, -20.0)
    b(n, 0.9, 0.5, 0.9, -0.8, 0.1, 1.6, STONE, 40.0)
    b(n, 1.0, 1.4, 1.0, 1.0, 0.1, -0.4, STONE, 10.0)
    for z in [-2.1, -0.3]:
        b(n, 0.2, 3.0, 0.2, -2.1, 0, z, WOOD)
    b(n, 0.2, 0.2, 2.1, -2.1, 3.0, -1.2, WOOD)
    b(n, 2.6, 0.2, 0.2, -0.8, 2.8, -1.2, WOOD)
    b(n, 0.04, 1.2, 0.04, 0.3, 1.6, -1.2, TIMBER)
    b(n, 0.5, 0.4, 0.5, 0.3, 1.2, -1.2, STONE)
    b(n, 1.6, 1.2, 1.4, 1.9, 0.1, -2.0, WOOD)
    roof(n, 2.0, 0.8, 1.7, 1.9, 1.3, -2.0, SLATE)

static func _granary(n: Node3D) -> void:
    b(n, 5.2, 0.8, 4.6, 0, 0, 0, STONE)
    b(n, 4.8, 2.0, 4.2, 0, 0.8, 0, WOOD)
    roof(n, 5.6, 2.0, 4.8, 0, 2.8, 0, TILE)
    b(n, 1.3, 1.6, 0.14, 0, 0.8, 2.12, TIMBER)
    for x in [-2.3, 0.0, 2.3]:
        b(n, 0.2, 2.0, 0.16, x, 0.8, 2.12, TIMBER)
    cyl(n, 0.35, 0.4, 0.8, 2.0, 0, 2.7, WOOD, 8)
    cyl(n, 0.35, 0.4, 0.8, 1.3, 0, 2.7, WOOD, 8)
    b(n, 0.5, 0.5, 0.5, -2.1, 0, 2.7, HAY)

static func _tower(n: Node3D) -> void:
    cyl(n, 1.35, 1.65, 3.0, 0, 0, 0, STONE)
    cyl(n, 1.25, 1.35, 2.8, 0, 3.0, 0, STONE)
    cyl(n, 1.6, 1.3, 0.4, 0, 5.8, 0, STONE_D)
    merlons(n, 1.5, 8, 0, 6.2, 0, STONE)
    b(n, 0.14, 0.55, 0.1, 0, 3.4, 1.3, DARK)
    b(n, 0.14, 0.55, 0.1, 1.3, 3.4, 0, DARK, 90.0)
    b(n, 0.8, 1.2, 0.1, 0, 0, 1.58, TIMBER)
    banner(n, 0, 6.2, 0, 1.8)

static func _barracks(n: Node3D) -> void:
    b(n, 5.2, 0.8, 3.6, 0, 0, -0.9, STONE)
    b(n, 5.0, 1.8, 3.4, 0, 0.8, -0.9, PLASTER)
    for x in [-2.4, -0.8, 0.8, 2.4]:
        b(n, 0.2, 2.6, 0.2, x, 0, 0.8, TIMBER)
    roof(n, 4.0, 1.6, 5.7, 0, 2.6, -0.9, SLATE, 90.0)
    b(n, 0.9, 1.4, 0.1, 0, 0, 0.82, TIMBER)
    cyl(n, 0.1, 0.12, 1.6, -1.6, 0, 2.2, TIMBER, 6)
    b(n, 0.9, 0.14, 0.14, -1.6, 1.2, 2.2, TIMBER)
    b(n, 1.4, 0.8, 0.14, 1.4, 0, 2.2, WOOD)
    banner(n, 2.3, 0, 2.3, 3.0)

static func _chapel(n: Node3D) -> void:
    b(n, 4.4, 0.6, 3.0, -0.6, 0, 0, STONE)
    b(n, 4.2, 2.0, 2.8, -0.6, 0.6, 0, Color(0.74, 0.72, 0.66))
    roof(n, 3.2, 1.5, 4.8, -0.6, 2.6, 0, SLATE, 90.0)
    b(n, 1.5, 0.5, 1.5, 2.1, 0, 0, STONE)
    b(n, 1.3, 3.8, 1.3, 2.1, 0.5, 0, STONE)
    cyl(n, 0.0, 1.05, 2.0, 2.1, 4.3, 0, TILE, 4, 45.0)
    b(n, 0.1, 0.8, 0.1, 2.1, 6.3, 0, HAY)
    b(n, 0.4, 0.1, 0.1, 2.1, 6.8, 0, HAY)
    b(n, 0.7, 1.3, 0.1, -1.4, 0.6, 1.42, TIMBER)
    b(n, 0.3, 0.9, 0.1, -0.2, 1.0, 1.42, Color(0.3, 0.45, 0.7))

static func _keep(n: Node3D) -> void:
    b(n, 9.6, 0.12, 9.6, 0, 0, 0, STONE_D)
    # curtain walls with a gate gap on the +Z side
    b(n, 3.6, 2.2, 0.6, -2.9, 0, 4.4, STONE)
    b(n, 3.6, 2.2, 0.6, 2.9, 0, 4.4, STONE)
    b(n, 9.4, 2.2, 0.6, 0, 0, -4.4, STONE)
    b(n, 0.6, 2.2, 8.2, -4.4, 0, 0, STONE)
    b(n, 0.6, 2.2, 8.2, 4.4, 0, 0, STONE)
    for sx in [-4.4, 4.4]:
        for sz in [-4.4, 4.4]:
            cyl(n, 1.0, 1.2, 3.6, sx, 0, sz, STONE)
            cyl(n, 0.0, 1.35, 1.5, sx, 3.6, sz, SLATE, 10)
    # keep
    b(n, 4.6, 0.8, 3.8, 0, 0, -1.6, STONE_D)
    b(n, 4.2, 3.6, 3.4, 0, 0.8, -1.6, STONE)
    for i in 6:
        b(n, 0.6, 0.6, 0.6, -2.0 + i * 0.8, 4.4, -0.1, STONE)
        b(n, 0.6, 0.6, 0.6, -2.0 + i * 0.8, 4.4, -3.1, STONE)
    roof(n, 3.6, 1.4, 3.8, 0, 4.4, -1.6, SLATE, 90.0)
    b(n, 1.0, 1.6, 0.1, 0, 0.8, 0.12, TIMBER)
    for x in [-1.3, 1.3]:
        b(n, 0.18, 0.7, 0.1, x, 2.4, 0.12, DARK)
    banner(n, 0, 5.4, -1.6, 2.6)
    # gate leaves, well and cart
    b(n, 1.1, 1.9, 0.1, -0.7, 0, 4.5, TIMBER, 70.0)
    b(n, 1.1, 1.9, 0.1, 0.7, 0, 4.5, TIMBER, -70.0)
    cyl(n, 0.6, 0.6, 0.7, 2.6, 0.1, 1.6, STONE, 10)
    b(n, 0.1, 1.2, 0.1, 2.1, 0.1, 1.6, TIMBER)
    b(n, 0.1, 1.2, 0.1, 3.1, 0.1, 1.6, TIMBER)
    roof(n, 1.4, 0.5, 0.9, 2.6, 1.3, 1.6, THATCH, 90.0)
    b(n, 1.6, 0.4, 1.0, -2.8, 0.1, 2.2, WOOD)
    b(n, 0.5, 0.5, 0.5, -2.8, 0.5, 2.2, HAY)
