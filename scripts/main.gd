extends Node3D
## Game bootstrap: wires world, camera, economy and HUD together.

const KEEP_CELL := Vector2i(22, 22)

var economy: Economy
var world: World
var rig: CameraRig
var hud: Hud

var build_id: String = ""
var ghost_cell: Vector2i = Vector2i(-1, -1)
var selected: Node3D = null
var _last_autosave_day: int = 1

func _ready() -> void:
    _setup_environment()
    world = World.new()
    add_child(world)
    economy = Economy.new()
    add_child(economy)
    rig = CameraRig.new()
    add_child(rig)
    hud = Hud.new()
    add_child(hud)
    hud.setup(economy)
    rig.ui_blocker = hud.is_over_ui
    rig.tapped.connect(_on_tapped)
    rig.hovered.connect(_on_hovered)
    hud.build_selected.connect(_on_build_selected)
    hud.build_confirmed.connect(_confirm_build)
    hud.build_cancelled.connect(_cancel_build)
    hud.demolish_pressed.connect(_demolish_selected)
    hud.save_pressed.connect(save_game)
    hud.load_pressed.connect(load_game)
    economy.changed.connect(_on_economy_changed)
    _new_game()

func _new_game() -> void:
    var keep := world.place("town_center", KEEP_CELL)
    economy.counts["town_center"] = 1
    rig.focus_on(keep.position)
    economy.message.emit("Welcome, my lord. Build houses, farms and a woodcutter, then watch the treasury and mood.")
    economy.message.emit("Tap to position a building, tap again (or press Build) to place it. Drag to pan, pinch to zoom.")
    economy.changed.emit()

func _setup_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = Color(0.32, 0.52, 0.85)
    sm.sky_horizon_color = Color(0.76, 0.82, 0.9)
    sm.ground_horizon_color = Color(0.6, 0.62, 0.58)
    sm.ground_bottom_color = Color(0.25, 0.27, 0.22)
    sky.sky_material = sm
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.74, 0.8, 0.86)
    env.fog_density = 0.003
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 80.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    add_child(sun)

# ---- input -> game --------------------------------------------------------
func _ground_cell(screen_pos: Vector2, size: Vector2i) -> Variant:
    var o: Vector3 = rig.camera.project_ray_origin(screen_pos)
    var d: Vector3 = rig.camera.project_ray_normal(screen_pos)
    var p: Variant = world.ground_ray(o, d)
    if p == null:
        return null
    return world.point_to_cell(p, size)

func _build_size() -> Vector2i:
    var def: Dictionary = Defs.BUILDINGS[build_id]
    return def["size"]

func _on_tapped(pos: Vector2) -> void:
    if build_id != "":
        var c: Variant = _ground_cell(pos, _build_size())
        if c == null:
            return
        if c == ghost_cell and _can_place():
            _confirm_build()
        else:
            ghost_cell = c
            _update_ghost()
        return
    var cell: Variant = _ground_cell(pos, Vector2i(1, 1))
    if cell == null:
        _deselect()
        return
    if world.occupied.has(cell):
        _select(world.occupied[cell])
    else:
        _deselect()

func _on_hovered(pos: Vector2) -> void:
    if build_id == "":
        return
    var c: Variant = _ground_cell(pos, _build_size())
    if c != null and c != ghost_cell:
        ghost_cell = c
        _update_ghost()

func _on_build_selected(id: String) -> void:
    _deselect()
    build_id = id
    var vc: Variant = _ground_cell(get_viewport().get_visible_rect().size * 0.5, _build_size())
    ghost_cell = vc if vc != null else KEEP_CELL
    hud.show_place_bar(true)
    _update_ghost()

func _can_place() -> bool:
    if build_id == "":
        return false
    var def: Dictionary = Defs.BUILDINGS[build_id]
    return world.footprint_ok(ghost_cell, _build_size()) and economy.can_afford(def["cost"])

func _update_ghost() -> void:
    if build_id == "":
        return
    var def: Dictionary = Defs.BUILDINGS[build_id]
    var fits: bool = world.footprint_ok(ghost_cell, _build_size())
    var afford: bool = economy.can_afford(def["cost"])
    world.set_ghost(build_id, ghost_cell, fits and afford)
    var status: String = "OK"
    if not fits:
        status = "Blocked: trees, water, steep ground or another building."
    elif not afford:
        status = "Not enough resources."
    hud.set_place_status("%s (%s): %s" % [def["name"], hud._cost_text(def["cost"]), status], fits and afford)

func _confirm_build() -> void:
    if not _can_place():
        return
    var def: Dictionary = Defs.BUILDINGS[build_id]
    economy.spend(def["cost"])
    world.place(build_id, ghost_cell)
    economy.add_building(build_id)
    _update_ghost()

func _cancel_build() -> void:
    build_id = ""
    world.clear_ghost()
    hud.show_place_bar(false)

func _select(node: Node3D) -> void:
    selected = node
    world.show_marker(node)
    hud.show_info(node)

func _deselect() -> void:
    selected = null
    world.hide_marker()
    hud.hide_info()

func _demolish_selected() -> void:
    if selected == null or not is_instance_valid(selected):
        return
    var id: String = selected.get_meta("id")
    if id == "town_center":
        return
    var node := selected
    _deselect()
    world.remove_building(node)
    economy.remove_building(id)

func _on_economy_changed() -> void:
    if build_id != "":
        _update_ghost()
    if economy.day % 10 == 0 and economy.day != _last_autosave_day:
        _last_autosave_day = economy.day
        save_game(true)

# ---- save / load ----------------------------------------------------------
func save_game(silent: bool = false) -> void:
    var list: Array = []
    for node in world.building_root.get_children():
        if node.is_queued_for_deletion():
            continue
        var cell: Vector2i = node.get_meta("cell")
        list.append({"id": node.get_meta("id"), "x": cell.x, "y": cell.y})
    var data := {
        "version": 1,
        "economy": economy.to_dict(),
        "buildings": list,
        "camera": {"x": rig.position.x, "z": rig.position.z, "yaw": rig.yaw, "dist": rig.dist},
    }
    var ok: bool = SaveSystem.write(data)
    if not silent or not ok:
        economy.message.emit("Game saved." if ok else "Saving failed!")

func load_game() -> void:
    var data: Dictionary = SaveSystem.read()
    if data.is_empty():
        economy.message.emit("No save file found.")
        return
    _cancel_build()
    _deselect()
    world.clear_buildings()
    economy.counts.clear()
    var list: Array = data.get("buildings", [])
    for e in list:
        var id: String = str(e["id"])
        if not Defs.BUILDINGS.has(id):
            continue
        world.place(id, Vector2i(int(e["x"]), int(e["y"])))
        economy.counts[id] = economy.count(id) + 1
    economy.from_dict(data.get("economy", {}))
    var cam: Dictionary = data.get("camera", {})
    rig.focus_on(Vector3(float(cam.get("x", 0.0)), 0.0, float(cam.get("z", 0.0))))
    rig.yaw = float(cam.get("yaw", rig.yaw))
    _last_autosave_day = economy.day
    economy.message.emit("Game loaded (day %d)." % economy.day)
