extends Node
## Playing a draft leaves the editor scene/selection intact. GameState lives
## only in this preview process, and the preview has no campaign next-level.
func _ready() -> void:
	var play := (load("res://scenes/play.tscn") as PackedScene).instantiate()
	play.start_slug = "eeri-editor-preview"
	add_child(play)
	play._roster = [{"slug": play.start_slug, "index": 0}]
	play._index = 0
	play._begin()
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/eeri-editor-preview.json"))
	if bool(raw.get("preview_checkpoint", false)) and play.level.checkpoint != null:
		play.kid.x = float(play.level.checkpoint["x"])
		play.kid.y = float(play.level.checkpoint["y"])
