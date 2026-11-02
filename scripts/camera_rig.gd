class_name CameraRig
extends Node3D
## Angled strategy camera.
## Touch: 1 finger drag = pan, 2 fingers = pinch zoom + twist rotate, tap = select/place.
## Mouse: left drag = pan, wheel = zoom, right/middle drag = rotate/tilt, click = tap.
## Keyboard: WASD/arrows pan, Q/E rotate.

signal tapped(screen_pos: Vector2)
signal hovered(screen_pos: Vector2)

var yaw: float = 35.0
var pitch: float = 52.0
var dist: float = 34.0
var bounds: float = 44.0
var ui_blocker: Callable = Callable()
var camera: Camera3D

var _pivot: Node3D
var _dist_target: float = 34.0
var _touches: Dictionary = {}
var _ignored: Dictionary = {}
var _tap_start: Vector2 = Vector2.ZERO
var _tap_valid: bool = false
var _pinch_dist: float = 0.0
var _pinch_angle: float = 0.0
var _mouse_left: bool = false
var _mouse_moved: bool = false

func _ready() -> void:
    _pivot = Node3D.new()
    add_child(_pivot)
    camera = Camera3D.new()
    camera.far = 400.0
    camera.near = 0.5
    camera.fov = 55.0
    _pivot.add_child(camera)
    camera.current = true
    _apply()

func focus_on(p: Vector3) -> void:
    position = Vector3(p.x, 0.0, p.z)

func _blocked(pos: Vector2) -> bool:
    return ui_blocker.is_valid() and bool(ui_blocker.call(pos))

func _apply() -> void:
    position.x = clampf(position.x, -bounds, bounds)
    position.z = clampf(position.z, -bounds, bounds)
    rotation_degrees.y = yaw
    _pivot.rotation_degrees.x = -pitch
    camera.position = Vector3(0, 0, dist)

func _pan(rel: Vector2) -> void:
    var s: float = dist * 0.0022
    var fwd: Vector3 = -global_transform.basis.z
    var right: Vector3 = global_transform.basis.x
    var vscale: float = 1.0 / maxf(sin(deg_to_rad(pitch)), 0.35)
    position += right * (-rel.x * s) + fwd * (rel.y * s * vscale)

func _process(delta: float) -> void:
    var mv := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        mv.y += 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        mv.y -= 1.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        mv.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        mv.x += 1.0
    if mv != Vector2.ZERO:
        var spd: float = dist * 0.9 * delta
        position += (global_transform.basis.x * mv.x + (-global_transform.basis.z) * mv.y) * spd
    if Input.is_physical_key_pressed(KEY_Q):
        yaw += 70.0 * delta
    if Input.is_physical_key_pressed(KEY_E):
        yaw -= 70.0 * delta
    dist = lerpf(dist, _dist_target, 1.0 - exp(-10.0 * delta))
    _apply()

func _init_pinch() -> void:
    var keys: Array = _touches.keys()
    if keys.size() < 2:
        return
    var a: Vector2 = _touches[keys[0]]
    var b: Vector2 = _touches[keys[1]]
    _pinch_dist = a.distance_to(b)
    _pinch_angle = (b - a).angle()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _on_touch(event as InputEventScreenTouch)
    elif event is InputEventScreenDrag:
        _on_drag(event as InputEventScreenDrag)
    elif event is InputEventMouseButton:
        _on_mouse_button(event as InputEventMouseButton)
    elif event is InputEventMouseMotion:
        _on_mouse_motion(event as InputEventMouseMotion)

func _on_touch(t: InputEventScreenTouch) -> void:
    if t.pressed:
        if _blocked(t.position):
            _ignored[t.index] = true
            return
        _touches[t.index] = t.position
        if _touches.size() == 1:
            _tap_start = t.position
            _tap_valid = true
        else:
            _tap_valid = false
            _init_pinch()
    else:
        if _ignored.erase(t.index):
            return
        if _touches.has(t.index):
            if _touches.size() == 1 and _tap_valid:
                tapped.emit(t.position)
            _touches.erase(t.index)
            _tap_valid = false

func _on_drag(d: InputEventScreenDrag) -> void:
    if _ignored.has(d.index) or not _touches.has(d.index):
        return
    _touches[d.index] = d.position
    if _touches.size() == 1:
        if _tap_valid and d.position.distance_to(_tap_start) > 16.0:
            _tap_valid = false
        if not _tap_valid:
            _pan(d.relative)
    else:
        var keys: Array = _touches.keys()
        var a: Vector2 = _touches[keys[0]]
        var b: Vector2 = _touches[keys[1]]
        var nd: float = a.distance_to(b)
        var na: float = (b - a).angle()
        if _pinch_dist > 1.0 and nd > 1.0:
            _dist_target = clampf(_dist_target * _pinch_dist / nd, 12.0, 85.0)
        yaw += rad_to_deg(angle_difference(_pinch_angle, na))
        _pinch_dist = nd
        _pinch_angle = na
        _pan(d.relative * 0.5)

func _on_mouse_button(mb: InputEventMouseButton) -> void:
    if mb.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if mb.button_index == MOUSE_BUTTON_LEFT:
        if mb.pressed:
            if _blocked(mb.position):
                _mouse_left = false
                return
            _mouse_left = true
            _mouse_moved = false
            _tap_start = mb.position
        else:
            if _mouse_left and not _mouse_moved:
                tapped.emit(mb.position)
            _mouse_left = false
    elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
        _dist_target = clampf(_dist_target * 0.9, 12.0, 85.0)
    elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        _dist_target = clampf(_dist_target * 1.1, 12.0, 85.0)

func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
    if mm.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if _mouse_left:
        if not _mouse_moved and mm.position.distance_to(_tap_start) > 8.0:
            _mouse_moved = true
        if _mouse_moved:
            _pan(mm.relative)
    elif (mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
        yaw -= mm.relative.x * 0.3
        pitch = clampf(pitch + mm.relative.y * 0.2, 30.0, 75.0)
    elif not _blocked(mm.position):
        hovered.emit(mm.position)
