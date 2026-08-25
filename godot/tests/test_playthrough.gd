extends Node
## A BOT MUST FINISH EVERY LEVEL.
##
## This is the gate the browser build learned it needed: test/rooms.mjs proves
## a room's GEOMETRY and it passed a level nobody could finish. Proving the
## numbers is not proving the game.
##
## The bot is DELIBERATELY DUMB — no level knowledge, no waypoints, no
## authored route. It knows only: go right; jump when stuck or over a hole;
## climb when a ladder is the thing in the way; and if something is blocking
## that only a machine clears, go and get the machine and hold the verb at it.
## Anything it cannot finish that way is a level a six-year-old cannot either.
##
## It also MEASURES COST, because a tireless bot will eventually beat a level
## a child would put down. Losing the ride means walking back and reading the
## machine again, and more than a couple of those in one room is a hostile
## arrangement even though it is passable.
##
## Runs headless with no scene: it drives the ported bodies directly, the same
## way test_kid does, which is why it can play twelve levels in seconds rather
## than in real time.
##
## Run: godot --headless --path godot res://tests/test_playthrough.tscn

const DT := 1.0 / 60.0
## Generous: a level is 60-90 seconds of real play, and the bot is clumsy.
const BUDGET_STEPS := 60 * 60 * 4
## More than this many lost rides in one room and the arrangement is hostile.
const RIDE_LOSS_LIMIT := 3

var _pass := 0
var _fail := 0


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 300.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("PLAYTHROUGH FAIL: timed out")
		get_tree().quit(1))
	add_child(bail)
	bail.start()

	print("── Eeri — a bot finishes every level ──")
	var levels: Array = LevelData.load_index().get("levels", [])
	check("the whole roster is there", levels.size() == 12, "%d" % levels.size())

	for e in levels:
		var slug := String(e.get("slug", ""))
		var r := _play(slug)
		var name := String(e.get("name", slug))
		check("%s can be finished" % name, r["done"],
			"reached x=%.1f of %d in %.1fs%s" % [r["x"], r["w"], r["t"], r["why"]])
		if r["done"]:
			# COST, not just completion.
			check("…without the ride being taken from him repeatedly",
				r["ride_losses"] <= RIDE_LOSS_LIMIT,
				"%d lost rides" % r["ride_losses"])
	_finish()


## Where the machine is, or somewhere it can never reach if there is none.
func mx_of(m: Machine) -> float:
	return m.x if m != null else -9999.0


## Play one level to its flag. Returns {done, x, w, t, ride_losses, why}.
func _play(slug: String) -> Dictionary:
	var lvl := LevelData.load_slug(slug)
	if lvl == null:
		return {"done": false, "x": 0.0, "w": 0, "t": 0.0, "ride_losses": 0, "why": " — no such level"}

	var k = lvl.spawn.get("kid", {})
	var kid := Kid.new(lvl, float(k.get("x", 4.5)), float(k.get("y", 4)))
	var run := LevelRun.new(lvl)

	# the room's furniture
	var robots: Array[Robot] = []
	for span in lvl.robots:
		robots.append(Robot.new(lvl, span))
	var hoists: Array[Hoist] = []
	for h in lvl.hoists:
		hoists.append(Hoist.new(h))
	kid.platforms = hoists
	var vents: Array[SteamVent] = []
	var vi := 0
	for hz in lvl.hazards:
		if String(hz.get("type", "")) == "steam":
			vents.append(SteamVent.new(lvl, float(hz.get("x", 0)), float(vi) * 0.83))
			vi += 1

	# the machine, and the jobs only it can do
	var mkind := "excavator"
	if lvl.machines.size() > 0:
		mkind = String(lvl.machines[0].get("type", "excavator"))
	var machine: Machine = null
	var mspawn = lvl.spawn.get(mkind, null)
	if mspawn != null:
		machine = Machine.new(lvl, float(mspawn.get("x", 0)), float(mspawn.get("y", 0)), mkind)
	var bank: Bank = Bank.new(lvl, lvl.bank) if lvl.bank != null else null
	var wall: Pieces.Wall = Pieces.Wall.new(lvl.wall) if lvl.wall != null else null
	var girder: Pieces.Girder = Pieces.Girder.new(lvl.girder) if lvl.girder != null else null

	var mode := "foot"
	var move_t := 0.0
	var best := kid.x
	var stuck := 0
	var jump_hold := 0
	var ride_losses := 0
	var was_riding := false
	var steps := 0
	var piping = null
	var pipe_t := 0.0
	var pipe_cool := 0.0

	var trace := OS.get_environment("EERI_TRACE") == slug
	while steps < BUDGET_STEPS:
		steps += 1
		if trace and steps % 300 == 0:
			print("   t=%5.1f mode=%-11s kid=%6.2f mach=%6.2f bank=%s wall=%s gird=%s" % [
				steps * DT, mode, kid.x,
				machine.x if machine != null else -1.0,
				("%d/%d" % [bank.remaining, bank.rows]) if bank != null else "-",
				str(wall.state()) if wall != null else "-",
				str(girder.state()) if girder != null else "-"])
		for h in hoists:
			h.step(DT)
		for v in vents:
			v.step(DT)
		var target := {"x": kid.x, "y": kid.y, "grounded": kid.grounded}
		for r in robots:
			r.step(DT, target)

		if was_riding and mode == "foot":
			ride_losses += 1
		was_riding = mode == "riding"

		# ---- what, if anything, only the machine can clear ---------------
		# A JOB CARRIES ITS OWN REACH, and it must — the bank and the wall are
		# SOLID TERRAIN, so a machine drives up to them and stops a body-width
		# short. Asking the bot to get "within 2.2" of a bank centre is asking
		# for something the machine physically cannot do: it parks at 82.6
		# against a bank centred on 86 and drives at it forever.
		var job = null
		if bank != null and not bank.cleared:
			job = {"at": bank.centre(), "reached": bank.in_reach(mx_of(machine))}
		elif wall != null and not wall.cleared:
			job = {"at": wall.centre(), "reached": wall.in_reach(mx_of(machine))}
		elif girder != null and not girder.seated:
			if not girder.slung:
				job = {"at": girder.stack_x,
					"reached": absf(mx_of(machine) - girder.stack_x) <= 3.2}
			else:
				job = {"at": (girder.seat_x0 + girder.seat_x1) * 0.5,
					"reached": girder.can_seat(mx_of(machine))}

		if mode == "riding" and machine != null:
			if job == null:
				# JOB DONE — GET OUT. The flag only raises on foot, and a bot
				# that stays in the cab drives happily past the end forever.
				mode = "dismounting"
				move_t = 0.0
				kid.x = machine.x - machine.face * 2.6
				kid.y = maxf(lvl.ground_top(kid.x, machine.y + 2.0), machine.y)
				kid.vx = 0.0
				kid.vy = 0.0
				continue
			var dx: float = job["at"] - machine.x
			var drive := 0.0
			var verb: bool = job["reached"]
			if not verb:
				drive = signf(dx)
			machine.step(DT, drive)
			machine.step_swing(DT)
			if bank != null and not bank.cleared:
				bank.step(DT, machine.x, verb)
			if wall != null and not wall.cleared and verb:
				machine.heave()
				if machine.striking() and not machine.struck_this_swing and wall.in_reach(machine.x):
					machine.struck_this_swing = true
					if wall.strike() and wall.cleared:
						for row in wall.rows:
							lvl.clear_row(int(wall.c0), int(wall.c1), int(wall.cy0) + row)
			if girder != null and not girder.seated and verb:
				if not girder.slung:
					girder.sling(machine.x)
				elif girder.can_seat(machine.x):
					if girder.seat(machine.x):
						lvl.fill_row(int(girder.gap_c0), int(girder.gap_c1), int(girder.gap_cy))
			# the rider goes where the machine goes
			kid.x = machine.x
			kid.y = machine.y + 1.25
			run.step(kid.x, kid.y)
			continue

		if mode == "mounting" or mode == "dismounting":
			move_t += DT
			if move_t >= 0.42:
				mode = "riding" if mode == "mounting" else "foot"
			continue

		# ---- on foot -----------------------------------------------------
		# Board only when there is a job for the machine, so the bot does not
		# ride past the end of a level it could have walked.
		if job != null and machine != null and machine.can_mount(kid.x, kid.y, kid.grounded):
			mode = "mounting"
			move_t = 0.0
			machine.tame()
			continue

		# THE PIPE. The bot's whole vocabulary is right/jump/climb/verb, and it
		# has stalled on an unknown verb before, so the rule is the same shape
		# as the ladder's: standing at a mouth and getting nowhere means go
		# DOWN it. Without this, world 2's deep water has no crossing and two
		# rooms are unfinishable — which is a fact about the bot, not the level.
		if pipe_cool > 0.0:
			pipe_cool -= DT
		if piping != null:
			pipe_t += DT
			if pipe_t >= 0.55:
				var to = piping["to"]
				kid.x = float(to.get("c", 0)) + 0.5
				kid.y = float(to.get("cy", 0))
				kid.vx = 0.0
				kid.vy = 0.0
				piping = null
				pipe_cool = 0.5
			continue
		# Take it when the way ahead is a HOLE, not only when thoroughly stuck.
		# World 2's deep water is four tiles wide against a 4.75-tile run-jump,
		# which is deliberately marginal — the pipe beside it is the authored
		# crossing, and a bot that only reaches for it after failing twenty
		# times reports the room as unfinishable when it is not.
		var hole_ahead := not lvl.solid_cell(int(kid.x) + 1, int(kid.y) - 1)
		if kid.grounded and pipe_cool <= 0.0 and (stuck > 5 or hole_ahead):
			for q in lvl.pipes:
				for pair in [[q.get("a"), q.get("b")], [q.get("b"), q.get("a")]]:
					var m = pair[0]
					if m == null:
						continue
					if absf(kid.x - (float(m.get("c", 0)) + 0.5)) < 0.7 							and absf(kid.y - float(m.get("cy", 0))) < 0.6:
						piping = {"from": m, "to": pair[1]}
						pipe_t = 0.0
						stuck = 0
						break
				if piping != null:
					break
			if piping != null:
				continue

		var inp := {"ax": 1.0}
		if kid.x > best + 0.01:
			best = kid.x
			stuck = 0
		elif kid.grounded:
			# Only count stuck-ness on the GROUND. Counting it in the air made
			# the bot fire a jump every frame it was falling, so it bunny-hopped
			# off every lip instead of taking a running jump at it.
			stuck += 1

		# LOOK ONE TILE AHEAD, NOT TWO. A hole seen two tiles out makes the bot
		# leave the ground two tiles early, and a run-jump carries 4.75 — which
		# lands it 0.25 of a tile SHORT of the far lip of a 3-tile pit. One tile
		# of lookahead is the difference between clearing every authored gap and
		# falling into half of them.
		var hole := not lvl.solid_cell(int(kid.x) + 1, int(kid.y) - 1)
		var blocked := lvl.solid_cell(int(kid.x) + 1, int(kid.y))
		if kid.grounded and jump_hold <= 0 and (hole or blocked or stuck > 5):
			# HOLD THROUGH THE WHOLE ASCENT. The jump is variable-height and
			# cut_jump clamps vy to 4 the instant the button is released, so a
			# short hold chops a 0.42s climb at 0.23s and quietly turns every
			# jump into the small one.
			jump_hold = 28
		if jump_hold > 0:
			jump_hold -= 1
			inp["jump_pressed"] = jump_hold == 27
			inp["jump_held"] = true

		# A LADDER IS THE THING IN THE WAY, not an obstacle to jump. The
		# browser bot stalled on exactly this once, because climbing was a verb
		# it did not have.
		if lvl.climbable(kid.x, kid.y) and stuck > 5:
			inp["up_held"] = true

		kid.step(DT, inp)

		# stomps and knocks, so the room's enemies are really in the way
		for r in robots:
			if r.dead:
				continue
			if r.stomped_by(kid.x, kid.y, Kid.HW, kid.vy):
				kid.bounce()
			elif not r.stompable and r.landed_on(kid.x, kid.y, Kid.HW, kid.vy):
				kid.bounce()
				r.shrug()
			elif r.hits(kid.x, kid.y, Kid.HW, Kid.BH) and kid.mercy_t <= 0.0:
				kid.struck(r.x)
		for v in vents:
			if v.hits(kid.x, kid.y, Kid.HW, Kid.BH) and kid.mercy_t <= 0.0:
				kid.struck(v.x)

		run.step(kid.x, kid.y)
		if run.finished:
			return {"done": true, "x": kid.x, "w": lvl.w, "t": steps * DT,
				"ride_losses": ride_losses, "why": ""}

	var why := ""
	if job_pending(bank, wall, girder):
		why = " — the machine's job was never finished"
	return {"done": false, "x": best, "w": lvl.w, "t": steps * DT,
		"ride_losses": ride_losses, "why": why}


func job_pending(bank: Bank, wall: Pieces.Wall, girder: Pieces.Girder) -> bool:
	if bank != null and not bank.cleared:
		return true
	if wall != null and not wall.cleared:
		return true
	if girder != null and not girder.seated:
		return true
	return false


func _finish() -> void:
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		get_tree().quit(1)
	else:
		print("ALL GREEN")
		get_tree().quit(0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("  ok  - %s" % label)
	else:
		_fail += 1
		print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
