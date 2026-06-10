extends RefCounted
class_name ItemData

const CATALOG_PATH := "res://data/items.json"

const EQUIP_SLOTS := [
	"helmet",
	"amulet",
	"weapon",
	"chest",
	"gloves",
	"ring_1",
	"legs",
	"ring_2",
	"earring_1",
	"feet",
	"earring_2",
]

const RARITY_COLORS := {
	"basic": Color(0.55, 0.58, 0.52),
	"common": Color(0.78, 0.78, 0.82),
	"rare": Color(0.35, 0.72, 1.0),
	"unique": Color(0.95, 0.72, 0.28),
}

const RARITY_NAMES := {
	"basic": "Basic",
	"common": "Common",
	"rare": "Rare",
	"unique": "Unique",
	"trade": "Trade",
	"epic": "Epic",
}

const SLOT_NAMES := {
	"weapon": "Weapon",
	"chest": "Chest",
	"legs": "Legs",
	"feet": "Boots",
	"gloves": "Gloves",
	"helmet": "Helmet",
	"earring": "Earring",
	"ring": "Ring",
	"amulet": "Amulet",
}

const STAT_LABELS := {
	"attack": "Attack",
	"armor": "Armor",
	"max_hp": "Health",
	"max_mana": "Mana",
	"spell_power": "Spell Power",
}

const STAT_SHORT := {
	"attack": "ATK",
	"armor": "ARM",
	"max_hp": "HP",
	"max_mana": "MP",
	"spell_power": "SP",
}

const RARITY_POWER := {
	"basic": 1,
	"common": 2,
	"rare": 4,
	"unique": 8,
}

const RARITY_MULT := {
	"basic": 1.0,
	"common": 1.4,
	"rare": 2.2,
	"unique": 3.5,
}

const SLOT_STATS := {
	"weapon": {"attack": 4.0},
	"chest": {"armor": 3.0, "max_hp": 10.0},
	"legs": {"armor": 2.0},
	"feet": {"armor": 1.0},
	"gloves": {"attack": 2.0},
	"helmet": {"armor": 2.0, "max_hp": 6.0},
	"earring": {"spell_power": 2.0},
	"ring": {"attack": 1.0, "spell_power": 1.0},
	"amulet": {"max_hp": 6.0, "max_mana": 4.0},
}

static var _defs: Dictionary = {}
static var _textures: Dictionary = {}
static var _content_rects: Dictionary = {}

# Slot ic cerceve ile ayni (inventory_slot_draw.gd grow(-2))
const ICON_INSET := 2.0


static func load_catalog() -> void:
	_defs.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("Item catalog not found: %s" % CATALOG_PATH)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse item JSON")
		return

	for entry in parsed.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			continue
		_defs[id] = entry


static func get_def(id: String) -> Dictionary:
	if _defs.is_empty():
		load_catalog()
	return _defs.get(id, {})


static func make_instance(id: String) -> Dictionary:
	return {"id": id}


static func display_name(item: Dictionary) -> String:
	var def := get_def(str(item.get("id", "")))
	return str(def.get("name", item.get("id", "?")))


static func item_slot(item: Dictionary) -> String:
	return str(get_def(str(item.get("id", ""))).get("slot", ""))


static func item_rarity(item: Dictionary) -> String:
	var id := str(item.get("id", ""))
	if id.is_empty():
		return str(item.get("rarity", "common"))
	return str(get_def(id).get("rarity", "common"))


static func rarity_name(rarity: String) -> String:
	return str(RARITY_NAMES.get(rarity, rarity.capitalize()))


static func slot_name(slot_type: String) -> String:
	return str(SLOT_NAMES.get(slot_type, slot_type))


static func prefer_equip_slot(item: Dictionary, equipment: Dictionary) -> String:
	var slot_type := item_slot(item)
	if slot_type == "ring":
		if equipment.get("ring_1") == null:
			return "ring_1"
		if equipment.get("ring_2") == null:
			return "ring_2"
		return "ring_1"
	if slot_type == "earring":
		if equipment.get("earring_1") == null:
			return "earring_1"
		if equipment.get("earring_2") == null:
			return "earring_2"
		return "earring_1"
	if EQUIP_SLOTS.has(slot_type):
		return slot_type
	return ""


static func comparison_line(
	item: Dictionary,
	equipment: Dictionary,
	equip_slot_hint: String = ""
) -> String:
	var id := str(item.get("id", ""))
	if id.is_empty():
		return ""

	var target := equip_slot_hint
	if target.is_empty():
		target = prefer_equip_slot(item, equipment)
	if target.is_empty() or not equipment.has(target):
		return ""

	var equipped: Variant = equipment.get(target)
	if equipped == null or typeof(equipped) != TYPE_DICTIONARY:
		return ""

	var equipped_id := str(equipped.get("id", ""))
	if equipped_id == id:
		return ""

	var new_def := get_def(id)
	var old_def := get_def(equipped_id)
	if new_def.is_empty() or old_def.is_empty():
		return ""

	var new_stats := compute_stats(new_def)
	var old_stats := compute_stats(old_def)

	var best_key := ""
	var best_delta := 0.0
	for key in ["attack", "armor", "max_hp", "spell_power", "max_mana"]:
		var delta := float(new_stats.get(key, 0.0)) - float(old_stats.get(key, 0.0))
		if best_key.is_empty() or absf(delta) > absf(best_delta):
			best_delta = delta
			best_key = key

	if best_key.is_empty() or best_delta == 0.0:
		return ""

	var slot_label := slot_name(item_slot(item)).to_lower()
	var stat_label := str(STAT_SHORT.get(best_key, best_key))
	var old_v := float(old_stats.get(best_key, 0.0))
	var new_v := float(new_stats.get(best_key, 0.0))
	return "Current %s: +%.0f %s → This: +%.0f (%+.0f)" % [
		slot_label, old_v, stat_label, new_v, best_delta
	]


static func comparison_delta(
	item: Dictionary,
	equipment: Dictionary,
	equip_slot_hint: String = ""
) -> float:
	var id := str(item.get("id", ""))
	if id.is_empty():
		return 0.0

	var target := equip_slot_hint
	if target.is_empty():
		target = prefer_equip_slot(item, equipment)
	if target.is_empty():
		return 0.0

	var equipped: Variant = equipment.get(target)
	if equipped == null or typeof(equipped) != TYPE_DICTIONARY:
		return 0.0

	var equipped_id := str(equipped.get("id", ""))
	if equipped_id == id:
		return 0.0

	var new_stats := compute_stats(get_def(id))
	var old_stats := compute_stats(get_def(equipped_id))

	var best_delta := 0.0
	for key in ["attack", "armor", "max_hp", "spell_power", "max_mana"]:
		var delta := float(new_stats.get(key, 0.0)) - float(old_stats.get(key, 0.0))
		if absf(delta) > absf(best_delta):
			best_delta = delta
	return best_delta


static func sell_value(item: Dictionary) -> int:
	var id := str(item.get("id", ""))
	if id.is_empty():
		return 8 + int(item.get("power", 1)) * 6
	var def := get_def(id)
	var stats := compute_stats(def)
	return 8 + int(stats.get("power", item.get("power", 1))) * 6


static func tooltip_lines(item: Dictionary, footer_hint: String = "") -> PackedStringArray:
	var lines: PackedStringArray = []
	var id := str(item.get("id", ""))

	if id.is_empty():
		lines.append(str(item.get("name", "?")))
		var legacy_rarity := str(item.get("rarity", ""))
		if not legacy_rarity.is_empty():
			lines.append(rarity_name(legacy_rarity))
		lines.append("Sell: %d gold" % sell_value(item))
		if not footer_hint.is_empty():
			lines.append(footer_hint)
		return lines

	var def := get_def(id)
	if def.is_empty():
		lines.append(id)
		return lines

	var rarity := str(def.get("rarity", "common"))
	lines.append(display_name(item))
	lines.append("%s — %s" % [rarity_name(rarity), slot_name(str(def.get("slot", "")))])

	var stats := compute_stats(def)
	for key in ["attack", "armor", "max_hp", "max_mana", "spell_power"]:
		var amount := float(stats.get(key, 0.0))
		if amount > 0.0:
			lines.append("%s +%.0f" % [STAT_LABELS.get(key, key), amount])

	lines.append("Sell: %d gold" % sell_value(item))
	if not footer_hint.is_empty():
		lines.append(footer_hint)
	return lines


static func preload_all_textures() -> void:
	if _defs.is_empty():
		load_catalog()
	for id in _defs.keys():
		get_texture(id)


static func get_texture(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if _textures.has(id):
		return _textures[id]

	var def := get_def(id)
	var path: String = str(def.get("sprite", ""))
	if path.is_empty():
		return null

	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	if tex == null:
		var fs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(fs_path):
			var image := Image.load_from_file(fs_path)
			if image != null:
				tex = ImageTexture.create_from_image(image)

	if tex != null:
		_textures[id] = tex
		_content_rects[id] = _compute_content_rect(tex)
	return tex


static func _compute_content_rect(tex: Texture2D) -> Rect2:
	var tex_w := tex.get_width()
	var tex_h := tex.get_height()
	if tex_w <= 0 or tex_h <= 0:
		return Rect2(0, 0, 1, 1)

	var image := tex.get_image()
	if image == null or image.is_empty():
		return Rect2(0, 0, tex_w, tex_h)

	var min_x := tex_w
	var min_y := tex_h
	var max_x := 0
	var max_y := 0
	var step := 4
	var alpha_cutoff := 0.08

	for y in range(0, tex_h, step):
		for x in range(0, tex_w, step):
			if image.get_pixel(x, y).a > alpha_cutoff:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if min_x > max_x:
		return Rect2(0, 0, tex_w, tex_h)

	max_x = mini(tex_w - 1, max_x + step)
	max_y = mini(tex_h - 1, max_y + step)
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _content_rect_for(id: String, tex: Texture2D) -> Rect2:
	if _content_rects.has(id):
		return _content_rects[id]
	var rect := _compute_content_rect(tex)
	_content_rects[id] = rect
	return rect


enum IconFit { FIT, COVER, STRETCH }


static func icon_inner_rect(slot_rect: Rect2, inset_px: float = ICON_INSET) -> Rect2:
	return slot_rect.grow(-inset_px)


static func icon_draw_rects(
	slot_rect: Rect2,
	tex: Texture2D,
	content_src: Rect2,
	fit: IconFit = IconFit.STRETCH,
	inset_px: float = ICON_INSET
) -> Dictionary:
	var inner := icon_inner_rect(slot_rect, inset_px)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return {"dest": inner, "src": content_src}

	var src_size := content_src.size
	if src_size.x <= 0.0 or src_size.y <= 0.0:
		return {"dest": inner, "src": Rect2(0, 0, tex.get_width(), tex.get_height())}

	if fit == IconFit.STRETCH:
		return {"dest": inner, "src": content_src}

	var scale: float
	if fit == IconFit.COVER:
		scale = maxf(inner.size.x / src_size.x, inner.size.y / src_size.y)
	else:
		scale = minf(inner.size.x / src_size.x, inner.size.y / src_size.y)

	var drawn := Vector2(src_size.x * scale, src_size.y * scale)
	var pos := inner.position + (inner.size - drawn) * 0.5
	return {"dest": Rect2(pos, drawn), "src": content_src}


static func icon_rect(
	slot_rect: Rect2,
	tex: Texture2D,
	fit: IconFit = IconFit.STRETCH,
	inset_px: float = ICON_INSET
) -> Rect2:
	var content := Rect2(0, 0, tex.get_width(), tex.get_height())
	return icon_draw_rects(slot_rect, tex, content, fit, inset_px)["dest"]


static func draw_item_icon(
	canvas: CanvasItem,
	slot_rect: Rect2,
	item: Dictionary,
	fit: IconFit = IconFit.STRETCH,
	inset_px: float = ICON_INSET,
	modulate: Color = Color.WHITE
) -> bool:
	var id: String = str(item.get("id", ""))
	if id.is_empty():
		return false

	var tex: Texture2D = get_texture(id)
	if tex == null:
		return false

	var content := _content_rect_for(id, tex)
	var draw := icon_draw_rects(slot_rect, tex, content, fit, inset_px)
	canvas.draw_texture_rect_region(tex, draw["dest"], draw["src"], modulate)
	return true


static func slot_accepts(item_slot_type: String, equip_slot: String) -> bool:
	if item_slot_type == equip_slot:
		return true
	if item_slot_type == "earring" and equip_slot.begins_with("earring_"):
		return true
	if item_slot_type == "ring" and equip_slot.begins_with("ring_"):
		return true
	return false


static func compute_stats(def: Dictionary) -> Dictionary:
	var slot_type: String = str(def.get("slot", ""))
	var rarity: String = str(def.get("rarity", "common"))
	var mult: float = float(RARITY_MULT.get(rarity, 1.0))
	var base: Dictionary = SLOT_STATS.get(slot_type, {})
	var stats := {"power": int(RARITY_POWER.get(rarity, 1))}

	for key in base.keys():
		stats[key] = float(base[key]) * mult
	return stats


static func aggregate_stats(items: Array) -> Dictionary:
	var totals := {
		"attack": 0.0,
		"armor": 0.0,
		"max_hp": 0.0,
		"max_mana": 0.0,
		"spell_power": 0.0,
		"power": 0,
	}
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var def := get_def(str(item.get("id", "")))
		if def.is_empty():
			continue
		var stats := compute_stats(def)
		for key in stats.keys():
			totals[key] = totals.get(key, 0.0) + float(stats[key])
	return totals


static func ids_by_rarity(rarity: String) -> Array[String]:
	if _defs.is_empty():
		load_catalog()
	var result: Array[String] = []
	for id in _defs.keys():
		if str(_defs[id].get("rarity", "")) == rarity:
			result.append(id)
	return result


static func random_id() -> String:
	if _defs.is_empty():
		load_catalog()
	if _defs.is_empty():
		return ""
	var keys := _defs.keys()
	return keys[randi() % keys.size()]


static func roll_rarity() -> String:
	var roll := randf()
	if roll > 0.97:
		return "unique"
	if roll > 0.88:
		return "rare"
	if roll > 0.65:
		return "common"
	return "basic"


static func roll_loot_instance() -> Dictionary:
	var rarity := roll_rarity()
	var pool := ids_by_rarity(rarity)
	if pool.is_empty():
		return make_instance(random_id())
	return make_instance(pool[randi() % pool.size()])
