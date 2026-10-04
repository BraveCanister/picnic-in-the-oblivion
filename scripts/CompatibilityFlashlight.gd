extends SpotLight3D

func _ready() -> void:
	set_process(false)
	if OS.has_feature("android") and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		activate()

func activate() -> void:
	# This material family has specular disabled. A unique specular tag identifies
	# this light inside light(), without recoloring it or filtering other lights.
	light_specular = 0.137
	RenderingServer.global_shader_parameter_set("picnic_flashlight_cookie", light_projector)
	update_projection()
	set_process(true)

func update_projection() -> void:
	RenderingServer.global_shader_parameter_set("picnic_flashlight_inverse", global_transform.affine_inverse())
	RenderingServer.global_shader_parameter_set("picnic_flashlight_tangent", tan(deg_to_rad(spot_angle)))
	RenderingServer.global_shader_parameter_set("picnic_flashlight_size", light_size)

func _process(_delta: float) -> void:
	update_projection()
