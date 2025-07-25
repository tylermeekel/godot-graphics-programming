#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r8, set = 0, binding = 1) uniform image2D downscale_image;

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
        float pixelSize = 8.0;
        ivec2 downscaleUV = ivec2(floor(uv / pixelSize) * pixelSize);

        vec4 downscaleColor = imageLoad(color_image, downscaleUV);
        float luminance = dot(downscaleColor.rgb, vec3(0.2126, 0.7152, 0.0722));

        imageStore(downscale_image, uv, vec4(luminance, 0.0, 0.0, 0.0));
    }
}
