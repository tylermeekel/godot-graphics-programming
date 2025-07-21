#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

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
        vec2 center = vec2(0.5, 0.5);

        float dist = distance(uv, center) * 1.5;

        float vignette = 1 - dist;

        vec3 vignette_result = color.rgb * vignette;

        color = vec4(vignette_result, color.a);

        imageStore(color_image, xy, color);
    }
}
