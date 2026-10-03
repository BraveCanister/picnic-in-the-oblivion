extends Node

# Android-only display adaptation. Camera projection and input stay game-owned.
var frame: Control
var authored_offsets: Dictionary = {}
var modal_bar_offsets: Dictionary = {}
var modal_title_offsets: Dictionary = {}
const MODALS = ["Inventory", "Map", "Statistic", "Pause", "MainMenu", "MainMenu/Options", "Journal", "Dialogue", "Loot", "Trading", "SpawnMenu"]
const BACK_SCREENS = ["Inventory", "Map", "Statistic", "Journal", "Trading"]

func _ready():
	if not OS.has_feature("android"):
		return
	var gui = get_node_or_null("/root/Game/CanvasLayer/GUI")
	while gui == null or not gui.is_node_ready():
		await get_tree().process_frame
		gui = get_node_or_null("/root/Game/CanvasLayer/GUI")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size_changed.connect(_queue_layout)
	_queue_layout()

func _queue_layout():
	call_deferred("_layout_hud")

func _layout_hud():
	var gui = get_node_or_null("/root/Game/CanvasLayer/GUI") as Control
	if gui == null or not gui.is_node_ready():
		await get_tree().process_frame
		_queue_layout()
		return
	frame = gui.get_node("GAME/frame") as Control
	_layout_pause_button(frame)
	var saving_screen = gui.get_node_or_null("SplashScreens/ScreenSavingGame") as Control
	if saving_screen != null:
		var saving_icon = saving_screen.get_node("SplashImage") as AnimatedSprite2D
		saving_icon.position.x = saving_screen.size.x / 2.0
	if authored_offsets.is_empty():
		for child in frame.get_children():
			if child is Control:
				authored_offsets[child] = Vector4(child.offset_left, child.offset_top, child.offset_right, child.offset_bottom)
	var viewport_size = get_tree().root.get_visible_rect().size
	_layout_modals(gui, viewport_size)
	var window_size = Vector2(DisplayServer.window_get_size())
	var safe = Rect2(DisplayServer.get_display_safe_area())
	# Android safe-area coordinates are physical display pixels. With fullscreen
	# EXPAND the root transform has equal scale and no pillarbox translation.
	var uniform_scale = get_tree().root.get_final_transform().get_scale().x
	if uniform_scale <= 0.0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	if not safe.has_area():
		safe = Rect2(Vector2.ZERO, window_size)
	safe = safe.intersection(Rect2(Vector2.ZERO, window_size))
	var start_padding = safe.position / uniform_scale / frame.scale
	var end_padding = (window_size - safe.end) / uniform_scale / frame.scale
	var cutouts = DisplayServer.get_display_cutouts()
	# Preserve the authored uniform pixel-art UI scale, but cover the new viewport.
	frame.offset_right = viewport_size.x / frame.scale.x - gui.size.x
	frame.offset_bottom = viewport_size.y / frame.scale.y - gui.size.y
	for child in authored_offsets:
		var original: Vector4 = authored_offsets[child]
		child.offset_left = original.x
		child.offset_top = original.y
		child.offset_right = original.z
		child.offset_bottom = original.w
		var physical_rect = get_tree().root.get_final_transform() * child.get_global_rect()
		var padding = Vector2.ZERO
		if child.anchor_left == child.anchor_right:
			if child.anchor_left == 0.0:
				if edge_needs_padding(physical_rect, SIDE_LEFT, safe.position.x, window_size, cutouts):
					padding.x = start_padding.x
			elif child.anchor_left == 1.0:
				if edge_needs_padding(physical_rect, SIDE_RIGHT, window_size.x - safe.end.x, window_size, cutouts):
					padding.x = -end_padding.x
		if child.anchor_top == child.anchor_bottom:
			if child.anchor_top == 0.0:
				if edge_needs_padding(physical_rect, SIDE_TOP, safe.position.y, window_size, cutouts):
					padding.y = start_padding.y
			elif child.anchor_top == 1.0:
				if edge_needs_padding(physical_rect, SIDE_BOTTOM, window_size.y - safe.end.y, window_size, cutouts):
					padding.y = -end_padding.y
		child.offset_left = original.x + padding.x
		child.offset_top = original.y + padding.y
		child.offset_right = original.z + padding.x
		child.offset_bottom = original.w + padding.y
	# Center-anchored crosshair/scope retain the full world viewport center.

func _layout_modals(gui: Control, viewport_size: Vector2):
	var design_size = Vector2(1920,1080)
	var origin = (viewport_size - design_size) / 2.0
	for name in MODALS:
		var modal = gui.get_node_or_null("GAME/" + name) as Control
		if modal == null:
			continue
		# Mixed fixed/fractional coordinates were authored against this canvas.
		# Keep content and hit regions together; only its backdrop fills the screen.
		modal.set_anchors_preset(Control.PRESET_CENTER)
		modal.offset_left = -design_size.x / 2.0
		modal.offset_top = -design_size.y / 2.0
		modal.offset_right = design_size.x / 2.0
		modal.offset_bottom = design_size.y / 2.0
		var backdrop = modal.get_node_or_null("FullscreenBackdrop") as ColorRect
		if backdrop == null:
			backdrop = ColorRect.new()
			backdrop.name = "FullscreenBackdrop"
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			backdrop.color = modal.color if modal is ColorRect else Color.BLACK
			modal.add_child(backdrop)
			modal.move_child(backdrop, 0)
		backdrop.position = -origin
		backdrop.size = viewport_size
		if name in ["Dialogue", "Trading"]:
			var outer_frame = modal.get_node("BG") as NinePatchRect
			outer_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
			outer_frame.position = -origin
			outer_frame.size = viewport_size / outer_frame.scale
			outer_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Background patches include opaque pixels, not just a thin line.
			# Keep them below every content/control/bar, as in the authored scene.
			outer_frame.draw_center = true
			outer_frame.z_index = 0
			modal.move_child(outer_frame, 1)
		for bar_name in ["panel_up", "panel_down"]:
			var bar = modal.get_node_or_null(bar_name) as NinePatchRect
			if bar == null:
				continue
			if not modal_bar_offsets.has(bar):
				modal_bar_offsets[bar] = Vector4(bar.offset_left, bar.offset_top, bar.offset_right, bar.offset_bottom)
			bar.anchor_left = 0.0
			bar.anchor_right = 0.0
			bar.offset_left = -origin.x
			bar.offset_right = viewport_size.x / bar.scale.x - origin.x
			var original: Vector4 = modal_bar_offsets[bar]
			var vertical_shift = -origin.y if bar_name == "panel_up" else origin.y
			bar.offset_top = original.y + vertical_shift
			bar.offset_bottom = original.w + vertical_shift
		if name in ["Inventory", "Map", "Pause", "Journal", "Statistic", "MainMenu/Options", "Trading"]:
			var title = modal.get_node("title") as Label
			if not modal_title_offsets.has(title):
				modal_title_offsets[title] = Vector2(title.offset_left, title.offset_right)
				if name == "Inventory": modal_title_offsets[title] = Vector2(36,296)
				if name == "Map": modal_title_offsets[title] = Vector2(32,300)
			title.anchor_left = 0.0
			title.anchor_right = 0.0
			title.offset_left = modal_title_offsets[title].x - origin.x
			title.offset_right = modal_title_offsets[title].y - origin.x
			if name in ["Inventory", "Map"]: title.uppercase = true
		if name in BACK_SCREENS:
			var old_tip = modal.get_node_or_null("back_tip")
			if old_tip == null: old_tip = modal.get_node_or_null("back")
			if old_tip != null: old_tip.hide()
			var button = modal.get_node_or_null("AndroidBack") as Button
			if button == null:
				button = Button.new()
				button.name = "AndroidBack"
				button.text = "BACK"
				button.theme = modal.get_node("title").theme
				button.add_theme_font_size_override("font_size", 32)
				for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
					button.add_theme_color_override(color_name, Color(0.933333,0.615686,0.192157))
				button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var style = StyleBoxTexture.new()
				style.texture = preload("res://assets/ui/android_back.png")
				# Draw the complete supplied sprite at a uniform integer scale.
				# Nine-slicing would give its border and interior different pixel sizes.
				for state in ["normal", "hover", "pressed", "focus"]:
					button.add_theme_stylebox_override(state, style)
				button.z_index = 2
				button.pressed.connect(_on_back_pressed)
				modal.add_child(button)
			var safe = Rect2(DisplayServer.get_display_safe_area())
			var physical_size = Vector2(DisplayServer.window_get_size())
			if not safe.has_area(): safe = Rect2(Vector2.ZERO, physical_size)
			var scale_factor = get_tree().root.get_final_transform().get_scale().x
			var right_margin = maxf(20.0, (physical_size.x - safe.end.x) / scale_factor) + 24.0
			var bottom_margin = maxf(20.0, (physical_size.y - safe.end.y) / scale_factor)
			button.size = Vector2(60,19) * 4.0
			button.position = viewport_size - origin - button.size - Vector2(right_margin,bottom_margin)

func _layout_pause_button(hud: Control):
	if hud.has_node("AndroidPause"): return
	var button = TextureButton.new()
	button.name = "AndroidPause"
	button.texture_normal = preload("res://assets/ui/ui_btn_round.png")
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Both sprites are 15x15; inherit the same uniform HUD scale as casual_icon.
	button.offset_left = -22
	button.offset_right = -7
	button.offset_top = -22
	button.offset_bottom = -7
	button.pressed.connect(_on_back_pressed)
	hud.add_child(button)

func _on_back_pressed():
	# The real player handler owns Android Back's pause/close/return behavior.
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and is_instance_valid(gm.player):
		gm.PlaySFXLoaded(gm.sfx_manager_json["on_pause_resume_click"])
		gm.player.notification(NOTIFICATION_WM_GO_BACK_REQUEST)

static func edge_needs_padding(rect: Rect2, side: int, inset: float, window_size: Vector2, cutouts: Array) -> bool:
	# A cutout halfway down an edge need not inset a control at its clear corner.
	# Preserve full safe-area padding when no exact cutout is known, or when a
	# system-area inset extends farther into the window than the cutout.
	var cutout_inset = 0.0
	var overlaps = false
	for value in cutouts:
		var cutout = Rect2(value)
		var extent = 0.0
		match side:
			SIDE_LEFT:
				if cutout.position.x <= 0.0: extent = cutout.end.x
			SIDE_RIGHT:
				if cutout.end.x >= window_size.x: extent = window_size.x - cutout.position.x
			SIDE_TOP:
				if cutout.position.y <= 0.0: extent = cutout.end.y
			SIDE_BOTTOM:
				if cutout.end.y >= window_size.y: extent = window_size.y - cutout.position.y
		if extent > 0.0:
			cutout_inset = maxf(cutout_inset, extent)
			overlaps = overlaps or rect.intersects(cutout, true)
	return cutout_inset <= 0.0 or inset > cutout_inset + 1.0 or overlaps
