@tool
extends Control
## The level editor's layer dock. The main control is an HSlider: one tick
## per layer `EeriLayerRail` reports. Moving it does not repaint the GridMap.
## The editor plugin reads `selected_index()` when a marker prefab is dropped
## and puts that marker on the layer.

var _slider: HSlider
var _readout: Label


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if _slider != null:
		return
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)

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
	_readout.text = "%s    z = %s\nA marker dropped into this scene snaps here (x/y on the half-tile grid). Dragging one later snaps x/y and leaves its layer alone." % [layer["name"], z_text]
