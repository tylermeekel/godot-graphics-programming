#[compute]
#version 450

layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 1, binding = 0) restrict buffer SigmaBuffer {
    float sigma1;
    float sigma2;
    float threshold;
} sigma_buffer;

layout(push_constant, std430) uniform Params {
    vec2 raster_size;
    vec2 reserved;
} params;

vec3 gaussianBlur(ivec2 pixel_xy, float sigma) {
    vec3 blurred_color = vec3(0.0);

    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            ivec2 offset = ivec2(i - 1, j - 1);
            vec3 offsetColor = imageLoad(color_image, pixel_xy + offset).rgb;

            float kernelVal = 1.0 / (2.0 * 3.14 * pow(sigma, 2)) * exp(-1 * (pow(offset.x, 2) + pow(offset.y, 2)) / (2 * pow(sigma, 2)));
            blurred_color += offsetColor * kernelVal;
        }
    }

    return blurred_color;
}

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

        vec3 blur1 = gaussianBlur(xy, sigma_buffer.sigma1);
        vec3 blur2 = gaussianBlur(xy, sigma_buffer.sigma2);

        vec3 dog = blur2 - blur1;
        float edgeIntensity = length(dog);

        if (edgeIntensity > sigma_buffer.threshold) {
            imageStore(color_image, xy, vec4(1));
        } else {
            imageStore(color_image, xy, vec4(vec3(0.0), 1.0));
        }
    }
}
