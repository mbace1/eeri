@tool
extends VBoxContainer
## The level editor's layer dock. The main control is an HSlider: one tick
## per layer `EeriLayerRail` reports. Moving it does not repaint the GridMap.
## The editor plugin reads `selected_index()` when a marker prefab is dropped
## and puts that marker on the layer.

var _slider: HSlider
var _readout: Label
var _plugin: EditorPlugin
var _levels: OptionButton
var _status: Label
var _filter: LineEdit
var _palette: ItemList
var _catalog: Array = []
var _from_checkpoint: CheckButton


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if _slider != null:
		return
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	var heading := Label.new()
	heading.text = "Eeri level editor"
	box.add_child(heading)
	_levels = OptionButton.new()
	_levels.fit_to_longest_item = false
	_levels.name = "LevelPicker"
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level in LevelData.load_index().get("levels", []):
		_levels.add_item(String(level["name"]))
		_levels.set_item_metadata(_levels.item_count - 1, String(level["slug"]))
	box.add_child(_levels)
	var open_row := HBoxContainer.new()
	box.add_child(open_row)
	_button(open_row, "Open level", "open_level")
	_button(open_row, "New", "new_level")
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "Save", "save_level")
	_button(actions, "Check", "validate_level")
	_button(actions, "Play", "play_level")
	var apply := Button.new()
	apply.text = "Apply world art…"
	apply.tooltip_text = "Review and apply shared art placements to all three levels in this world. Gameplay edits remain in your draft."
	apply.pressed.connect(func():
		if _plugin != null: _plugin.call("review_world_art"))
	box.add_child(apply)
	_from_checkpoint = CheckButton.new()
	_from_checkpoint.text = "Start at checkpoint"
	box.add_child(_from_checkpoint)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Open a level or start a new draft."
	box.add_child(_status)

	var title := Label.new()
	title.text = "Layer"
	box.add_child(title)

	_slider = HSlider.new()
	_slider.name = "LayerSlider"
	_slider.min_value = 0
	_slider.max_value = maxi(0, EeriLayerRail.layer_count() - 1)
	_slider.step = 1
	_slider.tick_count = maxi(1, EeriLayerRail.layer_count())
	_slider.ticks_on_borders = true
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.custom_minimum_size = Vector2(0, 28)
	_slider.value_changed.connect(_on_value)
	box.add_child(_slider)

	_readout = Label.new()
	_readout.name = "Readout"
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readout)

	# Gameplay markers live on PLAY (z = 0). Start there so a drop before
	# anyone touches the slider stays on the plane the exporter already reads.
	_slider.set_value_no_signal(EeriLayerRail.index_of("PLAY"))
	_on_value(_slider.value)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Find a piece…"
	_filter.text_changed.connect(func(_text): _fill_palette())
	box.add_child(_filter)
	_palette = ItemList.new()
	_palette.name = "Pieces"
	_palette.fixed_icon_size = Vector2i(44, 44)
	_palette.icon_mode = ItemList.ICON_MODE_LEFT
	_palette.custom_minimum_size = Vector2(0, 190)
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.item_activated.connect(func(index): _add_selected(index))
	box.add_child(_palette)
	var add := Button.new()
	add.text = "Add selected piece"
	add.pressed.connect(func():
		var selected := _palette.get_selected_items()
		if not selected.is_empty(): _add_selected(selected[0]))
	box.add_child(add)
	_build_catalog()
	_fill_palette()


func configure(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_ensure()


func _button(parent: Control, text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func():
		if _plugin == null: return
		if action == "open_level":
			if _levels.selected >= 0: _plugin.call(action, _levels.get_item_metadata(_levels.selected))
		elif action == "play_level":
			_plugin.call(action, _from_checkpoint.button_pressed)
		else: _plugin.call(action))
	parent.add_child(button)


func show_status(text: String, problem := false) -> void:
	_ensure()
	_status.text = text
	_status.modulate = Color(1, 0.65, 0.5) if problem else Color.WHITE


func set_current(root: Node) -> void:
	if root == null or not root.has_meta("eeri_slug"):
		show_status("Open a level or start a new draft.")
		return
	var slug := String(root.get_meta("eeri_slug"))
	for i in _levels.item_count:
		if _levels.get_item_metadata(i) == slug:
			_levels.select(i)
	show_status("%s\nSaved drafts stay in the authored folder. Play previews your current edits." % root.get_meta("eeri_name", slug))


func _build_catalog() -> void:
	var data := SceneryData.load_data()
	for key in data.art:
		var spec: Dictionary = data.art[key]
		var texture_path := "res://data/" + String(spec["file"])
		_catalog.append({"label": String(spec.get("label", key)), "art": key,
			"icon": load(texture_path) if ResourceLoader.exists(texture_path) else null})
	for file in DirAccess.get_files_at("res://leveleditor/markers"):
		if not file.ends_with(".tscn"): continue
		var path := "res://leveleditor/markers/" + file
		var marker := (load(path) as PackedScene).instantiate()
		if not marker is EeriArtCutout:
			_catalog.append({"label": file.trim_prefix("eeri_").trim_suffix(".tscn").capitalize(), "scene": path})
		marker.free()
	_catalog.sort_custom(func(a, b): return a["label"] < b["label"])


func _fill_palette() -> void:
	if _palette == null: return
	_palette.clear()
	var query := _filter.text.to_lower()
	for entry in _catalog:
		if query != "" and not String(entry["label"]).to_lower().contains(query): continue
		_palette.add_item(String(entry["label"]), entry.get("icon"))
		_palette.set_item_metadata(_palette.item_count - 1, entry)


func _add_selected(index: int) -> void:
	if _plugin != null:
		_plugin.call("add_piece", _palette.get_item_metadata(index))


func selected_index() -> int:
	_ensure()
	return int(_slider.value)


func selected_layer_name() -> String:
	return String(EeriLayerRail.layer_at(selected_index())["name"])


func set_layer_index(index: int) -> void:
	_ensure()
	_slider.value = index


func _on_value(value: float) -> void:
	var layer := EeriLayerRail.layer_at(int(value))
	var z := float(layer["z"])
	var z_text := str(int(round(z))) if is_equal_approx(z, round(z)) else str(z)
	_readout.text = "%s    depth %s\nPlacement snaps to ½ tile." % [layer["name"], z_text]
	_readout.tooltip_text = "Choose a layer for new art. Moving an existing piece keeps its layer."
