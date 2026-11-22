extends RefCounted
## An enemy walking the stage path. Plain state; BattleSim owns the rules.

var uid: int
var type: String
var def: Dictionary
var pos: Vector2
var path_i := 1
var progress := 0.0
var hp: float
var max_hp: float
var blocker = null  # SimUnit currently holding this enemy, or null
var atk_timer := 0.0
var alive := true

# Presentation cues.
var face := Vector2.RIGHT
var lunge_t := 0.0
var flash_t := 0.0
var jitter := Vector2.ZERO


func _init(p_uid: int, p_type: String, p_def: Dictionary, start: Vector2) -> void:
	uid = p_uid
	type = p_type
	def = p_def
	pos = start
	max_hp = float(p_def["hp"])
	hp = max_hp
	# Deterministic small offset so stacked enemies stay readable.
	var a := float(p_uid) * 2.399
	jitter = Vector2(cos(a), sin(a)) * 0.12
