@tool
extends CompositorEffect
class_name ChromaticAbberationShader

@export var r_offset: int = 1
@export var g_offset: int = 2
@export var b_offset: int = 3

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true

var rd: RenderingDevice
var shader: RID
var pipeline: RID

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return
	
	var shader_file: RDShaderFile = load("res://shaders/chromatic_abberation.glsl")
	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

func _render_callback(p_effect_callback_type: int, render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return
		
			var x_groups = size.x / 4
			var y_groups = size.y / 4
			var z_groups = 1
			
			var push_constant: PackedFloat32Array = PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0
			])
			
			var offset_values: PackedInt32Array = PackedInt32Array([
				r_offset,
				g_offset,
				b_offset
			])
			var offset_bytes = offset_values.to_byte_array()
			var offset_buffer := rd.storage_buffer_create(offset_bytes.size(), offset_bytes)
			
			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				var input_image = render_scene_buffers.get_color_layer(view)
				
				
				var image_uniform: RDUniform = RDUniform.new()
				image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				image_uniform.binding = 0
				image_uniform.add_id(input_image)
				var image_uniform_set = UniformSetCacheRD.get_cache(shader, 0, [image_uniform])
				
				var offset_uniform: RDUniform = RDUniform.new()
				offset_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				offset_uniform.binding = 0
				offset_uniform.add_id(offset_buffer)
				var offset_uniform_set = UniformSetCacheRD.get_cache(shader, 1, [offset_uniform])
				
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, image_uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, offset_uniform_set, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
