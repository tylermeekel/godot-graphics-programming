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
        // simplified 3x3 kernel
        float kernel[9] = float[](1, 2, 1, 2, 4, 2, 1, 2, 1);

        vec3 blurredColor = vec3(0.0);

        int k = 0;
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                ivec2 offset = ivec2(i - 1, j - 1);
                vec3 offsetColor = imageLoad(color_image, xy + offset).rgb;

                float offsetMultiplier = kernel[k] / 16.0;
                blurredColor += offsetColor * offsetMultiplier;
            }
        }

        color = vec4(blurredColor, color.a);
        imageStore(color_image, xy, color);
    }
}
