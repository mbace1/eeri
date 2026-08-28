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
	var lang: String = OS.get_environment("EERI_SHOT_LANG")
	if lang != "":
		Loc.set_language(lang)
	var want: String = OS.get_environment("EERI_SHOT_LEVEL")
	if want != "":
		play.start_slug = want
	add_child(play)
	# walk past the title, the same way --skip does for a player — unless the
	# title is the thing being photographed
	if OS.get_environment("EERI_SHOT_TITLE") == "":
		if play.has_method("_begin"):
			play._begin()
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
		elif drive == "climb":
			var lad = play.level.ladders[0] if play.level.ladders.size() > 0 else null
			if lad != null:
				k.x = float(lad.get("c",0)) + 0.5
				k.y = float(lad.get("cy0",0)) + 0.5
			for i in 90:
				k.step(DT, {"up_held": true})
				play._diorama.step_fore(DT, k.climbing)
		elif drive == "at":
			# stand him at a given x so a specific prop can be photographed
			k.x = float(OS.get_environment("EERI_SHOT_AT"))
			k.y = play.level.ground_top(k.x, 10.0)
			for i in 30:
				k.step(DT, {})
				play.run.step(k.x, k.y)
			play._step_robots(DT)
		elif drive == "wary":
			# park near the machine WITHOUT boarding it -- step _step_ride()
			# directly so the untamed work() cycle runs, same as _process()
			# would, and stop partway through so the bucket is visibly down.
			k.x = play.machine.x - 2.0
			k.y = play.machine.y
			for i in 40:
				k.step(DT, {})
				play._step_ride(DT, {})
				if play.machine.swinging():
					break
		elif drive == "mount":
			# park him at whatever machine this room has and board it
			k.x = play.machine.x - 2.0
			k.y = play.machine.y
			for i in 20: k.step(DT, {})
			play._step_ride(DT, {"ax": 0.0, "action_pressed": true})
			for i in 120: play._step_ride(DT, {"ax": 0.0})
		elif drive == "ride":
			# Put him beside the parked machine and board it. Walking there is
			# a pathfinding problem, not the thing under test — the harness
			# should show the RIDE.
			k.x = play.machine.x - 2.0
			k.y = play.machine.y
			for i in 20:
				k.step(DT, {})
			play._step_ride(DT, {"ax": 0.0, "action_pressed": true})
			for i in 200:
				play._step_ride(DT, {"ax": 1.0})
				if play.mode == "riding" and i > 40:
					break
		elif drive == "bolts":
			# run right along the bolt trail, jumping anything that blocks
			for i in 1200:
				var stuck: bool = k.grounded and absf(k.vx) < 0.4 and i > 30
				k.step(DT, {"ax": 1.0, "jump_pressed": stuck, "jump_held": true})
				play.run.step(k.x, k.y)
				if play.run.bolts_got >= 12: break
		elif drive == "gate":
			# THE GATE ITSELF, not the whole level's traversal to reach it --
			# the naive run+jump driver above cannot solve every authored
			# level (1-3 wants a machine over a wall), and that is a fact
			# about the harness, not about _step_gate(). So this drive parks
			# the kid at the gate directly and forces the flag up, the same
			# shortcut EERI_SHOT_AT already takes for a specific prop.
			# THE WALL IS PART OF EVERY WORLD-ENDING LEVEL (the crane clears it
			# on the way to the gate in real play), so an honest gate shot
			# clears it first the same way machine.gd's own strike does --
			# otherwise the frame is the uncleared wall's own red rubble
			# state, not the building.
			if play.wall != null:
				for r in play.wall.rows:
					play.level.clear_row(int(play.wall.c0), int(play.wall.c1), int(play.wall.cy0) + r)
				play.wall.cleared = true
				play._build_tiles()
			var gx: float = float(play.level.gate.get("x", 0)) + 1.0
			k.x = gx
			k.y = play.level.ground_top(gx, 10.0)
			play.run.flag_phase = 3
			play.run.flag_raised = true
			if OS.get_environment("EERI_SHOT_GOT9") != "":
				GameState.world_golden = 9   # force the finished roof+lamp path
			for i in 30:
				k.step(DT, {})
				play.run.step(k.x, k.y)
				play._step_gate(DT)
				if play._cleared:
					break
			# The generic epilogue below calls _place_camera(true), which snaps
			# to the KID, not to cam.cut()'s target -- correct for ordinary
			# shots, but it means this diagnostic has to put the kid where the
			# building actually is to see it, rather than trusting the cut.
			if play._building_node != null:
				k.x = play._building_node.position.x + 40.0   # step clear of it
				k.y = play._building_node.position.y
		elif drive == "dig":
			# park at the bank, board, and hold the verb until a row is gone
			k.x = play.machine.x - 2.0
			k.y = play.machine.y
			for i in 20: k.step(DT, {})
			play._step_ride(DT, {"ax": 0.0, "action_pressed": true})
			for i in 60: play._step_ride(DT, {"ax": 0.0})
			# drive to the bank
			for i in 1200:
				play._step_ride(DT, {"ax": 1.0})
				play._step_bank(DT, {"down_held": false})
				if play.bank.in_reach(play.machine.x): break
			# then dig, stopping mid-stroke so the arm is visibly working
			var rows0: int = play.bank.remaining
			for i in 400:
				play._step_ride(DT, {"ax": 0.0})
				play._step_bank(DT, {"down_held": true})
				if play.bank.remaining < rows0 and play.bank.bucket < -1.0: break
		elif drive == "stomp":
			# run at the first hopper (level 1-1 puts one across x 15..21) and
			# come down on it, stepping the robots on the same clock
			var tgt := {}
			for i in 900:
				var jump: bool = k.grounded and absf(k.x - play.robots[0].x) < 2.6
				k.step(DT, {"ax": 1.0, "jump_pressed": jump, "jump_held": true})
				play._step_robots(DT)
				if play.stomps > 0:
					play._robot_nodes[0].visible = true   # show what was hit
					break
		play._update_hint()   # _process is off during a driven shot; call by hand
		play._sync_visual()
		play._sync_robots()
		play._sync_machine()
		play._sync_bank()
		play._sync_arm()
		play._sync_pickups()
		play._place_camera(true)
		for i in 4:
			await get_tree().process_frame

	if OS.get_environment("EERI_SHOT_PAUSE") != "":
		play._shell.set_paused(true)
		for i in 4:
			await get_tree().process_frame
	if OS.get_environment("EERI_SHOT_GOLDEN") != "":
		play._shell.banner_golden(1, 3)
		for i in 4:
			await get_tree().process_frame
	if OS.get_environment("EERI_SHOT_CLOCKOUT") != "":
		play._shell.clock_out("the tower", 7, 9, 137, 4)
		for i in 4:
			await get_tree().process_frame

	var p: String = OS.get_environment("EERI_SHOT")
	if p == "": p = "res://tools/_shot.png"
	get_viewport().get_texture().get_image().save_png(p)
	print("wrote ", p)
	get_tree().quit(0)
