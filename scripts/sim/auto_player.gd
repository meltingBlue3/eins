extends RefCounted
## Replays a deployment plan: each entry waits until its time has passed and the deploy is legal.
## Used by tests (balance gates) and by the screenshot demo.

var plan: Array
var _next := 0


func _init(p_plan: Array) -> void:
	plan = p_plan


func update(sim) -> void:
	while _next < plan.size():
		var entry: Dictionary = plan[_next]
		if sim.time < float(entry["t"]):
			return
		if sim.deploy(entry["unit"], entry["cell"]) == null:
			return
		_next += 1


## A sensible first-time plan for stage 1-1.
static func stage_1_1_plan() -> Array:
	return [
		{"t": 0.0, "unit": "blade", "cell": Vector2i(5, 1)},
		{"t": 0.0, "unit": "archer", "cell": Vector2i(5, 2)},
		{"t": 0.0, "unit": "medic", "cell": Vector2i(6, 2)},
		{"t": 0.0, "unit": "caster", "cell": Vector2i(4, 2)},
		{"t": 0.0, "unit": "warden", "cell": Vector2i(3, 3)},
		# A player redeploys a fallen blade on the second lane.
		{"t": 70.0, "unit": "blade", "cell": Vector2i(6, 3)},
	]
