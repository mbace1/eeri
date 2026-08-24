class_name Pieces
extends RefCounted
## The manipulable world pieces — the LOCKS a ride machine exists to open.
## Ported from js/pieces.js.
##
## THE RULE THE ART BRIEF STATES AND THIS FILE OBEYS: draw the CHANGE. A
## cracked wall keeps its full height and gains a crack; it does not become a
## shorter wall. Rubble is a different silhouette, not less of the same one.
## That is why every piece ships all of its states as sibling nodes
## (state0/state1/state2) sharing one origin — the game shows exactly one.


class Wall extends RefCounted:
	## Intact -> cracked -> rubble. Two strikes of the wrecking ball.
	const HITS_TO_CLEAR := 2

	var c0 := 0.0
	var c1 := 0.0
	var cy0 := 0.0
	var rows := 0
	var hits := 0
	var cleared := false

	func _init(def: Dictionary) -> void:
		c0 = float(def.get("c0", 0))
		c1 = float(def.get("c1", 0))
		cy0 = float(def.get("cy0", 0))
		rows = int(def.get("rows", 3))

	func centre() -> float:
		return (c0 + c1) * 0.5

	## Struck by the ball. Returns true if this strike changed anything.
	func strike() -> bool:
		if cleared:
			return false
		hits += 1
		if hits >= HITS_TO_CLEAR:
			cleared = true
		return true

	## 0 = intact, 1 = cracked, 2 = rubble. A CRACKED WALL IS STILL A WALL —
	## it blocks exactly as much as an intact one, which is what makes the
	## second swing worth taking rather than a formality.
	func state() -> int:
		if cleared:
			return 2
		return 1 if hits > 0 else 0

	func blocks() -> bool:
		return not cleared

	func in_reach(machine_x: float) -> bool:
		return absf(machine_x - centre()) < (c1 - c0) * 0.5 + 3.6


class Girder extends RefCounted:
	## Stacked -> slung -> seated as a span. The same gesture as the dig, the
	## other way round: the bucket TAKES the load off the stack and lowers it
	## in at the lip.
	##
	## The authored record is {stackX, gap:{c0,c1,cy}, seat:{x0,x1}, spanLen}.
	## `seat` is the WINDOW THE MACHINE MUST STAND IN to lower it — not where
	## the girder ends up — which is why it is a narrow x range beside the gap
	## rather than the gap itself.
	var stack_x := 0.0
	var gap_c0 := 0.0
	var gap_c1 := 0.0
	var gap_cy := 0.0
	var seat_x0 := 0.0
	var seat_x1 := 0.0
	var span_len := 0.0

	var slung := false
	var seated := false

	func _init(def: Dictionary) -> void:
		stack_x = float(def.get("stackX", 0))
		var g = def.get("gap", {})
		gap_c0 = float(g.get("c0", 0))
		gap_c1 = float(g.get("c1", 0))
		gap_cy = float(g.get("cy", 0))
		var st = def.get("seat", {})
		seat_x0 = float(st.get("x0", 0))
		seat_x1 = float(st.get("x1", 0))
		span_len = float(def.get("spanLen", 0))

	func gap_centre() -> float:
		return (gap_c0 + gap_c1) * 0.5

	## Picked up. Only from the stack, and only once.
	func sling(machine_x: float) -> bool:
		if slung or seated:
			return false
		if absf(machine_x - stack_x) > 3.2:
			return false
		slung = true
		return true

	## Lowered in at the lip — and only from inside the authored seat window.
	## THE SPAN IS WALKED ON, so seating it is what actually changes the map.
	func can_seat(machine_x: float) -> bool:
		return slung and not seated and machine_x >= seat_x0 and machine_x <= seat_x1

	func seat(machine_x: float) -> bool:
		if not can_seat(machine_x):
			return false
		slung = false
		seated = true
		return true

	func state() -> int:
		if seated:
			return 2
		return 1 if slung else 0
