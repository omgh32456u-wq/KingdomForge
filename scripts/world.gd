class_name World
extends Node3D
## Terrain (procedural heightfield with a river), vegetation, grid-based
## building placement, and the placement ghost / selection marker.

const SEA_LEVEL: float = -0.6

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var occupied: Dictionary = {}   # Vector2i -> building Node3D
var blocked: Dictionary = {}    # Vector2i -> true (trees, rocks)
var building_root := Node3D.new()

var _ghost := Node3D.new()
var _ghost_model: Node3D = null
var _ghost_id: String = ""
var _footprint := MeshInstance3D.new()
var _foot_mat := StandardMaterial3D.new()
var _marker := MeshInstance3D.new()

func _ready() -> void:
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	detail.seed = 99
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 0.09
	add_child(building_root)
	_build_terrain()
	_build_water()
	_scatter()
	_build_ghost()

# ---- terrain -------------------------------------------------------------
func height_at(x: float, z: float) -> float:
	var h: float = noise.get_noise_2d(x, z) * 5.0
	var d: float = Vector2(x, z).length()
	h *= smoothstep(16.0, 36.0, d)
	var river_x: float = 34.0 + 5.0 * sin(z * 0.07)
	var rd: float = clampf(1.0 - absf(x - river_x) / 6.0, 0.0, 1.0)
	h -= rd * rd * 4.2
	return h

func _terrain_color(x: float, z: float, h: float) -> Color:
	var n: float = detail.get_noise_2d(x, z) * 0.5 + 0.5
	var c: Color = Color(0.30, 0.46, 0.17).lerp(Color(0.46, 0.56, 0.24), n)
	var dx: float = height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz: float = height_at(x, z + 1.0) - height_at(x, z - 1.0)
	var slope: float = sqrt(dx * dx + dz * dz) * 0.5
	c = c.lerp(Color(0.45, 0.41, 0.34), clampf((slope - 0.3) * 3.0, 0.0, 1.0))
	if h < SEA_LEVEL + 0.6:
		c = c.lerp(Color(0.62, 0.55, 0.38), clampf((SEA_LEVEL + 0.6 - h) / 0.6, 0.0, 1.0))
	var d: float = Vector2(x, z).length()
	c = c.lerp(Color(0.50, 0.42, 0.28), (1.0 - smoothstep(9.0, 17.0, d)) * 0.55)
	return c

func _build_terrain() -> void:
	var half: float = Defs.GRID * Defs.CELL * 0.5
	var n: int = int(half * 2.0) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x: float = -half + float(i)
			var z: float = -half + float(j)
			var h: float = height_at(x, z)
			st.set_color(_terrain_color(x, z, h))
			st.add_vertex(Vector3(x, h, z))
	for j in n - 1:
		for i in n - 1:
			var a: int = j * n + i
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)
	# dark underlay so the map edge does not show the sky
	var under := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	under.mesh = pm
	under.position.y = -4.5
	var um := StandardMaterial3D.new()
	um.albedo_color = Color(0.18, 0.2, 0.12)
	under.material_override = um
	add_child(under)

func _build_water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Defs.GRID * Defs.CELL + 8.0, Defs.GRID * Defs.CELL + 8.0)
	mi.mesh = pm
	mi.position.y = SEA_LEVEL
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.38, 0.55, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _multi(mesh: Mesh, xf: Array[Transform3D], cols: Array[Color]) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)

func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var trunks: Array[Transform3D] = []
	var trunk_cols: Array[Color] = []
	var cones: Array[Transform3D] = []
	var cone_cols: Array[Color] = []
	var domes: Array[Transform3D] = []
	var dome_cols: Array[Color] = []
	var tries: int = 0
	while trunks.size() < 420 and tries < 5000:
		tries += 1
		var x: float = rng.randf_range(-46.0, 46.0)
		var z: float = rng.randf_range(-46.0, 46.0)
		if Vector2(x, z).length() < 15.0:
			continue
		var h: float = height_at(x, z)
		if h < SEA_LEVEL + 0.5 or h > 6.0:
			continue
		if detail.get_noise_2d(x * 1.7, z * 1.7) < -0.2:
			continue
		var cell := Vector2i(int(floor(x / Defs.CELL + Defs.GRID * 0.5)), int(floor(z / Defs.CELL + Defs.GRID * 0.5)))
		blocked[cell] = true
		var s: float = rng.randf_range(0.8, 1.5)
		var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		trunks.append(Transform3D(bs, Vector3(x, h + 0.7 * s, z)))
		trunk_cols.append(Color(0.33, 0.22, 0.12))
		if rng.randf() < 0.55:
			cones.append(Transform3D(bs, Vector3(x, h + 2.6 * s, z)))
			cone_cols.append(Color(0.12, 0.30, 0.14).lerp(Color(0.2, 0.4, 0.18), rng.randf()))
		else:
			domes.append(Transform3D(bs, Vector3(x, h + 2.2 * s, z)))
			dome_cols.append(Color(0.25, 0.42, 0.16).lerp(Color(0.55, 0.5, 0.18), rng.randf() * rng.randf()))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 1.4
	trunk.radial_segments = 6
	trunk.rings = 1
	_multi(trunk, trunks, trunk_cols)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.3
	cone.height = 3.2
	cone.radial_segments = 7
	cone.rings = 1
	_multi(cone, cones, cone_cols)
	var dome := SphereMesh.new()
	dome.radius = 1.3
	dome.height = 2.4
	dome.radial_segments = 8
	dome.rings = 4
	_multi(dome, domes, dome_cols)

	# rocks
	var rocks: Array[Transform3D] = []
	var rock_cols: Array[Color] = []
	var r_tries: int = 0
	while rocks.size() < 45 and r_tries < 1500:
		r_tries += 1
		var x: float = rng.randf_range(-46.0, 46.0)
		var z: float = rng.randf_range(-46.0, 46.0)
		if Vector2(x, z).length() < 14.0:
			continue
		var h: float = height_at(x, z)
		if h < SEA_LEVEL + 0.5:
			continue
		var cell := Vector2i(int(floor(x / Defs.CELL + Defs.GRID * 0.5)), int(floor(z / Defs.CELL + Defs.GRID * 0.5)))
		if blocked.has(cell):
			continue
		blocked[cell] = true
		var sc := Vector3(rng.randf_range(0.7, 1.6), rng.randf_range(0.5, 1.0), rng.randf_range(0.7, 1.4))
		var rb := Basis(Vector3.UP, rng.randf() * TAU).scaled(sc)
		rocks.append(Transform3D(rb, Vector3(x, h + 0.3, z)))
		rock_cols.append(Color(0.45, 0.44, 0.41).lerp(Color(0.6, 0.58, 0.54), rng.randf()))
	var rock := SphereMesh.new()
	rock.radius = 0.8
	rock.height = 1.2
	rock.radial_segments = 6
	rock.rings = 3
	_multi(rock, rocks, rock_cols)

# ---- grid helpers ----------------------------------------------------------
func cell_center(cell: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) + float(size.x) * 0.5 - Defs.GRID * 0.5) * Defs.CELL, 0.0,
		(float(cell.y) + float(size.y) * 0.5 - Defs.GRID * 0.5) * Defs.CELL)

func point_to_cell(p: Vector3, size: Vector2i) -> Vector2i:
	var fx: float = p.x / Defs.CELL + Defs.GRID * 0.5 - float(size.x) * 0.5
	var fz: float = p.z / Defs.CELL + Defs.GRID * 0.5 - float(size.y) * 0.5
	return Vector2i(int(floor(fx + 0.5)), int(floor(fz + 0.5)))

func _samples(cell: Vector2i, size: Vector2i) -> Array:
	var c: Vector3 = cell_center(cell, size)
	var hx: float = float(size.x) * Defs.CELL * 0.5
	var hz: float = float(size.y) * Defs.CELL * 0.5
	var out: Array = []
	for ox in [-hx, 0.0, hx]:
		for oz in [-hz, 0.0, hz]:
			out.append(height_at(c.x + ox, c.z + oz))
	return out

func ground_avg(cell: Vector2i, size: Vector2i) -> float:
	var total: float = 0.0
	var s: Array = _samples(cell, size)
	for v in s:
		total += float(v)
	return total / float(s.size())

func footprint_ok(cell: Vector2i, size: Vector2i) -> bool:
	for dx in size.x:
		for dy in size.y:
			var c := Vector2i(cell.x + dx, cell.y + dy)
			if c.x < 0 or c.y < 0 or c.x >= Defs.GRID or c.y >= Defs.GRID:
				return false
			if occupied.has(c) or blocked.has(c):
				return false
	var hs: Array = _samples(cell, size)
	var lo: float = hs.min()
	var hi: float = hs.max()
	if lo < SEA_LEVEL + 0.25:
		return false
	return hi - lo <= 1.6

func ground_ray(origin: Vector3, dir: Vector3) -> Variant:
	if dir.y >= -0.001:
		return null
	var t: float = 0.0
	var start_y: float = 8.0
	if origin.y > start_y:
		t = (origin.y - start_y) / -dir.y
	var prev: float = t
	for i in 400:
		var p: Vector3 = origin + dir * t
		if p.y <= height_at(p.x, p.z):
			var lo: float = prev
			var hi: float = t
			for k in 8:
				var mid: float = (lo + hi) * 0.5
				var q: Vector3 = origin + dir * mid
				if q.y <= height_at(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var r: Vector3 = origin + dir * hi
			var lim: float = Defs.GRID * Defs.CELL * 0.5
			if absf(r.x) > lim or absf(r.z) > lim:
				return null
			return r
		prev = t
		t += 0.5
	return null

# ---- buildings -------------------------------------------------------------
func place(id: String, cell: Vector2i) -> Node3D:
	var def: Dictionary = Defs.BUILDINGS[id]
	var size: Vector2i = def["size"]
	var node := BuildingFactory.create(id)
	var base_h: float = ground_avg(cell, size) + 0.12
	var c: Vector3 = cell_center(cell, size)
	c.y = base_h
	node.position = c
	node.set_meta("id", id)
	node.set_meta("cell", cell)
	# stone plinth reaching down to the lowest terrain point under the footprint
	var s: Array = _samples(cell, size)
	var depth: float = base_h - float(s.min()) + 0.25
	var plinth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(size.x) * Defs.CELL + 0.2, depth, float(size.y) * Defs.CELL + 0.2)
	plinth.mesh = bm
	plinth.position = Vector3(0, -depth * 0.5, 0)
	plinth.material_override = BuildingFactory._mat(BuildingFactory.STONE_D)
	node.add_child(plinth)
	building_root.add_child(node)
	for dx in size.x:
		for dy in size.y:
			occupied[Vector2i(cell.x + dx, cell.y + dy)] = node
	return node

func remove_building(node: Node3D) -> void:
	var cell: Vector2i = node.get_meta("cell")
	var def: Dictionary = Defs.BUILDINGS[node.get_meta("id")]
	var size: Vector2i = def["size"]
	for dx in size.x:
		for dy in size.y:
			occupied.erase(Vector2i(cell.x + dx, cell.y + dy))
	node.queue_free()

func clear_buildings() -> void:
	for ch in building_root.get_children():
		ch.queue_free()
	occupied.clear()

# ---- ghost & marker -------------------------------------------------------
func _build_ghost() -> void:
	add_child(_ghost)
	_ghost.visible = false
	_foot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_footprint.material_override = _foot_mat
	_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_footprint)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.3, 0.6, 1.0, 0.45)
	_marker.material_override = mm
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)

func set_ghost(id: String, cell: Vector2i, valid: bool) -> void:
	var def: Dictionary = Defs.BUILDINGS[id]
	var size: Vector2i = def["size"]
	if id != _ghost_id:
		if is_instance_valid(_ghost_model):
			_ghost_model.queue_free()
		_ghost_model = BuildingFactory.create(id)
		_ghost.add_child(_ghost_model)
		_ghost_id = id
		var box := BoxMesh.new()
		box.size = Vector3(float(size.x) * Defs.CELL, 0.2, float(size.y) * Defs.CELL)
		_footprint.mesh = box
	var c: Vector3 = cell_center(cell, size)
	c.y = ground_avg(cell, size) + 0.12
	_ghost.position = c
	_footprint.position = Vector3(0, 0.08, 0)
	_foot_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.45) if valid else Color(0.95, 0.2, 0.2, 0.5)
	_ghost.visible = true

func clear_ghost() -> void:
	_ghost.visible = false
	_ghost_id = ""
	if is_instance_valid(_ghost_model):
		_ghost_model.queue_free()
		_ghost_model = null

func show_marker(node: Node3D) -> void:
	var def: Dictionary = Defs.BUILDINGS[node.get_meta("id")]
	var size: Vector2i = def["size"]
	var box := BoxMesh.new()
	box.size = Vector3(float(size.x) * Defs.CELL + 0.4, 0.2, float(size.y) * Defs.CELL + 0.4)
	_marker.mesh = box
	_marker.position = node.position + Vector3(0, 0.1, 0)
	_marker.visible = true

func hide_marker() -> void:
	_marker.visible = false
