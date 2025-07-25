@tool
extends CompositorEffect
class_name AsciiShader

var rd: RenderingDevice

var downscale_texture: RID
var downscale_shader: RID
var downscale_pipeline: RID

var ascii_texture_file: CompressedTexture2D = load("res://assets/fillASCII.png")
var ascii_texture: RID
var ascii_shader: RID
var ascii_pipeline: RID

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if downscale_shader.is_valid():
			rd.free_rid(downscale_shader)
		if ascii_shader.is_valid():
			rd.free_rid(ascii_shader)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return
		
	# Initialize ASCII Texture Image
	var ascii_image_format: RDTextureFormat = RDTextureFormat.new()
	ascii_image_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	ascii_image_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var ascii_texture_image: Image = ascii_texture_file.get_image()
	
	ascii_image_format.height = ascii_texture_image.get_height()
	ascii_image_format.width = ascii_texture_image.get_width()
	
	ascii_texture_image.convert(Image.FORMAT_RGBA8)
	ascii_texture = rd.texture_create(ascii_image_format, RDTextureView.new(), [ascii_texture_image.get_data()])
	
	# Compile Downscale Shader
	var downscale_shader_file: RDShaderFile = load("res://shaders/ascii_downscale.glsl")
	var downscale_shader_spirv = downscale_shader_file.get_spirv()
	downscale_shader = rd.shader_create_from_spirv(downscale_shader_spirv)
	
	if downscale_shader.is_valid():
		downscale_pipeline = rd.compute_pipeline_create(downscale_shader)
		
	# Compile ASCII Shader
	var ascii_shader_file: RDShaderFile = load("res://shaders/ascii.glsl")
	var ascii_shader_spirv = ascii_shader_file.get_spirv()
	ascii_shader = rd.shader_create_from_spirv(ascii_shader_spirv)
	
	if ascii_shader.is_valid():
		ascii_pipeline = rd.compute_pipeline_create(ascii_shader)

func _render_callback(p_effect_callback_type: int, render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return
		
			var x_groups = (size.x - 1) / 8 + 1
			var y_groups = (size.y - 1) / 8 + 1
			var z_groups = 1
			
			var push_constant: PackedFloat32Array = PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0
			])
			
			var pc_bytes: PackedByteArray = push_constant.to_byte_array()
			
			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				var color_buffer = render_scene_buffers.get_color_layer(view)
				
				var color_buffer_format: RDTextureFormat = rd.texture_get_format(color_buffer)
				
				# Create downscale texture (there's probably a better place to do this but I need updated
				# width and height for the texture...)
				var downscale_format: RDTextureFormat = RDTextureFormat.new()
				downscale_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
				downscale_format.height = size.y
				downscale_format.width = size.x
				downscale_format.usage_bits = color_buffer_format.usage_bits
	
				downscale_texture = rd.texture_create(downscale_format, RDTextureView.new(), [])
				
				var color_uniform: RDUniform = RDUniform.new()
				color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				color_uniform.binding = 0
				color_uniform.add_id(color_buffer)
				
				var downscale_texture_uniform: RDUniform = RDUniform.new()
				downscale_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				downscale_texture_uniform.binding = 1
				downscale_texture_uniform.add_id(downscale_texture)
				
				var image_uniform_set = rd.uniform_set_create([color_uniform, downscale_texture_uniform], downscale_shader, 0)
				
				# Begin Downscale, Greyscale pass
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, downscale_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
				
				# Begin ASCII pass
				var ascii_texture_uniform: RDUniform = RDUniform.new()
				ascii_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE # figure out how to change to sampler l8r
				ascii_texture_uniform.binding = 0
				ascii_texture_uniform.add_id(ascii_texture)
				
				var ascii_uniform_set = rd.uniform_set_create([ascii_texture_uniform], ascii_shader, 1)

				compute_list = rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, ascii_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, ascii_uniform_set, 1)
				rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
				
				# Free the downscale texture to avoid eating memory?
				rd.free_rid(downscale_texture)
