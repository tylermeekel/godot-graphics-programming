@tool
extends CompositorEffect
class_name TestingShader

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true

var rd: RenderingDevice
var first_shader: RID
var first_pipeline: RID

var second_shader: RID
var second_pipeline: RID

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if first_shader.is_valid():
			rd.free_rid(first_shader)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return
	
	var first_shader_file: RDShaderFile = load("res://shaders/testing_1.glsl")
	var first_shader_spirv = first_shader_file.get_spirv()
	first_shader = rd.shader_create_from_spirv(first_shader_spirv)
	
	var second_shader_file: RDShaderFile = load("res://shaders/testing_2.glsl")
	var second_shader_spirv = second_shader_file.get_spirv()
	second_shader = rd.shader_create_from_spirv(second_shader_spirv)
	
	if first_shader.is_valid():
		first_pipeline = rd.compute_pipeline_create(first_shader)
	
	if second_shader.is_valid():
		second_pipeline = rd.compute_pipeline_create(second_shader)

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
			
			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				var input_image = render_scene_buffers.get_color_layer(view)
				
				var input_image_format: RDTextureFormat = rd.texture_get_format(input_image)
				var storage_image = rd.texture_create(input_image_format, RDTextureView.new(), [])
				
				var image_uniform: RDUniform = RDUniform.new()
				image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				image_uniform.binding = 0
				image_uniform.add_id(input_image)
				var image_uniform_set = UniformSetCacheRD.get_cache(first_shader, 0, [image_uniform])
				
				var storage_image_uniform: RDUniform = RDUniform.new()
				storage_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				storage_image_uniform.binding = 0
				storage_image_uniform.add_id(storage_image)
				var storage_uniform_set = UniformSetCacheRD.get_cache(first_shader, 1, [storage_image_uniform])
				
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, first_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, storage_uniform_set, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
				
				compute_list = rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, second_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, storage_uniform_set, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
