extends RefCounted
## Content tables. Adding a unit, enemy, or stage should only touch this file.
## Colors are hex strings so the tables stay plain constant data.

const UNITS := {
	"blade": {
		"name": "剑士", "glyph": "剑", "role": "近卫", "color": "e07b4f",
		"cost": 10, "hp": 1000, "atk": 180, "def": 60, "res": 0, "interval": 1.0,
		"block": 2, "range": 0.8, "tile": "ground", "kind": "melee", "damage": "physical",
		"redeploy": 20.0, "desc": "地面 · 阻挡 2 · 攻击稳定，开局主力。",
	},
	"warden": {
		"name": "盾卫", "glyph": "盾", "role": "重装", "color": "4f8fd8",
		"cost": 14, "hp": 1600, "atk": 80, "def": 140, "res": 0, "interval": 1.4,
		"block": 3, "range": 0.8, "tile": "ground", "kind": "melee", "damage": "physical",
		"redeploy": 20.0, "desc": "地面 · 阻挡 3 · 护甲很高，几乎不怕雾团。",
	},
	"archer": {
		"name": "弓手", "glyph": "弓", "role": "狙击", "color": "6cbf5a",
		"cost": 9, "hp": 600, "atk": 110, "def": 20, "res": 0, "interval": 1.0,
		"block": 0, "range": 2.6, "tile": "high", "kind": "ranged", "damage": "physical",
		"redeploy": 20.0, "desc": "高台 · 优先射击最接近灯塔的敌人。打不动重甲。",
	},
	"caster": {
		"name": "术士", "glyph": "术", "role": "术师", "color": "a46ee0",
		"cost": 16, "hp": 550, "atk": 150, "def": 10, "res": 20, "interval": 1.6,
		"block": 0, "range": 2.2, "tile": "high", "kind": "ranged", "damage": "arts",
		"redeploy": 20.0, "desc": "高台 · 法术伤害无视护甲，专克雾甲。",
	},
	"medic": {
		"name": "医师", "glyph": "医", "role": "医疗", "color": "f2d16b",
		"cost": 12, "hp": 600, "atk": 120, "def": 10, "res": 0, "interval": 2.0,
		"block": 0, "range": 2.6, "tile": "high", "kind": "healer", "damage": "heal",
		"redeploy": 20.0, "desc": "高台 · 治疗范围内血量比例最低的队友。",
	},
}
const UNIT_ORDER := ["blade", "warden", "archer", "caster", "medic"]

const ENEMIES := {
	"slime": {
		"name": "雾团", "hp": 550, "atk": 120, "def": 20, "res": 0, "interval": 1.6,
		"speed": 0.9, "size": 0.24, "life_cost": 1, "color": "6b5a8e", "shape": "blob",
	},
	"hound": {
		"name": "雾犬", "hp": 300, "atk": 90, "def": 0, "res": 0, "interval": 1.0,
		"speed": 1.7, "size": 0.19, "life_cost": 1, "color": "9a5a86", "shape": "hound",
	},
	"brute": {
		"name": "雾甲", "hp": 1200, "atk": 220, "def": 100, "res": 0, "interval": 2.4,
		"speed": 0.5, "size": 0.33, "life_cost": 2, "color": "4a4e6e", "shape": "brute",
	},
}

## Map legend: '#' void, '.' ground (walkable, melee deploy), '^' high ground (ranged deploy),
## 'R' enemy gate, 'B' lighthouse. Enemies follow the shortest walkable route R -> B.
const STAGES := [
	{
		"id": "1-1",
		"name": "雾起之港",
		"life": 10,
		"map": [
			"#^^^^##^^^^#",
			"R........^^#",
			"#^^^^^^^.^^#",
			"#^.......^^#",
			"#^.^^^^^^^^#",
			"##.........B",
		],
		"waves": [
			{"t": 5.0, "type": "slime", "n": 3, "gap": 2.0},
			{"t": 18.0, "type": "slime", "n": 4, "gap": 1.5},
			{"t": 30.0, "type": "hound", "n": 3, "gap": 1.0},
			{"t": 45.0, "type": "brute", "n": 1},
			{"t": 50.0, "type": "slime", "n": 5, "gap": 1.2},
			{"t": 65.0, "type": "hound", "n": 4, "gap": 0.8},
			{"t": 80.0, "type": "brute", "n": 2, "gap": 4.0},
			{"t": 85.0, "type": "slime", "n": 6, "gap": 1.0},
			{"t": 100.0, "type": "hound", "n": 5, "gap": 0.7},
			{"t": 105.0, "type": "brute", "n": 1},
		],
		"hint": "近战放在地面挡路，远程放在高台输出。雾甲很硬，交给术士。",
	},
]
