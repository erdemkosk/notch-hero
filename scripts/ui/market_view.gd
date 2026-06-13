extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const InventoryHoverScript = preload("res://scripts/ui/inventory_hover.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")
const ItemRarityFrameScript = preload("res://scripts/ui/item_rarity_frame.gd")
const SpriteSheetFramesScript = preload("res://scripts/ui/sprite_sheet_frames.gd")

const LABEL_COLOR := Color(0.82, 0.72, 0.58)
const GOLD_COLOR := Color(0.92, 0.74, 0.38)
const TEXT_ACTIVE := Color(0.98, 0.94, 0.84)
const BUBBLE_BG := Color(0.08, 0.06, 0.10, 0.95)
const COUNTER_COLOR := Color(0.24, 0.16, 0.12)

var _sprite: AnimatedSprite2D
var _hover_slot := -1
var _action_timer := 0.0
var _idle_random_timer := 6.0
var _speech_text := "Welcome, traveler!"
var _last_quote_update_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	if GameState != null:
		GameState.state_changed.connect(queue_redraw)

	# Setup the shopkeeper AnimatedSprite2D
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_apply_shopkeeper_sheet()
	_sprite.play("idle")
	
	_speech_text = _get_default_merchant_quote()
	set_process(true)


func _apply_shopkeeper_sheet() -> void:
	var sheet: Texture2D = load("res://assets/characters/shopkeeper_sheet.png")
	var sprite_frames := SpriteFrames.new()
	
	var add_anim = func(name: String, row: int, col: int):
		sprite_frames.add_animation(name)
		sprite_frames.set_animation_speed(name, 5.0)
		sprite_frames.set_animation_loop(name, true)
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2i(col * 125, row * 166, 125, 166)
		sprite_frames.add_frame(name, tex, 1.0)

	# Map new shopkeeper sheet cells to actions
	add_anim.call("idle", 0, 0)          # Idle standing
	add_anim.call("talk", 0, 1)          # Talk gesture
	add_anim.call("hold", 0, 2)          # Gold coin hold
	add_anim.call("walk", 2, 3)          # Walking/running
	add_anim.call("carry_basket", 1, 3)  # Gesturing/welcoming
	add_anim.call("read", 1, 2)          # Reading scroll/map
	add_anim.call("cook", 2, 0)          # Jump/Cheer
	add_anim.call("mine", 2, 1)          # Clapping/rubbing hands
	add_anim.call("carry_logs", 0, 3)    # Putting coins in box
	add_anim.call("sleep", 2, 2)         # Bowing/thinking/counting

	_sprite.sprite_frames = sprite_frames


func _process(delta: float) -> void:
	if not visible or GameState == null or not GameState.has_hero():
		return

	# Handle shopkeeper action timer
	if _action_timer > 0.0:
		_action_timer -= delta
		if _action_timer <= 0.0:
			_sprite.play("idle")
			_speech_text = _get_default_merchant_quote()

	# Idle animation randomizer
	_idle_random_timer -= delta
	if _idle_random_timer <= 0.0:
		_idle_random_timer = randf_range(6.0, 12.0)
		if _sprite.animation == "idle" and _action_timer <= 0.0:
			var r := randf()
			if r < 0.35:
				_sprite.play("read")
			elif r < 0.65:
				_sprite.play("carry_basket")
			else:
				_sprite.play("talk")
			
			# Return to idle after a short delay
			get_tree().create_timer(2.2).timeout.connect(func() -> void:
				if is_instance_valid(_sprite) and _action_timer <= 0.0:
					_sprite.play("idle")
			)

	# Periodically drift/rotate default quote when idle
	var now := Time.get_ticks_msec()
	if _action_timer <= 0.0 and _hover_slot == -1 and now - _last_quote_update_ms > 7000:
		_speech_text = _get_default_merchant_quote()
		_last_quote_update_ms = now

	# Reposition sprite based on size
	var shop_rect := _shopkeeper_rect()
	var scale_factor := 1.8
	_sprite.scale = Vector2(scale_factor, scale_factor)
	var counter_h := UIScaleScript.px(18.0)
	var bottom_y := shop_rect.end.y - counter_h
	_sprite.position = Vector2(
		shop_rect.position.x + shop_rect.size.x * 0.5,
		bottom_y - (83.0 * scale_factor) + UIScaleScript.px(16.0)
	)

	queue_redraw()


func _get_default_merchant_quote() -> String:
	var quotes := [
		"Welcome, traveler!",
		"Only the finest wares!",
		"Need scrolls or potions?",
		"Prices refresh every 2 hours.",
		"Spend your gold wisely!",
		"Items directly go to your bag!"
	]
	var idx := int(Time.get_ticks_msec() / 7000) % quotes.size()
	return quotes[idx]


func _get_item_quote(item: Dictionary) -> String:
	var id: String = item.get("id", "")
	var name: String = ItemDataScript.display_name(item)
	
	if id.contains("blessed"):
		return "A blessed scroll! Extremely rare."
	if id.contains("standard"):
		return "Need to upgrade your gear?"
	if id.contains("potion"):
		return "Potions save lives, my friend."
	if id.contains("crystal") or id.contains("shard") or id.contains("dust"):
		return "Rare materials for forge enchants!"
	
	var rarity := ItemDataScript.item_rarity(item)
	if rarity == "unique":
		return "A unique %s! Worth every gold!" % name
	if rarity == "rare":
		return "That rare %s will boost your stats!" % name
	
	return "A sturdy %s. Interested?" % name


func _left_panel_rect() -> Rect2:
	var w := size.x * 0.50
	var x := UIScaleScript.px(6.0)
	var y := UIScaleScript.px(6.0)
	var h := size.y - y - UIScaleScript.px(6.0)
	return Rect2(x, y, w, h)


func _right_panel_rect() -> Rect2:
	var left_rect := _left_panel_rect()
	var x := left_rect.end.x + UIScaleScript.px(6.0)
	var w := size.x - x - UIScaleScript.px(6.0)
	var y := UIScaleScript.px(6.0)
	var h := size.y - y - UIScaleScript.px(6.0)
	return Rect2(x, y, w, h)


func _shopkeeper_rect() -> Rect2:
	var right_rect := _right_panel_rect()
	var y := UIScaleScript.px(48.0)
	var h := right_rect.end.y - y - UIScaleScript.px(6.0)
	return Rect2(right_rect.position.x, y, right_rect.size.x, h)


func _bubble_rect() -> Rect2:
	var right_rect := _right_panel_rect()
	var x := right_rect.position.x
	var w := right_rect.size.x
	var y := UIScaleScript.px(10.0)
	var h := UIScaleScript.px(34.0)
	return Rect2(x, y, w, h)


func _grid_origin() -> Vector2:
	var left_rect := _left_panel_rect()
	var grid_w := UIScaleScript.px(146.0)
	var origin_x := left_rect.position.x + (left_rect.size.x - grid_w) * 0.5
	return Vector2(origin_x, UIScaleScript.px(44.0))


func _slot_size() -> Vector2:
	return Vector2(UIScaleScript.px(38.0), UIScaleScript.px(38.0))


func _slot_rect(index: int) -> Rect2:
	var col := index % 3
	var row := int(index / 3)
	var origin := _grid_origin()
	var s := _slot_size()
	var gap_x := UIScaleScript.px(16.0)
	var gap_y := UIScaleScript.px(20.0) # Larger y gap to fit price tags below
	
	return Rect2(
		origin.x + col * (s.x + gap_x),
		origin.y + row * (s.y + gap_y),
		s.x,
		s.y
	)


func _price_label_rect(slot_rect: Rect2) -> Rect2:
	return Rect2(
		slot_rect.position.x - UIScaleScript.px(6.0),
		slot_rect.position.y + slot_rect.size.y + UIScaleScript.px(1.0),
		slot_rect.size.x + UIScaleScript.px(12.0),
		UIScaleScript.px(12.0)
	)


func _slot_at(local_pos: Vector2) -> int:
	if GameState == null or GameState.market_offers.size() < 6:
		return -1
	for i in range(6):
		if _slot_rect(i).has_point(local_pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if GameState == null or GameState.market_offers.size() < 6:
		return

	if event is InputEventMouseMotion:
		var slot := _slot_at(event.position)
		if slot != _hover_slot:
			_hover_slot = slot
			if _hover_slot >= 0:
				var offer: Dictionary = GameState.market_offers[_hover_slot]
				if not offer.get("bought", false):
					_speech_text = _get_item_quote(offer["item"])
					if _action_timer <= 0.0:
						_sprite.play("talk")
			else:
				if _action_timer <= 0.0:
					_speech_text = _get_default_merchant_quote()
					_sprite.play("idle")
			queue_redraw()
			
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := _slot_at(event.position)
		if slot >= 0:
			_buy_offer(slot)


func _buy_offer(index: int) -> void:
	var offer: Dictionary = GameState.market_offers[index]
	if offer.get("bought", false):
		return
		
	var price: int = offer.get("price", 0)
	var discount := 0.0
	if GameState.hero != null and GameState.hero.has_method("get_talent_shop_discount_modifier"):
		discount = GameState.hero.get_talent_shop_discount_modifier()
	var cost := int(round(price * (1.0 - discount)))

	if GameState.hero.gold < cost:
		_speech_text = "You don't have enough gold!"
		_action_timer = 2.0
		_sprite.play("talk")
		queue_redraw()
		return

	if GameState.buy_market_offer(index):
		# Success! Play custom animation
		_action_timer = 1.6
		if randf() < 0.5:
			_sprite.play("cook")
		else:
			_sprite.play("mine")
		_speech_text = "A pleasure doing business!"
	else:
		_speech_text = "Your bag is full, adventurer!"
		_action_timer = 2.0
		_sprite.play("talk")
	queue_redraw()


func _draw() -> void:
	if GameState == null or GameState.market_offers.size() < 6 or size.x < 40.0 or size.y < 40.0:
		return

	# 1. Base dark background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.95))

	# 2. Left Panel (Bazaar Grid) Backdrop
	var left_rect := _left_panel_rect()
	var r := UIScaleScript.px(6.0)
	InventorySlotDrawScript._draw_rounded_fill(self, left_rect, r, Color(0.08, 0.07, 0.10, 0.9))
	InventorySlotDrawScript._draw_rounded_stroke(self, left_rect, r, Color(0.18, 0.16, 0.22, 0.4), 1.0)

	# 3. Right Panel (Merchant Cozy Shop Interior) Backdrop
	var right_rect := _right_panel_rect()
	InventorySlotDrawScript._draw_rounded_fill(self, right_rect, r, Color(0.14, 0.10, 0.08, 0.9))
	InventorySlotDrawScript._draw_rounded_stroke(self, right_rect, r, Color(0.25, 0.18, 0.14, 0.5), 1.0)

	# Draw Header
	_draw_header()
	
	# Draw Left Side slots
	_draw_item_slots()
	
	# Draw Right Side backdrop/counter
	_draw_counter()
	
	# Draw speech bubble
	_draw_speech_bubble()
	
	# Draw Hover Tooltip if applicable
	_draw_hover_tooltip()


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	var fs := UIScaleScript.font_emphasis()
	var align_x := _grid_origin().x

	# Draw Title
	draw_string(
		font,
		Vector2(align_x, UIScaleScript.px(18.0)),
		"THE BAZAAR",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		GOLD_COLOR
	)
	
	# Draw Restock Timer
	var time_left := maxf(0.0, GameState.market_next_refresh_time - Time.get_unix_time_from_system())
	var hours := int(time_left / 3600.0)
	var minutes := int(fmod(time_left, 3600.0) / 60.0)
	var seconds := int(fmod(time_left, 60.0))
	var timer_text := ""
	if hours > 0:
		timer_text = "Restocks in: %dh %dm" % [hours, minutes]
	else:
		timer_text = "Restocks in: %02d:%02d" % [minutes, seconds]
		
	var timer_fs := UIScaleScript.font_caption()
	var timer_col := LABEL_COLOR.darkened(0.1)
	draw_string(
		font,
		Vector2(align_x, UIScaleScript.px(30.0)),
		timer_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		timer_fs,
		timer_col
	)


func _draw_item_slots() -> void:
	var discount := 0.0
	if GameState.hero != null and GameState.hero.has_method("get_talent_shop_discount_modifier"):
		discount = GameState.hero.get_talent_shop_discount_modifier()

	for i in range(6):
		var rect := _slot_rect(i)
		var offer: Dictionary = GameState.market_offers[i]
		var item: Dictionary = offer["item"]
		var bought: bool = offer.get("bought", false)
		var hovered: bool = i == _hover_slot and not bought

		# Highlight slot
		if hovered:
			InventoryHoverScript.draw_slot(self, rect)

		# Draw Slot background
		InventorySlotDrawScript.draw_square(self, rect, hovered)

		# Draw Item Icon
		InventoryIconDrawScript.draw_in_slot(self, rect, item)
		
		# Draw Rarity Frame
		ItemRarityFrameScript.draw_on_slot(self, rect, ItemDataScript.item_rarity(item), float(Time.get_ticks_msec()) / 200.0)

		# Draw Quantity badge for stackable items
		if ItemDataScript.is_stackable(item):
			var count := ItemDataScript.stack_count(item)
			if count > 1:
				var badge := str(count)
				var font := ThemeDB.fallback_font
				var badge_fs := UIScaleScript.font_caption()
				var tw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_fs).x
				draw_string(
					font,
					Vector2(rect.end.x - UIScaleScript.px(2.0) - tw, rect.end.y - UIScaleScript.px(2.0)),
					badge,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					badge_fs,
					TEXT_ACTIVE
				)

		# Draw Sold Out overlay
		if bought:
			# Dark translucent block
			InventorySlotDrawScript._draw_rounded_fill(self, rect, UIScaleScript.px(4.0), Color(0.04, 0.03, 0.05, 0.82))
			# Drawn SOLD text
			var font := ThemeDB.fallback_font
			var sold_fs := UIScaleScript.font_caption()
			var sold_txt := "SOLD"
			var tw := font.get_string_size(sold_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sold_fs).x
			draw_string(
				font,
				Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y * 0.6),
				sold_txt,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				sold_fs,
				Color(0.85, 0.28, 0.22)
			)
		else:
			# Draw Gold price tag
			var price: int = offer.get("price", 0)
			var cost := int(round(price * (1.0 - discount)))
			var price_rect := _price_label_rect(rect)
			var price_txt := "%d" % cost
			var font := ThemeDB.fallback_font
			var price_fs := UIScaleScript.font_caption()
			var tw := font.get_string_size(price_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, price_fs).x
			
			# Draw gold coin icon or g indicator
			draw_string(
				font,
				Vector2(price_rect.position.x + (price_rect.size.x - tw) * 0.5, price_rect.end.y),
				price_txt + "g",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				price_fs,
				GOLD_COLOR
			)


func _draw_counter() -> void:
	var shop := _shopkeeper_rect()
	
	# Draw wood merchant counter table
	var counter_h := UIScaleScript.px(18.0)
	var counter_rect := Rect2(shop.position.x, shop.end.y - counter_h, shop.size.x, counter_h)
	var r := UIScaleScript.px(3.0)
	InventorySlotDrawScript._draw_rounded_fill(self, counter_rect, r, COUNTER_COLOR)
	InventorySlotDrawScript._draw_rounded_stroke(self, counter_rect, r, COUNTER_COLOR.lightened(0.18), 1.0)


func _draw_speech_bubble() -> void:
	var bubble := _bubble_rect()
	var r := UIScaleScript.px(6.0)
	
	# Draw speech bubble frame
	InventorySlotDrawScript._draw_rounded_fill(self, bubble, r, BUBBLE_BG)
	InventorySlotDrawScript._draw_rounded_stroke(self, bubble, r, GOLD_COLOR.darkened(0.25), 1.0)
	
	# Draw little triangle pointing down/left
	var p1 := Vector2(bubble.position.x + UIScaleScript.px(24.0), bubble.end.y)
	var p2 := Vector2(bubble.position.x + UIScaleScript.px(16.0), bubble.end.y + UIScaleScript.px(6.0))
	var p3 := Vector2(bubble.position.x + UIScaleScript.px(28.0), bubble.end.y)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), BUBBLE_BG)
	draw_line(p1, p2, GOLD_COLOR.darkened(0.25), 1.0)
	draw_line(p2, p3, GOLD_COLOR.darkened(0.25), 1.0)

	# Draw Text inside bubble
	var font := ThemeDB.fallback_font
	var fs := UIScaleScript.font_caption()
	
	# Word wrap text if too long
	var words := _speech_text.split(" ")
	var lines: Array[String] = []
	var curr := ""
	var max_w := bubble.size.x - UIScaleScript.px(10.0)
	
	for w in words:
		var test := curr + (" " if not curr.is_empty() else "") + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			lines.append(curr)
			curr = w
		else:
			curr = test
	if not curr.is_empty():
		lines.append(curr)
		
	# Draw line by line centered
	var start_y := bubble.position.y + UIScaleScript.px(12.0)
	if lines.size() == 1:
		start_y = bubble.position.y + bubble.size.y * 0.6
		
	for j in range(lines.size()):
		var line_txt := lines[j]
		var tw := font.get_string_size(line_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := bubble.position.x + (bubble.size.x - tw) * 0.5
		draw_string(
			font,
			Vector2(tx, start_y + float(j) * (fs + UIScaleScript.px(2.0))),
			line_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			TEXT_ACTIVE
		)


func _draw_hover_tooltip() -> void:
	if _hover_slot < 0 or GameState == null or GameState.market_offers.size() < 6:
		return
	
	var offer: Dictionary = GameState.market_offers[_hover_slot]
	var bought: bool = offer.get("bought", false)
	if bought:
		return

	var rect := _slot_rect(_hover_slot)
	var item: Dictionary = offer["item"]
	var discount := 0.0
	if GameState.hero != null and GameState.hero.has_method("get_talent_shop_discount_modifier"):
		discount = GameState.hero.get_talent_shop_discount_modifier()
	var cost := int(round(offer.get("price", 0) * (1.0 - discount)))

	ItemTooltipScript.draw_for_slot(
		self,
		rect,
		item,
		Rect2(Vector2.ZERO, size),
		"Click to buy for %d gold!" % cost,
		GameState.hero.equipment
	)
