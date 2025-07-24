#[compute]
#version 450

layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 1, binding = 0) restrict buffer OffsetBuffer {
    int r_offset;
    int g_offset;
    int b_offset;
} offset_buffer;

layout(push_constant, std430) uniform Params {
    vec2 raster_size;
    vec2 reserved;
} params;

void main() {
    ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.raster_size);
    vec2 uv = vec2(float(xy.x) / float(size.x), float(xy.y) / float(size.y));

    if (xy.x >= size.x || xy.y >= size.y) {
        return;
    }

    vec4 color = imageLoad(color_image, xy);

    if (color.a == 0) {
        return;
    } else {
        float red = imageLoad(color_image, ivec2(xy.x + offset_buffer.r_offset, xy.y)).r;
        float green = imageLoad(color_image, ivec2(xy.x + offset_buffer.g_offset, xy.y)).g;
        float blue = imageLoad(color_image, ivec2(xy.x + offset_buffer.b_offset, xy.y)).b;

        imageStore(color_image, xy, vec4(red, green, blue, color.a));
    }
}
