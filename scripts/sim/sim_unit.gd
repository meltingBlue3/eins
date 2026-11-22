extends RefCounted
## A deployed unit. Plain state; BattleSim owns the rules.

var uid: int
var id: String
var def: Dictionary
var cell: Vector2i
var pos: Vector2
var hp: float
var max_hp: float
var atk_timer := 0.0
var blocked: Array = []
var alive := true

# Presentation cues. The sim sets and decays them so replays stay deterministic.
var face := Vector2.RIGHT
var lunge_t := 0.0
var flash_t := 0.0
var spawn_t := 0.3


func _init(p_uid: int, p_id: String, p_def: Dictionary, p_cell: Vector2i) -> void:
	uid = p_uid
	id = p_id
	def = p_def
	cell = p_cell
	pos = Vector2(p_cell)
	max_hp = float(p_def["hp"])
	hp = max_hp


func block_capacity() -> int:
	return int(def["block"])


func can_block_more() -> bool:
	return alive and blocked.size() < block_capacity()
