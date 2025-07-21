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
        float kernelX[9] = float[](-1, 0, 1, -2, 0, 2, -1, 0, 1);
        float kernelY[9] = float[](-1, -2, -1, 0, 0, 0, 1, 2, 1);

        float gX = 0.0;
        float gY = 0.0;

        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                ivec2 offset = ivec2(i - 1, j - 1);
                float gray = dot(imageLoad(color_image, xy + offset).rgb, vec3(0.299, 0.587, 0.114));

                gX += gray * kernelX[i * 3 + j];
                gY += gray * kernelY[i * 3 + j];
            }
        }

        float g = sqrt(pow(gX, 2) + pow(gY, 2));
        g = clamp(g / 0.8, 0.0, 1.0);
        imageStore(color_image, xy, vec4(g, g, g, 1.0));
    }
}
