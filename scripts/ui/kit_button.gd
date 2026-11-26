extends Button
## Plaque button with a little life: grows on hover, dips on press.
## Create it with UiKit.button(...), which also applies the plaque style.

var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_to.bind(1.06))
	mouse_exited.connect(_to.bind(1.0))
	button_down.connect(_to.bind(0.95))
	button_up.connect(func(): _to(1.06 if is_hovered() else 1.0))


func _to(s: float) -> void:
	if disabled:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(s, s), 0.14)
