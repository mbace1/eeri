extends Node
## Screenshot harness. A gate certifies WORKS and cannot see LOOKS — this
## project's standing lesson — so a scene or art change ends in a picture.
##
## EERI_SHOT       where to write
## EERI_SHOT_DRIVE "run" or "jump": drive the ported body directly, with
##                 process paused, so the frame shows a real gameplay pose
##                 rather than an idle stand.
const DT := 1.0 / 60.0

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/play.tscn")
	var play: Node = packed.instantiate()
	add_child(play)
	for i in 30:
		await get_tree().process_frame

	var drive: String = OS.get_environment("EERI_SHOT_DRIVE")
	if drive != "":
		play.set_process(false)          # own the clock, don't fight _process
		var k = play.kid
		for i in 70:                      # up to full run speed
			k.step(DT, {"ax": 1.0})
		if drive == "jump":
			k.step(DT, {"ax": 1.0, "jump_pressed": true, "jump_held": true})
			for i in 14:
				k.step(DT, {"ax": 1.0, "jump_held": true})
		play._sync_visual()
		play._place_camera(true)
		for i in 4:
			await get_tree().process_frame

	var p: String = OS.get_environment("EERI_SHOT")
	if p == "": p = "res://tools/_shot.png"
	get_viewport().get_texture().get_image().save_png(p)
	print("wrote ", p)
	get_tree().quit(0)
