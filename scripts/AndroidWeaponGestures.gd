extends RefCounted

# Logical viewport ratios for Android weapon gestures.
const DOWN_HEIGHT = 0.085
const LEFT_HEIGHT = 0.15
const DOMINANCE = 1.7
const MAX_MSEC = 650
const LOW_BAND = 0.80
const SCOPE_RIGHT_START = 0.50
const ENVELOPE_HEIGHT = 0.025
var hold_to_scope = true # Future option boundary; no settings UI in this task.
var scope_index = -1
var scope_weapon = null
var alpha_rects = {}
var scope_hidden_icons = {}
var reload_motion = preload("res://scripts/AndroidReloadMotion.gd").new()

func weapon_region(manager) -> Rect2:
	if manager.player == null or manager.weapon_system == null or not manager.weapon_system.current_weapon:
		return Rect2()
	var base_fov = Player.DEFAULT_WORLD_FOV if manager.weapon_system.is_scoping else -1.0
	var size = manager.get_viewport().get_visible_rect().size
	return sprite_region(manager.player.hud, size, base_fov)

func sprite_region(sprite: Sprite3D, root_size: Vector2, base_fov: float = -1.0) -> Rect2:
	if sprite == null or not sprite.is_visible_in_tree() or sprite.texture == null or sprite.axis != Vector3.AXIS_Z:
		return Rect2()
	var camera = sprite.get_viewport().get_camera_3d()
	if camera == null or sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED or sprite.fixed_size:
		return Rect2() # Authored weapon is camera-owned XY, without billboarding.
	var key = sprite.texture.get_instance_id()
	if not alpha_rects.has(key):
		var image = sprite.texture.get_image()
		if image == null:
			return Rect2()
		if image.is_compressed():
			if image.decompress() != OK:
				return Rect2()
		alpha_rects[key] = Rect2(image.get_used_rect())
	var used: Rect2 = alpha_rects[key]
	if used.size == Vector2.ZERO:
		return Rect2()
	# Mesh vertices include the engine's centered/offset coordinate conventions.
	var mesh = sprite.generate_triangle_mesh()
	if mesh == null:
		return Rect2()
	var faces = mesh.get_faces()
	if faces.is_empty():
		return Rect2()
	var local_rect = Rect2(Vector2(faces[0].x, -faces[0].y), Vector2.ZERO)
	for vertex in faces:
		local_rect = local_rect.expand(Vector2(vertex.x, -vertex.y))
	var texture_size = sprite.texture.get_size()
	var pixels = Rect2(local_rect.position + used.position / texture_size * local_rect.size, used.size / texture_size * local_rect.size)
	if sprite.flip_h:
		pixels.position.x = local_rect.end.x - used.end.x / texture_size.x * local_rect.size.x
	if sprite.flip_v:
		pixels.position.y = local_rect.end.y - used.end.y / texture_size.y * local_rect.size.y
	var points = [pixels.position, Vector2(pixels.end.x, pixels.position.y), pixels.end, Vector2(pixels.position.x, pixels.end.y)]
	var bounds = Rect2()
	var first = true
	var game_size = sprite.get_viewport().get_visible_rect().size
	for point in points:
		var world = sprite.to_global(Vector3(point.x, -point.y, 0))
		if camera.is_position_behind(world):
			return Rect2()
		var screen = camera.unproject_position(world) * root_size / game_size
		if base_fov > 0.0:
			# Keep the weapon-swap envelope at normal FOV while the scope zooms.
			var ratio = tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(base_fov * 0.5))
			screen = root_size * 0.5 + (screen - root_size * 0.5) * ratio
		if first:
			bounds = Rect2(screen, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(screen)
	return bounds.grow(root_size.y * ENVELOPE_HEIGHT).intersection(Rect2(Vector2.ZERO, root_size))

func begin(manager, contact: Dictionary, position: Vector2):
	var size = manager.get_viewport().get_visible_rect().size
	var region = weapon_region(manager)
	contact.weapon_candidate = region.has_area() and region.has_point(position)
	contact.scoped_at_start = manager.weapon_system.is_scoping
	contact.scope_candidate = not contact.scoped_at_start and position.y >= size.y * LOW_BAND and position.x >= size.x * SCOPE_RIGHT_START
	contact.reload_candidate = position.y >= size.y * LOW_BAND and position.x >= size.x * SCOPE_RIGHT_START
	contact.gesture = contact.weapon_candidate or contact.scope_candidate or contact.reload_candidate
	contact.gesture_done = false
	contact.gesture_height = size.y
	# Candidate ownership begins only in root unhandled: HUD/menu GUI wins first.

func decision(contact: Dictionary, position: Vector2, now: int) -> String:
	if contact.gesture_done or now - contact.started > MAX_MSEC:
		return ""
	var displacement = position - contact.origin
	if contact.weapon_candidate and displacement.y >= contact.gesture_height * DOWN_HEIGHT and displacement.y >= absf(displacement.x) * DOMINANCE:
		return "swap"
	if contact.scope_candidate and -displacement.x >= contact.gesture_height * LEFT_HEIGHT and -displacement.x >= absf(displacement.y) * DOMINANCE:
		return "scope"
	if contact.get("reload_candidate", contact.scope_candidate) and displacement.x >= contact.gesture_height * LEFT_HEIGHT and displacement.x >= absf(displacement.y) * DOMINANCE:
		return "reload"
	return ""

func update(manager, contact: Dictionary, event):
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		release(manager, contact.index)
		return
	var action = decision(contact, event.position, Time.get_ticks_msec())
	if action == "":
		if (contact.weapon_candidate or contact.scope_candidate or contact.get("reload_candidate", false)) and not contact.gesture_done:
			var displacement = event.position - contact.origin
			var down_possible = contact.weapon_candidate and displacement.y > 0 and displacement.y >= absf(displacement.x) * DOMINANCE
			var scope_possible = ((contact.scope_candidate and displacement.x < 0) or (contact.get("reload_candidate", contact.scope_candidate) and displacement.x > 0)) and absf(displacement.x) >= absf(displacement.y) * DOMINANCE
			if displacement.length() > manager.ANDROID_LOOK_THRESHOLD and ((not down_possible and not scope_possible) or Time.get_ticks_msec() - contact.started > MAX_MSEC):
				contact.gesture = false
				contact.look_replay = displacement # Replay buffered motion once into normal look.
		return
	contact.gesture_done = true # Recognition or rejected action: one attempt per finger.
	if action == "swap":
		var ws = manager.weapon_system
		if ws.current_weapon and ws.pslot and ws.rslot:
			end_scope(manager)
			var target = "rifle" if ws.current_weapon == ws.pslot else "pistol"
			manager._select_weapon_slot(target)
	elif action == "scope":
		recognize_scope(manager, contact.index)
	elif action == "reload":
		request_reload(manager)

func request_reload(manager):
	var ws = manager.weapon_system
	if ws == null or not ws.current_weapon or ws.is_reloading or manager.player.hud_anim_player.current_animation == "shoot":
		return
	manager.call_reload() # Existing guards, animation, ammo and scope cleanup.

func recognize_scope(manager, index: int):
	var ws = manager.weapon_system
	if ws == null or not ws.current_weapon or not ws.can_scope or ws.is_reloading:
		return
	if scope_index >= 0:
		return # A second scope finger cannot steal the first hold.
	if not hold_to_scope and ws.is_scoping:
		end_scope(manager)
		return
	scope_index = index if hold_to_scope else -2
	scope_weapon = ws.current_weapon
	ws.Scope(true) # Exact RMB optic path (overlay/crosshair/FOV).
	set_scope_icons(manager, true)

func release(manager, index: int):
	if hold_to_scope and scope_index == index:
		end_scope(manager)

func end_scope(manager):
	if scope_index == -1:
		return
	if manager.weapon_system != null and manager.player != null and manager.Gui != null:
		manager.weapon_system.Scope(false)
	set_scope_icons(manager, false)
	scope_index = -1
	scope_weapon = null

func tick(manager):
	if OS.has_feature("android"):
		var ws = manager.weapon_system
		var gravity = Input.get_gravity()
		var allowed = manager._android_gameplay_input_allowed() and ws != null and ws.current_weapon != null
		if allowed:
			allowed = not ws.is_reloading and ws.can_shoot and manager.player.hud_anim_player.current_animation not in ["shoot", "wpn_draw", "wpn_hide"] and gravity.length_squared() > 1.0
		if reload_motion.feed(Time.get_ticks_msec(), Input.get_accelerometer() - gravity, Input.get_gyroscope(), allowed):
			request_reload(manager)
	if manager.Gui is Control:
		configure_scope_ui(manager.Gui)
	if scope_index == -1:
		return
	var ws = manager.weapon_system
	if not manager._android_gameplay_input_allowed() or ws == null or ws.is_reloading or ws.current_weapon != scope_weapon:
		end_scope(manager)
	elif hold_to_scope and not manager._android_touches.has(scope_index):
		end_scope(manager)

func configure_scope_ui(gui: Control):
	var scope = gui.get_node_or_null("GAME/frame/lr_scope") as Control
	if scope == null or scope.has_meta("gesture_input_ready"):
		return
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for decoration in scope.find_children("*", "Control", true, false):
		decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.set_meta("gesture_input_ready", true)

func set_scope_icons(manager, hide_icons: bool):
	if hide_icons:
		if not (manager.Gui is Control):
			return
		for name in ["medkit_icon", "medkit2_icon", "antirad_icon"]:
			var icon = manager.Gui.get_node_or_null("GAME/frame/" + name) as Control
			if icon != null:
				if not scope_hidden_icons.has(icon):
					scope_hidden_icons[icon] = icon.visible
				icon.hide()
	else:
		for icon in scope_hidden_icons:
			if is_instance_valid(icon):
				icon.visible = scope_hidden_icons[icon]
		scope_hidden_icons.clear()
