extends RefCounted
## Art style registry. Drawing code asks here for a texture; null means "draw the grey-box shape".
## Textures live in res://assets/art/<style>/<folder>/<name>.png, stored at 2x on-screen size
## and bottom-anchored (see tools/art/process_style.py).

const STORE_SCALE := 2.0
const STYLES := [
	{"id": "cel", "name": "A 晴港赛璐璐"},
	{"id": "watercolor", "name": "B 雾色水彩"},
	{"id": "pixel", "name": "C 像素点阵"},
	{"id": "greybox", "name": "灰盒"},
]

static var current := 0
static var _cache := {}


static func style_id() -> String:
	return STYLES[current]["id"]


static func style_name() -> String:
	return STYLES[current]["name"]


static func cycle() -> void:
	current = (current + 1) % STYLES.size()


static func select(id: String) -> bool:
	for i in STYLES.size():
		if STYLES[i]["id"] == id:
			current = i
			return true
	return false


static func tex(folder: String, name: String) -> Texture2D:
	var id := style_id()
	if id == "greybox":
		return null
	var path := "res://assets/art/%s/%s/%s.png" % [id, folder, name]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## On-screen size of a stored texture.
static func screen_size(t: Texture2D) -> Vector2:
	return t.get_size() / STORE_SCALE
