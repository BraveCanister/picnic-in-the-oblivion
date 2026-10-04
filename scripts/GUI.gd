extends Control
class_name GUI
@onready var sv_effects_subviewport : SubViewportContainer = $"../../sv"
@onready var subviewport : SubViewport = $"../../sv/EffectDither"
@onready var frame : Control = $GAME/frame
@onready var hint: Label = $GAME/frame/screen_hint
@onready var ammo_clip : Label = $GAME/frame/ammo_frame/ammo_clip
@onready var ammo_all : Label = $GAME/frame/ammo_frame/ammo_all
@onready var belt_0_icon : TextureRect = $GAME/frame/ammo_frame/belt_0
@onready var belt_1_icon : TextureRect = $GAME/frame/ammo_frame/belt_1
@onready var belt_2_icon : TextureRect = $GAME/frame/ammo_frame/belt_2
@onready var belt_3_icon : TextureRect = $GAME/frame/ammo_frame/belt_3
@onready var weapon_icon : TextureRect = $GAME/frame/ammo_frame/weapon_icon
@onready var health_bar : TextureProgressBar = $GAME/frame/hp_bar
@onready var rad_bar : TextureProgressBar = $GAME/frame/rad_bar_frame/rad_bar
@onready var health_bar_inv : TextureProgressBar = $GAME/Inventory/hp_bar_inv
@onready var crosshair : TextureRect = $GAME/frame/cross
@onready var fps : Label = $GAME/frame/fps
@onready var pos : Label = $GAME/frame/pos
@onready var rot : Label = $GAME/frame/rot
@onready var camera_rotations : Label = $GAME/frame/rot2
@onready var pda_icon : TextureRect = $GAME/frame/pda_icon
@onready var rad_icon : TextureRect = $GAME/frame/radiation_icon
@onready var save_icon : TextureRect = $GAME/frame/save_icon
@onready var timers_text : Label = $GAME/frame/timers
@onready var message : Label = $GAME/frame/message
@export var loading_screen : Control
@onready var scope : TextureRect = $GAME/frame/lr_scope
@onready var main_menu : MainMenu = $GAME/MainMenu
@onready var damage_l : TextureRect = $GAME/frame/DamageLeft
@onready var damage_r : TextureRect = $GAME/frame/DamageRight
@onready var medkit_count : Label = $GAME/frame/medkit_icon/medkit_count
@onready var medkit_army_count : Label = $GAME/frame/medkit2_icon/medkit2_count
@onready var antirad_count : Label = $GAME/frame/antirad_icon/antirad_count
@onready var medkit_icon : TextureRect = $GAME/frame/medkit_icon
@onready var medkit_army_icon : TextureRect = $GAME/frame/medkit2_icon
@onready var antirad_icon : TextureRect = $GAME/frame/antirad_icon
@onready var weapon_hud : Sprite3D = $"../../sv/EffectDither/World/Player/Head/PlayerCamera/WeaponPresentation/HUD"
@onready var casual_icon = $GAME/frame/casual_icon
@onready var press_f_text : Label = $GAME/frame/press_f
@onready var death_screen = $DeathScreen
@onready var final_image = $GAME/FinalImage

@onready var game_gui_root : Control = $GAME
@onready var vignette : TextureRect = $GAME/Vignette

@onready var InventoryWindow : Inventory = $GAME/Inventory as Inventory
@onready var InventoryMoney : Label = $GAME/Inventory/money
@onready var JournalWindow : Journal = $GAME/Journal as Journal
@onready var PauseWindow : PauseMenu = $GAME/Pause as PauseMenu
@onready var DialogueWindow : DialogueSystem = $GAME/Dialogue as DialogueSystem
@onready var TradingWindow : TradingSystem = $GAME/Trading as TradingSystem
@onready var MapWindow : Map = $GAME/Map as Map
@onready var ConsoleWindow : Console = $GAME/Console as Console
@onready var TipWindow : Control = $GAME/HelpMessage
@onready var SkillWindow : SkillSystem = $GAME/Statistic as SkillSystem
@onready var IntroWindow : Control = $GAME/IntroMessage
@onready var MainMenuWindow : MainMenu = $GAME/MainMenu as MainMenu
@onready var SpawnMenuWindow = $GAME/SpawnMenu

@onready var GUI_ROOT : Control = $"."
@onready var GUI_GAME : Control = $GAME

@export var translation_labels : Array[Label] = []
@export var translation_buttons : Array[Button] = []
@export var textures_loader_elements = []

@onready var Loot : LootWindow = $GAME/Loot
@onready var TradingMessage = $GAME/TradingMessage

var is_tutorial_tip = false
var belt_ui : Array

# timer for message show
var message_showtime = 1.5
@onready var message_timer = Timer.new()
var intro_scroll_timer = 1.0
var messages_queue = []
var _message_tween: Tween
var _message_layout: Array = []
var _confirmation_accept: Callable
var _confirmation_cancel: Callable
var _confirmation_cancel_button: Button
var _confirmation_layout: Dictionary = {}

var splash_timer = 3.0
var fade_time = 1.0

var viewport_init_size = Vector2()

var last_scale = 0
var _radio_pda_active = false
var _radio_use_pending = false
var _radio_started_blink = false
var _radio_pda_texture : Texture2D
var _normal_pda_texture : Texture2D
var _normal_pda_visible = false
var _normal_pda_enabled = false
var _normal_pda_modulate : Color
# templates of crosshair textures for quick changing
var crosshair_gun_texture
var crosshair_use_texture
var crosshair_lock_texture
var crosshair_hit_texture
var crosshair_headshot_texture

signal on_gui_init_finished

# Called when the node enters the scene tree for the first time.
func _ready():
	var dynamic_font_regular : FontFile
	var dynamic_font_bold : FontFile
	
	var regular_font : Theme = load("res://themes/regular_font.tres") as Theme
	var bold_font : Theme = load("res://themes/bold_font.tres") as Theme
	
	if OS.has_feature("android"):
		var packaged_fonts : Array[FontFile] = []
		for path in ["res://assets/fonts/SM3DRegular.ttf", "res://assets/fonts/SM3DBold.ttf"]:
			var packaged_font = ResourceLoader.load(path, "FontFile") as FontFile
			if packaged_font == null or packaged_font.data.is_empty() or not packaged_font.has_char(65):
				push_error("[GUI Fonts]: Missing or unusable packaged FontFile: " + path)
				return
			var runtime_font = packaged_font.duplicate() as FontFile
			if runtime_font == null:
				push_error("[GUI Fonts]: Failed to duplicate packaged FontFile: " + path)
				return
			packaged_fonts.append(runtime_font)
		dynamic_font_regular = packaged_fonts[0]
		dynamic_font_bold = packaged_fonts[1]
	else:
		dynamic_font_regular = FontFile.new()
		dynamic_font_bold = FontFile.new()
		dynamic_font_regular.load_dynamic_font(GameManager.app_dir+"assets/fonts/SM3DRegular.ttf")
		dynamic_font_bold.load_dynamic_font(GameManager.app_dir+"assets/fonts/SM3DBold.ttf")
	
	dynamic_font_regular.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	dynamic_font_bold.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	
	dynamic_font_regular.oversampling = false
	dynamic_font_bold.oversampling = false
	
	regular_font.set_font("font","Label",dynamic_font_regular)
	regular_font.set_font("font","Button",dynamic_font_regular)
	regular_font.set_font("font","LineEdit",dynamic_font_regular)
	
	bold_font.set_font("font","Label",dynamic_font_bold)
	bold_font.set_font("font","Button",dynamic_font_bold)
	bold_font.set_font("font","LineEdit",dynamic_font_bold)
	bold_font.set_font("bold_font","RichTextLabel",dynamic_font_bold)
	bold_font.set_font("normal_font","RichTextLabel",dynamic_font_regular)
	if OS.has_feature("android"):
		print("[GUI Fonts]: Packaged regular/bold FontFile copies configured and assigned.")
	#get_tree().root.content_scale_factor = 1.5
	message_timer.wait_time = message_showtime
	message_timer.one_shot = true
	message_timer.name = "message_queue_timer"
	message_timer.timeout.connect(on_message_timer_timeout)
	add_child(message_timer)
	TradingMessage.visibility_changed.connect(func():
		if not TradingMessage.visible:
			CancelConfirmation())
	resize_cursor()
	get_tree().root.size_changed.connect(resize_cursor)
	await get_tree().create_timer(0.1).timeout
	belt_ui = [belt_0_icon, belt_1_icon, belt_2_icon, belt_3_icon]
	crosshair_gun_texture = Utility.load_external_texture("assets/ui/crosshair_weapon.png")
	crosshair_use_texture = Utility.load_external_texture("assets/ui/crosshair.png")
	crosshair_lock_texture = Utility.load_external_texture("assets/ui/lock.png")
	crosshair_hit_texture = Utility.load_external_texture("assets/ui/crosshair_weapon_hit.png")
	crosshair_headshot_texture = Utility.load_external_texture("assets/ui/crosshair_weapon_hit_headshot.png")
	rot.text = ""
	pos.text = ""
	
	search_ui_text_nodes(self)
	
	await get_tree().process_frame
	
	search_buttons_text_nodes(self)
	
	await get_tree().process_frame
	
	search_image_nodes(self)
	#print(textures_loader_elements.size())
	# textures reloading
	for texture in textures_loader_elements:
		if texture.texture != null and texture.texture.resource_path.contains("ui/"):
			var old_tex_name = texture.texture.resource_path.split('ui/',false)[1]
			#print("Reloaded texture for: %s" % old_tex_name)
			texture.texture = Utility.load_external_texture("assets/ui/"+old_tex_name)
	#self.reparent(get_node("root/Game/ViewPorts/MainGame/World/CanvasLayer"),true)
	
	if OS.has_feature("mobile"):
		medkit_icon.show()
		medkit_army_icon.show()
		antirad_icon.show()
		
	if OS.has_feature("windows") or OS.has_feature("macos"):
		medkit_icon.hide()
		medkit_army_icon.hide()
		antirad_icon.hide()

func on_message_timer_timeout():
	var fade: float = messages_queue[0]["fade"]
	if fade > 0.0:
		_message_tween = create_tween()
		_message_tween.tween_property(message, "modulate:a", 0.0, fade)
		_message_tween.tween_callback(_advance_message)
	else:
		_advance_message()

func _advance_message():
	messages_queue.pop_front()
	_restore_message_layout()
	message.modulate.a = 1.0
	if messages_queue.is_empty():
		message.text = ""
	else:
		_show_queued_message()

func _restore_message_layout():
	if _message_layout.is_empty():
		return
	message.anchor_left = _message_layout[0]
	message.anchor_top = _message_layout[1]
	message.anchor_right = _message_layout[2]
	message.anchor_bottom = _message_layout[3]
	message.offset_left = _message_layout[4]
	message.offset_top = _message_layout[5]
	message.offset_right = _message_layout[6]
	message.offset_bottom = _message_layout[7]
	message.horizontal_alignment = _message_layout[8]
	_message_layout.clear()

func _show_queued_message():
	var entry = messages_queue[0]
	message.text = entry["text"]
	if entry["top"]:
		_message_layout = [message.anchor_left, message.anchor_top, message.anchor_right,
			message.anchor_bottom, message.offset_left, message.offset_top,
			message.offset_right, message.offset_bottom, message.horizontal_alignment]
		message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		# The HUD frame is scaled fivefold; this label is scaled by one half.
		message.offset_left = 8.0
		message.offset_top = 12.0
		message.offset_right = message.get_parent().size.x - 8.0
		message.offset_bottom = 60.0
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_timer.start(entry["duration"])
	
func resize_cursor():
	var cursor_compressed_image : Texture2D = Utility.load_external_texture("assets/ui/cursor.png")
	var original_cursor = cursor_compressed_image.get_image()
	var original_cursor_size = cursor_compressed_image.get_size()
	var original_width = ProjectSettings.get_setting("display/window/size/viewport_width") as int
	var screen_scale = int(float(DisplayServer.window_get_size().x)/float(original_width))
	var new_size = Vector2i(screen_scale*original_cursor_size*2)
	
	if last_scale != screen_scale:
		last_scale = screen_scale
		var cursor = Image.new()
		cursor.copy_from(original_cursor)
		#print(new_size)
		cursor.resize(new_size.x,new_size.y,Image.INTERPOLATE_NEAREST)
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cursor))
	
func search_image_nodes(obj):
	var arr = []
	for texture_rect in obj.get_children():
		#print(texture_rect.name)
		if texture_rect is TextureRect and not arr.has(texture_rect):
			#xprint(texture_rect.name)
			arr.append(texture_rect)
		if texture_rect.get_child_count() > 0:
			search_image_nodes(texture_rect)
	for t in arr:
		textures_loader_elements.append(t)

func search_ui_text_nodes(obj):
	var arr = []
	for translation_label in obj.get_children():
		#print(texture_rect.name)
		if translation_label is UI_TEXT and translation_label is Label and not arr.has(translation_label):
			#print(translation_label.name)
			arr.append(translation_label)
		if translation_label.get_child_count() > 0:
			search_ui_text_nodes(translation_label)
	for t in arr:
		#print(t.name + " " + str(t.has_theme_font_override("font")))
		if not translation_labels.has(t):
			translation_labels.append(t)
			
func search_buttons_text_nodes(obj):
	var arr = []
	for translation_button in obj.get_children():
		if translation_button is UI_TEXT and translation_button is Button and not arr.has(translation_button):
			#print(translation_button.name)
			arr.append(translation_button)
		if translation_button.get_child_count() > 0:
			search_buttons_text_nodes(translation_button)
	for t in arr:
		if not translation_buttons.has(t):
			translation_buttons.append(t)

func SetWeaponHUD(state : bool):
	if state:
		weapon_hud.show()
	else:
		weapon_hud.hide()

func SetHUD(state : bool):
	if state:
		frame.show()
	else:
		frame.hide()

func SetCausalIcon(state : bool):
	casual_icon.visible = state

func UpdateHUDAmounts():
	medkit_count.text = str(InventoryWindow.GetItemsTypeAmount("medkit"))
	medkit_army_count.text = str(InventoryWindow.GetItemsTypeAmount("medkit_army"))
	antirad_count.text = str(InventoryWindow.GetItemsTypeAmount("antirad"))
	
func _process(_delta):
	
	if vignette.material.get_shader_parameter("vignette_opacity") > 0.15:
		var opacity = vignette.material.get_shader_parameter("vignette_opacity")
		vignette.material.set_shader_parameter("vignette_opacity",opacity - _delta * 3)
	
	UpdateHUDAmounts()
	_update_android_radio_pda()
			
	if IntroWindow.visible:
		intro_scroll_timer -= _delta * 1
		if intro_scroll_timer <= 0:
			intro_scroll_timer = 0
			$GAME/IntroMessage/ScrollContainer.scroll_vertical += 8
			intro_scroll_timer = 1.0
	
	if GameManager.player and GameManager.player.debug_info:
		$GAME/frame/debug_panel.visible = true
		var pos_x = "%.2f" % GameManager.player.position.x
		var pos_y = "%.2f" % GameManager.player.position.y
		var pos_z = "%.2f" % GameManager.player.position.z
		var rot_x = "%.2f" % GameManager.player.rotation_degrees.x
		var rot_y = "%.2f" % GameManager.player.rotation_degrees.y
		var rot_z = "%.2f" % GameManager.player.rotation_degrees.z
		pos.text = "X: %s\nY: %s\nZ: %s" % [pos_x,pos_y,pos_z]
		rot.text = "(%s, %s, %s)" % [rot_x, rot_y, rot_z]
		$GAME/editor_mode/camera_pos.text = "(%s, %s, %s)" % [pos_x,pos_y,pos_z]
		
		camera_rotations.text = "PlayerCamera: %s\nPlayerHead: %s\nFakeHead: %s" % [str(GameManager.player.PlayerCamera.rotation_degrees),str(GameManager.player.PlayerHead.rotation_degrees),str(GameManager.player.FakeHead.rotation_degrees)]

func PressF(state : bool):
	if state:
		if OS.has_feature("windows") or OS.has_feature("macos"):
			press_f_text.text = "%s (%s)" % [Lang.translate("press"), Lang.translate_string("[key_action]use[/key_action]")]
		if OS.has_feature("mobile"):
			press_f_text.text = "%s" % Lang.translate("press.mobile")
	else:
		press_f_text.text = ""
func ShowMessage(text, duration: float = 1.5, fade: float = 0.0, at_top: bool = false):
	# Preserve the original first-message dwell for existing notifications.
	if messages_queue.is_empty() and not at_top:
		duration += message_showtime
	messages_queue.push_back({"text": text, "duration": duration, "fade": fade, "top": at_top})
	if messages_queue.size() == 1:
		_show_queued_message()

func ShowMissionComplete():
	ShowMessage(Lang.translate("mission.complete"), 4.5, 0.5, true)
	var sfx = GameManager.player.get_node("Head/PlayerCamera/sfx1").duplicate() as AudioStreamPlayer
	GameManager.player.get_node("Head/PlayerCamera/Sounds").add_child(sfx)
	sfx.stream = preload("res://assets/sounds/pda_objective.mp3")
	sfx.volume_db = -4.0
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

func ShowConfirmation(text: String, accept: Callable, cancel: Callable):
	ShowTradingMessage(text)
	# Cover AndroidBack (z=2) along with the rest of the character menu.
	TradingMessage.z_index = 3
	# Temporarily adapt the existing popup pieces; other messages retain their layout.
	for node in [TradingMessage, $GAME/TradingMessage/BG2, $GAME/TradingMessage/BGBlack, $GAME/TradingMessage/panel_down, $GAME/TradingMessage/infoText]:
		var state: Dictionary = {}
		var properties = ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
			"offset_left", "offset_top", "offset_right", "offset_bottom", "scale", "pivot_offset", "visible"]
		if node is NinePatchRect:
			properties.append_array(["texture", "region_rect", "patch_margin_left",
				"patch_margin_top", "patch_margin_right", "patch_margin_bottom"])
		for property in properties:
			state[property] = node.get(property)
		_confirmation_layout[node] = state
	var frame: NinePatchRect = $GAME/TradingMessage/BG2
	frame.texture = preload("res://assets/ui/dialogue_ramka.png")
	frame.region_rect = Rect2(0, 0, 240, 317)
	frame.patch_margin_left = 4
	frame.patch_margin_top = 8
	frame.patch_margin_right = 72
	frame.patch_margin_bottom = 2
	frame.scale = Vector2(4, 4)
	frame.offset_left = -400
	frame.offset_top = -180
	frame.offset_right = -200
	frame.offset_bottom = -90
	$GAME/TradingMessage/BGBlack.hide()
	var bar: NinePatchRect = $GAME/TradingMessage/panel_down
	bar.anchor_left = 0.5
	bar.anchor_top = 0.5
	bar.anchor_right = 0.5
	bar.anchor_bottom = 0.5
	bar.offset_left = -392
	bar.offset_top = 60
	bar.offset_right = -196
	bar.offset_bottom = 88
	bar.scale = Vector2(4, 4)
	bar.show()
	var info: RichTextLabel = $GAME/TradingMessage/infoText
	info.offset_left = -360
	info.offset_top = -88
	info.offset_right = 360
	info.offset_bottom = 40
	info.text = "[center]" + text.replace("\n", "\n[font_size=12] [/font_size]\n") + "[/center]"
	_confirmation_accept = accept
	_confirmation_cancel = cancel
	var ok: Button = $GAME/TradingMessage/ButtonTradingMsgOk
	if _confirmation_cancel_button == null:
		_confirmation_cancel_button = ok.duplicate(0) as Button
		_confirmation_cancel_button.name = "ConfirmationCancel"
		TradingMessage.add_child(_confirmation_cancel_button)
		_confirmation_cancel_button.pressed.connect(CancelConfirmation)
	for button in [ok, _confirmation_cancel_button]:
		var background = button.get_node_or_null("ConfirmationBackground") as TextureRect
		if background == null:
			background = TextureRect.new()
			background.name = "ConfirmationBackground"
			background.texture = preload("res://assets/ui/btn2.png")
			background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Match the existing BACK sprite and frame at fourfold source scale.
			background.scale = Vector2(4, 4)
			background.show_behind_parent = true
			background.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(background)
		background.show()
		background.flip_v = button == ok
		button.add_theme_font_size_override("font_size", 18)
		button.anchor_top = 0.5
		button.anchor_bottom = 0.5
		button.offset_top = 80.0
		button.offset_bottom = 156.0
	ok.text = Lang.translate("confirm").to_upper()
	ok.offset_left = -360.0
	ok.offset_right = -120.0
	_confirmation_cancel_button.text = Lang.translate("cancel").to_upper()
	_confirmation_cancel_button.offset_left = 120.0
	_confirmation_cancel_button.offset_right = 360.0
	_confirmation_cancel_button.show()
	$GAME/TradingMessage/BG3.hide()
	# Scale text, artwork and hit regions together around the popup's center.
	TradingMessage.pivot_offset = TradingMessage.size / 2.0
	TradingMessage.scale = Vector2(1.2, 1.2)

func _clear_confirmation():
	TradingMessage.z_index = 0
	for node in _confirmation_layout:
		for property in _confirmation_layout[node]:
			node.set(property, _confirmation_layout[node][property])
	_confirmation_layout.clear()
	_confirmation_accept = Callable()
	_confirmation_cancel = Callable()
	_confirmation_cancel_button.hide()
	$GAME/TradingMessage/ButtonTradingMsgOk/ConfirmationBackground.hide()
	$GAME/TradingMessage/ButtonTradingMsgOk.text = "OK"
	$GAME/TradingMessage/ButtonTradingMsgOk.add_theme_font_size_override("font_size", 28)
	$GAME/TradingMessage/ButtonTradingMsgOk.anchor_top = 1.0
	$GAME/TradingMessage/ButtonTradingMsgOk.anchor_bottom = 1.0
	$GAME/TradingMessage/ButtonTradingMsgOk.offset_left = -416.0
	$GAME/TradingMessage/ButtonTradingMsgOk.offset_top = -344.0
	$GAME/TradingMessage/ButtonTradingMsgOk.offset_bottom = -265.0
	$GAME/TradingMessage/ButtonTradingMsgOk.offset_right = 416.0
	TradingMessage.hide()

func CancelConfirmation():
	if not _confirmation_cancel.is_valid():
		return
	var cancel = _confirmation_cancel
	_clear_confirmation()
	cancel.call()

func ShowTradingMessage(text,type = "classic"):
	CancelConfirmation()
	match type:
		"classic":
			$GAME/TradingMessage/BG2.show()
			$GAME/TradingMessage/BGBlack.show()
			TradingMessage.show()
			
			if TradingWindow.visible:
				TradingWindow._update_bags()
		"hint":
			$GAME/TradingMessage/BG2.hide()
			$GAME/TradingMessage/BGBlack.hide()
			if OS.has_feature("android"):
				# On Android, the original 76 + 98 slices exceed the 145px source region.
				$GAME/TradingMessage/BG3.patch_margin_left = 36
				$GAME/TradingMessage/BG3.patch_margin_right = 36
			$GAME/TradingMessage/BG3.show()
			TradingMessage.show()
	$GAME/TradingMessage/infoText.text = text

# Find UI element in GUI/GAME node
func GetUIElement(node):
	return get_node("GAME/"+node)

# Find UI element in editor node
func GetEditorElement(node):
	return get_node("GAME/editor_mode/"+node)

func _on_bug_button_ok_pressed():
	get_tree().quit()

# show crosshair hint
func show_hint(text):
	hint.text = text
# clear crosshair hint
func clear_hint():
	hint.text = ""

func UpdateTexts():
	for lang_label in translation_labels:
		if lang_label != null and lang_label.text != "":
			if lang_label.get("text_id"):
				lang_label.UpdateLanguage()
	# translation for buttons
	for lang_button in translation_buttons:
		if lang_button != null and lang_button.text != "":
			if lang_button.get("text_id"):
				lang_button.text = Lang.translate(lang_button.text_id)
			
func ShowIntroMessage():
	IntroWindow.show()
	GameManager.pause = true
	if GameManager.main_menu == false:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func HideIntroMessage():
	if GameManager.current_level != null:
		if not death_screen.visible and not MainMenuWindow.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.pause = false
	IntroWindow.hide()
	
func ShowIntroMessageCustom(text : String):
	IntroWindow.get_node("ScrollContainer/title").text = Lang.translate(text)
	ShowIntroMessage()

func LoadHelpTipJson(id : String):
	var tips = Utility.read_json("assets/gameplay/help_tips.json")
	for tip in tips:
		if tip["id"] == id:
			_ShowHelpTipMessage(tip["topic_img"],tip["text"],tip["topic_img_size"] if "topic_img_size" in tip else 256)
			break
	
func _ShowHelpTipMessage(topic_img_path : String, text : String,img_size=256):
	if not GameManager.pause:
		GameManager.pause = true
		is_tutorial_tip = true
		ShowTradingMessage("[center][img=%d]assets/ui/%s[/img][/center]\n \n \n%s" % [img_size,topic_img_path, Lang.translate(text)],"hint")
		#$GAME/HelpMessage/infoText.text = "[center][img=%d]assets/ui/%s[/img][/center]\n \n \n%s" % [img_size,topic_img_path, Lang.translate(text)]
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#$GAME/HelpMessage.show()
	
func ShowRad():
	$GAME/frame/rad_bar_frame.show()
	
func HideRad():
	$GAME/frame/rad_bar_frame.hide()

# Show object list on level (for editor mode)
func show_editor_object_list(list):
	var obj_list = $GAME/editor_mode/lvl_objects_selector/ScrollContainer/ObjectList
	var obj = preload("res://engine_objects/editor_list_object.tscn")
	obj_list.get_children().clear()
	
	for ed_obj in list:
		var new_obj = obj.instantiate()
		new_obj.text = str(ed_obj.name)
		obj_list.add_child(new_obj)
	$GAME/editor_mode/lvl_objects_selector.show()

func _on_close_selector_pressed():
	$GAME/editor_mode/lvl_objects_selector.hide()

func _on_light_mode_pressed():
	GameManager.World.get_node("SceneLight").visible = !GameManager.World.get_node("SceneLight").visible

func _on_button_ok_pressed():
	$GAME/HelpMessage/infoText.text = ""
	$GAME/HelpMessage.hide()
	GameManager.PlaySFXLoaded(GameManager.sfx_manager_json["on_msg_btn_click"])
	if not death_screen.visible and not MainMenuWindow.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.pause = false
	await get_tree().create_timer(0.1).timeout
	# randomly pick enemy and allow him permission to attack player
	if GameManager.player.current_eyezone != null and GameManager.player.current_eyezone.enemies.size() > 0:
		for hostile in GameManager.player.current_eyezone.enemies:
			if hostile.can_attack:
				return
		
		var ai = GameManager.player.current_eyezone.enemies.pick_random()
		ai.delay_timer = 0.5
		ai.can_attack = true

func set_dithering(state:bool = true):
	sv_effects_subviewport.material.set_shader_parameter("dithering", state)

func _on_ready():
	# translation for labels
	for lang_label in translation_labels:
		if lang_label != null and lang_label.text != "":
			if lang_label.get("text_id"):
				lang_label.text = Lang.translate(lang_label.text_id)
				lang_label.uppercase = true
	# translation for buttons
	for lang_button in translation_buttons:
		if lang_button != null and lang_button.text != "":
			if lang_button.get("text_id"):
				lang_button.text = Lang.translate(lang_button.text_id)
				lang_button.text = lang_button.text.to_upper()
	await get_tree().process_frame
	on_gui_init_finished.emit()

func _on_button_intro_ok_pressed():
	HideIntroMessage()
	GameManager.PlaySFXLoaded(GameManager.sfx_manager_json["on_msg_btn_click"])


func _on_button_trading_msg_ok_pressed():
	if _confirmation_accept.is_valid():
		var accept = _confirmation_accept
		_clear_confirmation()
		accept.call()
		return
	TradingMessage.hide()
	GameManager.on_trading_message_ok.emit()
	GameManager.PlaySFXLoaded(GameManager.sfx_manager_json["on_msg_btn_click"])
	if is_tutorial_tip:
		GameManager.pause = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		is_tutorial_tip = false


func _on_help_message_visibility_changed():
	if MainMenuWindow.visible:
		if $GAME/HelpMessage.visible:
			$GAME/HelpMessage/infoText.text = ""
			$GAME/HelpMessage.hide()
			GameManager.pause = false



func _android_radio_item() -> item:
	if not OS.has_feature("android") or _radio_use_pending:
		return null
	if not GameManager.is_game_ready or GameManager.current_level == null:
		return null
	if not GameManager.HasQuest("quest_talk_radio") or GameManager.HasEventKey("radio.start.quest"):
		return null
	var player = GameManager.player
	if GameManager.main_menu or GameManager.pause or player.is_dead or player.is_cutscene:
		return null
	if player.waypoint_walk or not player.can_use or not player.can_look or GameManager.weapon_system.is_reloading:
		return null
	if GameManager.GameProcess.cutscene_camera_movement or GameManager.GameProcess.cutscene_camera_rotation:
		return null
	if not frame.is_visible_in_tree():
		return null
	for window in [DialogueWindow, PauseWindow, MainMenuWindow, InventoryWindow, JournalWindow,
		MapWindow, SkillWindow, TradingWindow, ConsoleWindow, SpawnMenuWindow, IntroWindow,
		TipWindow, TradingMessage, loading_screen, final_image, death_screen]:
		if window.visible:
			return null
	return InventoryWindow.Find("radio_first")

func _update_android_radio_pda():
	if not OS.has_feature("android"):
		return
	if _android_radio_item() != null:
		if _radio_pda_texture == null:
			_radio_pda_texture = ResourceLoader.load("res://assets/ui/items/hand_radio.png", "Texture2D") as Texture2D
		if _radio_pda_texture == null:
			return
		if not _radio_pda_active:
			_normal_pda_texture = pda_icon.texture
			_normal_pda_visible = pda_icon.visible
			_normal_pda_enabled = GameManager.pda_enabled
			_normal_pda_modulate = pda_icon.modulate
			_radio_started_blink = not pda_icon.get_child(0).is_playing()
			if _radio_started_blink:
				pda_icon.get_child(0).play("blink")
			_radio_pda_active = true
		pda_icon.texture = _radio_pda_texture
		pda_icon.show()
	elif _radio_pda_active:
		pda_icon.texture = _normal_pda_texture
		# Preserve a story-driven ShowPDA change made during the temporary role.
		if GameManager.pda_enabled == _normal_pda_enabled:
			pda_icon.visible = _normal_pda_visible
			if _radio_started_blink:
				pda_icon.get_child(0).stop()
				pda_icon.modulate = _normal_pda_modulate
		_radio_started_blink = false
		_radio_pda_active = false

func _on_pda_icon_gui_input(event):
	if event is InputEventScreenTouch:
		if OS.has_feature("android") and event.is_pressed():
			# Radio must never fall through to Map while this quest is waiting.
			if GameManager.HasQuest("quest_talk_radio") and not GameManager.HasEventKey("radio.start.quest"):
				var radio_item = _android_radio_item()
				if radio_item != null:
					_radio_use_pending = true
					await radio_item.UseItem()
					_radio_use_pending = false
				return
		if event.is_pressed() and GameManager.pda_enabled:
			GameManager.pause = true
			MapWindow.Open()
			MapWindow.is_open_from_pause = false
			return


func _on_radiation_icon_gui_input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			#print("rad tapped")
			var rad = InventoryWindow.Find("antirad") as item
			if rad:
				rad.UseItem()
				return


func _on_medkit_icon_gui_input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			#print("rad tapped")
			var med = InventoryWindow.Find("medkit") as item
			if med:
				med.UseItem()
				return


func _on_medkit_2_icon_gui_input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			#print("rad tapped")
			var med = InventoryWindow.Find("medkit_army") as item
			if med:
				med.UseItem()
				return


func _on_antirad_icon_gui_input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			#print("rad tapped")
			var rad = InventoryWindow.Find("antirad") as item
			if rad:
				rad.UseItem()
				return
