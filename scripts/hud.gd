class_name Hud
extends CanvasLayer
## Touch-friendly HUD built entirely in code: resource bar, build bar,
## placement confirm bar, kingdom (policy) panel, building info panel, toasts.

signal build_selected(id: String)
signal build_confirmed
signal build_cancelled
signal demolish_pressed
signal save_pressed
signal load_pressed

var eco: Economy
var root: Control
var _res_labels: Dictionary = {}
var _build_buttons: Dictionary = {}
var _blockers: Array[Control] = []
var _place_bar: PanelContainer
var _place_label: Label
var _confirm_btn: Button
var _kingdom: PanelContainer
var _info: PanelContainer
var _info_label: Label
var _demolish_btn: Button
var _tax_label: Label
var _ration_label: Label
var _status_label: Label
var _speed_btns: Array[Button] = []
var _toast: Label
var _toasts: Array = []

func setup(economy: Economy) -> void:
    eco = economy
    layer = 10
    root = Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.theme = _make_theme()
    add_child(root)
    _build_top()
    _build_bottom()
    _build_place_bar()
    _build_kingdom()
    _build_info()
    _build_toast()
    eco.changed.connect(refresh)
    eco.message.connect(toast)
    refresh()

func is_over_ui(pos: Vector2) -> bool:
    for c in _blockers:
        if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
            return true
    return false

# ---- construction ---------------------------------------------------------
func _flat(bg: Color, border: Color, bw: int = 2, r: int = 8) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(r)
    s.set_content_margin_all(10)
    return s

func _make_theme() -> Theme:
    var t := Theme.new()
    t.default_font_size = 24
    var gold := Color(0.78, 0.62, 0.26)
    t.set_stylebox("panel", "PanelContainer", _flat(Color(0.11, 0.08, 0.05, 0.9), gold))
    t.set_stylebox("normal", "Button", _flat(Color(0.30, 0.20, 0.10), gold))
    t.set_stylebox("hover", "Button", _flat(Color(0.40, 0.28, 0.14), gold))
    t.set_stylebox("pressed", "Button", _flat(Color(0.20, 0.13, 0.07), gold))
    t.set_stylebox("disabled", "Button", _flat(Color(0.18, 0.16, 0.14), Color(0.35, 0.32, 0.28)))
    t.set_color("font_color", "Button", Color(0.98, 0.92, 0.75))
    t.set_color("font_hover_color", "Button", Color(1, 1, 0.85))
    t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
    t.set_color("font_disabled_color", "Button", Color(0.5, 0.46, 0.42))
    t.set_color("font_color", "Label", Color(0.96, 0.92, 0.82))
    return t

func _btn(text: String, min_size: Vector2 = Vector2(0, 76)) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.focus_mode = Control.FOCUS_NONE
    return b

func _build_top() -> void:
    var p := PanelContainer.new()
    p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    root.add_child(p)
    _blockers.append(p)
    var flow := HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 26)
    p.add_child(flow)
    for k in ["gold", "wood", "stone", "food", "pop", "happy", "day"]:
        var l := Label.new()
        flow.add_child(l)
        _res_labels[k] = l

func _build_bottom() -> void:
    var p := PanelContainer.new()
    p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    p.custom_minimum_size = Vector2(0, 120)
    p.grow_vertical = Control.GROW_DIRECTION_BEGIN
    root.add_child(p)
    _blockers.append(p)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    p.add_child(hb)
    var k := _btn("Kingdom", Vector2(170, 96))
    k.pressed.connect(func() -> void: _kingdom.visible = not _kingdom.visible)
    hb.add_child(k)
    var sc := ScrollContainer.new()
    sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hb.add_child(sc)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    sc.add_child(row)
    for id in Defs.BUILD_ORDER:
        var def: Dictionary = Defs.BUILDINGS[id]
        var b := _btn("%s\n%s" % [def["name"], _cost_text(def["cost"])], Vector2(190, 96))
        b.pressed.connect(func() -> void: build_selected.emit(id))
        row.add_child(b)
        _build_buttons[id] = b

func _cost_text(cost: Dictionary) -> String:
    var abbr := {"gold": "G", "wood": "W", "stone": "S", "food": "F"}
    var parts: PackedStringArray = []
    for k in cost:
        parts.append("%s%d" % [abbr[k], int(cost[k])])
    return " ".join(parts) if parts.size() > 0 else "free"

func _build_place_bar() -> void:
    _place_bar = PanelContainer.new()
    _place_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _place_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _place_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _place_bar.offset_bottom = -132
    _place_bar.visible = false
    root.add_child(_place_bar)
    _blockers.append(_place_bar)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 12)
    _place_bar.add_child(hb)
    _place_label = Label.new()
    _place_label.custom_minimum_size = Vector2(360, 0)
    _place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hb.add_child(_place_label)
    _confirm_btn = _btn("Build", Vector2(150, 72))
    _confirm_btn.pressed.connect(func() -> void: build_confirmed.emit())
    hb.add_child(_confirm_btn)
    var c := _btn("Done", Vector2(130, 72))
    c.pressed.connect(func() -> void: build_cancelled.emit())
    hb.add_child(c)

func _build_kingdom() -> void:
    _kingdom = PanelContainer.new()
    _kingdom.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _kingdom.offset_left = -480
    _kingdom.offset_right = -8
    _kingdom.offset_top = 96
    _kingdom.offset_bottom = 96 + 520
    _kingdom.visible = false
    root.add_child(_kingdom)
    _blockers.append(_kingdom)
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _kingdom.add_child(sc)
    var v := VBoxContainer.new()
    v.custom_minimum_size = Vector2(430, 0)
    v.add_theme_constant_override("separation", 8)
    sc.add_child(v)
    var title := Label.new()
    title.text = "Kingdom Decisions"
    v.add_child(title)
    _tax_label = Label.new()
    _tax_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_tax_label)
    var tr := HBoxContainer.new()
    v.add_child(tr)
    var tm := _btn("Lower taxes", Vector2(0, 64))
    tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tm.pressed.connect(func() -> void: eco.set_tax(eco.tax_level - 1))
    tr.add_child(tm)
    var tp := _btn("Raise taxes", Vector2(0, 64))
    tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tp.pressed.connect(func() -> void: eco.set_tax(eco.tax_level + 1))
    tr.add_child(tp)
    _ration_label = Label.new()
    _ration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_ration_label)
    var rr := HBoxContainer.new()
    v.add_child(rr)
    var rm := _btn("Smaller rations", Vector2(0, 64))
    rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rm.pressed.connect(func() -> void: eco.set_ration(eco.ration_level - 1))
    rr.add_child(rm)
    var rp := _btn("Bigger rations", Vector2(0, 64))
    rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rp.pressed.connect(func() -> void: eco.set_ration(eco.ration_level + 1))
    rr.add_child(rp)
    var rec := _btn("Recruit soldier (G10 W5)", Vector2(0, 64))
    rec.pressed.connect(func() -> void: eco.recruit())
    v.add_child(rec)
    _status_label = Label.new()
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(_status_label)
    var sp := HBoxContainer.new()
    v.add_child(sp)
    var speeds := [["Pause", 0.0], ["1x", 1.0], ["3x", 3.0]]
    for s in speeds:
        var sb := _btn(s[0], Vector2(0, 64))
        sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var val: float = s[1]
        sb.pressed.connect(func() -> void:
            eco.time_scale = val
            refresh())
        sp.add_child(sb)
        _speed_btns.append(sb)
    var fr := HBoxContainer.new()
    v.add_child(fr)
    var sv := _btn("Save", Vector2(0, 64))
    sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sv.pressed.connect(func() -> void: save_pressed.emit())
    fr.add_child(sv)
    var ld := _btn("Load", Vector2(0, 64))
    ld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ld.pressed.connect(func() -> void: load_pressed.emit())
    fr.add_child(ld)
    var close := _btn("Close", Vector2(0, 64))
    close.pressed.connect(func() -> void: _kingdom.visible = false)
    v.add_child(close)

func _build_info() -> void:
    _info = PanelContainer.new()
    _info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _info.offset_left = 8
    _info.offset_top = 96
    _info.offset_right = 440
    _info.visible = false
    root.add_child(_info)
    _blockers.append(_info)
    var v := VBoxContainer.new()
    _info.add_child(v)
    _info_label = Label.new()
    _info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _info_label.custom_minimum_size = Vector2(400, 0)
    v.add_child(_info_label)
    var hb := HBoxContainer.new()
    v.add_child(hb)
    _demolish_btn = _btn("Demolish", Vector2(0, 64))
    _demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _demolish_btn.pressed.connect(func() -> void: demolish_pressed.emit())
    hb.add_child(_demolish_btn)
    var c := _btn("Close", Vector2(0, 64))
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    c.pressed.connect(func() -> void: _info.visible = false)
    hb.add_child(c)

func _build_toast() -> void:
    _toast = Label.new()
    _toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _toast.offset_top = 100
    _toast.custom_minimum_size = Vector2(620, 0)
    _toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast.add_theme_constant_override("outline_size", 8)
    _toast.add_theme_color_override("font_outline_color", Color.BLACK)
    root.add_child(_toast)

# ---- runtime --------------------------------------------------------------
func toast(text: String) -> void:
    _toasts.append({"t": text, "ttl": 7.0})
    if _toasts.size() > 4:
        _toasts.pop_front()
    _render_toast()

func _render_toast() -> void:
    var lines: PackedStringArray = []
    for e in _toasts:
        lines.append(str(e["t"]))
    _toast.text = "\n".join(lines)

func _process(delta: float) -> void:
    if _toasts.is_empty():
        return
    for e in _toasts:
        e["ttl"] = float(e["ttl"]) - delta
    var n: int = _toasts.size()
    _toasts = _toasts.filter(func(e: Dictionary) -> bool: return float(e["ttl"]) > 0.0)
    if _toasts.size() != n:
        _render_toast()

func show_place_bar(on: bool) -> void:
    _place_bar.visible = on

func set_place_status(text: String, ok: bool) -> void:
    _place_label.text = text
    _confirm_btn.disabled = not ok

func show_info(node: Node3D) -> void:
    var id: String = node.get_meta("id")
    var def: Dictionary = Defs.BUILDINGS[id]
    var txt: String = "%s\n%s" % [def["name"], def["desc"]]
    if def.has("produces"):
        txt += "\nStaffing %d%%, mood x%.2f" % [int(eco.worker_efficiency() * 100.0), eco.production_multiplier()]
    _info_label.text = txt
    _demolish_btn.visible = id != "town_center"
    _info.visible = true

func hide_info() -> void:
    _info.visible = false

func _delta_txt(k: String) -> String:
    return "%+d" % int(round(float(eco.last_delta[k])))

func refresh() -> void:
    var r: Dictionary = eco.res
    _res_labels["gold"].text = "Gold %d (%s)" % [int(r["gold"]), _delta_txt("gold")]
    _res_labels["wood"].text = "Wood %d (%s)" % [int(r["wood"]), _delta_txt("wood")]
    _res_labels["stone"].text = "Stone %d (%s)" % [int(r["stone"]), _delta_txt("stone")]
    _res_labels["food"].text = "Food %d (%s)" % [int(r["food"]), _delta_txt("food")]
    _res_labels["pop"].text = "Pop %d/%d  Army %d" % [eco.pop, eco.housing_capacity(), eco.soldiers]
    _res_labels["happy"].text = "Mood %d" % int(eco.happiness)
    _res_labels["day"].text = "Day %d" % eco.day
    var hc := Color(0.5, 0.9, 0.4) if eco.happiness >= 60.0 else (Color(1, 0.8, 0.3) if eco.happiness >= 35.0 else Color(1, 0.4, 0.35))
    _res_labels["happy"].add_theme_color_override("font_color", hc)
    var fc := Color(1, 0.4, 0.35) if float(r["food"]) < 10.0 else Color(0.96, 0.92, 0.82)
    _res_labels["food"].add_theme_color_override("font_color", fc)
    for id in _build_buttons:
        var def: Dictionary = Defs.BUILDINGS[id]
        (_build_buttons[id] as Button).disabled = not eco.can_afford(def["cost"])
    _tax_label.text = "Taxes: %s (%.1f gold per peasant/day, %+d mood)" % [Defs.TAX_NAMES[eco.tax_level], Defs.TAX_COIN[eco.tax_level], int(Defs.TAX_HAP[eco.tax_level])]
    _ration_label.text = "Rations: %s (%.0f%% food use, %+d mood)" % [Defs.RATION_NAMES[eco.ration_level], float(Defs.RATION_MULT[eco.ration_level]) * 100.0, int(Defs.RATION_HAP[eco.ration_level])]
    var raid_in: int = eco.next_raid_day - eco.day
    _status_label.text = "%s\nJobs %d / peasants %d (work rate %d%%)\nDefense %d (soldiers %d/%d, towers %d). Next raid in ~%d days, strength ~%d." % [
        eco.breakdown, eco.jobs(), eco.pop, int(eco.worker_efficiency() * 100.0),
        eco.defense_rating(), eco.soldiers, eco.soldier_capacity(), eco.count("tower"), maxi(raid_in, 0), eco.raid_strength()]
    var speeds := [0.0, 1.0, 3.0]
    for i in _speed_btns.size():
        _speed_btns[i].disabled = is_equal_approx(eco.time_scale, float(speeds[i]))
