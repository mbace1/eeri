class_name CastLight
extends RefCounted
## The rim on the cast, and the lamp he carries at night.
##
## Ported from js/light.js §3 and js/craft.js's `rimLight` (browser v15.52).
## `ART_TARGET` §2a scores the cast "strong shapes, NO RIM LIGHT", and rung 4
## says what to do about it: "rim light on the cast only — one cheap fresnel
## term in the character material is what keeps a silhouette readable against
## a busy background." Captured frames agreed, and on the night shift they
## were damning: a mid-dark figure against a mid-dark depot, with the bolts
## the brightest thing near him.
##
## WHY THIS IS A SHADER AND NOT A LIGHT. A real light would touch the painted
## backdrop, which already has its shading drawn into it — the mistake
## `dressing34.gd`'s header warns about. A fresnel term added to the
## character's own material touches only the character.
##
## The rim COLOUR is the world's own key (warm yard, cold trench, green
## grove, blue night) and the strength is what that backdrop's business
## demands — the same table the browser build carries, because a second table
## of the same numbers is a second thing to keep in step.
const RIM := {
	"groundworks": {"color": Color("fff3dc"), "strength": 0.22},
	"pipeworks": {"color": Color("dceaff"), "strength": 0.34},
	"grove": {"color": Color("e8ffd8"), "strength": 0.40},
	# the big one: the depot is dark, blue and busy, and the rim is the only
	# thing on him the backdrop cannot also be
	"nightshift": {"color": Color("cfe2ff"), "strength": 0.72},
}

## An optional work lamp that FOLLOWS the cast. Only the night shift gets one,
## and it is the honest reading of that world: everyone on a night shift is
## carrying a light. `i: 0` is every daylight world — written out so the table
## reads as a set rather than a special case.
const LAMP := {
	"groundworks": {"i": 0.0},
	"pipeworks": {"i": 0.0},
	"grove": {"i": 0.0},
	"nightshift": {"i": 0.55, "r": 5.4, "colour": Color("ffd9a0"), "y": 0.9},
}

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_strength = 0.0;
uniform float rim_power = 2.6;

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	// The fresnel: 1 at the silhouette, 0 face-on. Added as EMISSION rather
	// than mixed into albedo, so it is a light ON the shape and not a repaint
	// of it -- and so it survives any colour the scene multiplies in, the way
	// the browser build's version survives applyMood's night tint.
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	EMISSION = rim_color.rgb * (f * rim_strength);
}
"""


## Give every mesh under `root` the rim shader, keeping whatever texture it
## already had. Returns how many materials were replaced, so a gate can assert
## a number instead of trusting a screenshot.
static func apply(root: Node3D) -> int:
	var sh := Shader.new()
	sh.code = SHADER
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.push_back(c)
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var mat := ShaderMaterial.new()
			mat.shader = sh
			if src != null and src.albedo_texture != null:
				mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("rim_color", Color.WHITE)
			mat.set_shader_parameter("rim_strength", 0.0)
			mat.set_shader_parameter("rim_power", 2.6)
			mi.set_surface_override_material(i, mat)
			n += 1
	return n


## Retune a built rim for the world he has walked into. The cast crosses four
## worlds without being rebuilt, so this is a dial rather than a constant.
static func set_world(root: Node3D, world: String) -> void:
	var r: Dictionary = RIM.get(world, RIM["groundworks"])
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.push_back(c)
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i) as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("rim_color", r["color"])
			mat.set_shader_parameter("rim_strength", r["strength"])


## The follow lamp: one OmniLight the cast carries. Built once — the kid is
## the only thing on screen that is never rebuilt, so neither is his light.
static func make_lamp() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "CastLamp"
	l.visible = false
	l.light_energy = 0.0
	l.omni_range = 5.4
	l.shadow_enabled = false          # ART_BRIEF §3.4: no cast shadow maps
	return l


static func set_lamp(lamp: OmniLight3D, world: String) -> float:
	var spec: Dictionary = LAMP.get(world, {"i": 0.0})
	var i := float(spec.get("i", 0.0))
	lamp.visible = i > 0.0
	lamp.light_energy = i * 2.0        # Godot's energy is not the quad's alpha
	lamp.light_color = spec.get("colour", Color("ffd9a0"))
	lamp.omni_range = float(spec.get("r", 5.4))
	return float(spec.get("y", 0.9))
