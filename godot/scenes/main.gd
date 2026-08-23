extends Node2D
## The whole of the Godot skeleton's gameplay: none.
##
## This proves the project boots, the display config reflows, and the
## AssetRegistry seam reads real manifest data — nothing about run/jump/
## stomp/climb, rooms, or any art. See EERI_GODOT_HANDOFF.md before adding
## any of that.

@onready var _status: Label = $UI/Status


func _ready() -> void:
	var lines := [
		"EERI — Godot port skeleton",
		"",
		"No gameplay ported yet. Read EERI_GODOT_HANDOFF.md before building here.",
		"",
		AssetRegistry.summary(),
	]
	_status.text = "\n".join(lines)
