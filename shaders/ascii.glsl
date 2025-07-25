#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r8, set = 0, binding = 1) uniform image2D downscale_image;
layout(rgba8, set = 1, binding = 0) uniform image2D ascii_image;

layout(push_constant, std430) uniform Params {
    vec2 raster_size;
    vec2 reserved;
} params;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.raster_size);

    if (uv.x >= size.x || uv.y >= size.y) {
        return;
    }

    vec4 color = imageLoad(color_image, uv);

    if (color.a == 0) {
        return;
    } else {
        float luminance = imageLoad(downscale_image, uv).r;

        float sampleX = mod(uv.x, 8);
        float sampleY = mod(uv.y, 8);

        float xOffset = floor(luminance * 10) * 8;

        sampleX += xOffset;

        vec3 asciiValue = imageLoad(ascii_image, ivec2(int(sampleX), int(sampleY))).rgb;

        vec3 finalColor = asciiValue * luminance;

        imageStore(color_image, uv, vec4(finalColor, 1.0));
    }
}
