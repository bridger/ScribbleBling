//
//  Passthrough.metal
//  Glitter
//
//  Created by Raheel Ahmad on 6/1/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


struct InTexturedVertex
{
    float2 position;
    float2 textureCoordinates;
};


struct TexturedVertex
{
    float4 position [[position]];
    float2 texCoords;
};

struct BlurCompositeFragmentUniform
{
    int radius;
};


vertex TexturedVertex textured_vertex(const device InTexturedVertex *vertices [[buffer(0)]],
                                      uint vid [[vertex_id]])
{
    TexturedVertex vertexOut;
    vertexOut.position = float4(vertices[vid].position, 0, 1);
    vertexOut.texCoords = vertices[vid].textureCoordinates;
    return vertexOut;
}

fragment float4 blur_composite_fragment(TexturedVertex inVertex [[stage_in]],
                                        texture2d<float, access::sample> texture [[ texture(0) ]],
                                        constant BlurCompositeFragmentUniform &uniforms [[buffer(0)]]
                                        )
{
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    int radius = uniforms.radius;
    float2 pixelSize = float2(1.0 / texture.get_width(),
                              1.0 / texture.get_height());
    float4 accumColor(0, 0, 0, 0);
    float maxOffsetI = -radius;
    float maxOffSetJ = -radius;
    for (int j = -radius; j <= radius; ++j)
    {
        for (int i = -radius; i <= radius; ++i)
        {
            float2 readOffset = float2(i, j) * pixelSize;
            float2 readIndex = inVertex.texCoords + readOffset;
            float4 color = texture.sample(textureSampler, readIndex);
            float colorSum = color.x + color.y + color.z + color.w;
            float accumColorSum = accumColor.x + accumColor.y + accumColor.z + accumColor.w;

            if (colorSum > accumColorSum) {
                accumColor = color;
                maxOffsetI = i;
                maxOffSetJ = j;
            }
        }
    }

    float weight = 1 - (abs(maxOffsetI) + abs(maxOffSetJ)) / (radius * 2.0);
    accumColor = accumColor * weight;

    return accumColor;
}

// --- Compute

struct InColorVertex
{
    float2 position;
    float4 color;
};

struct ColorVertex
{
    float4 position [[position]];
    float4 color;
};

struct PassthroughUniform {
    float2 displaySize;
    float displayScale;

    packed_float3 tilt;
    float cellSize;
    float whiteness;
    float darkness;
    float backgroundLight;
    float hueVariance;

    int useWideColor;
};

vertex ColorVertex final_vertex(const device InColorVertex *vertices [[buffer(0)]],
                                uint vid [[vertex_id]])
{
    ColorVertex vertexOut;
    vertexOut.position = float4(vertices[vid].position, 0, 1);
    vertexOut.color = vertices[vid].color;
    return vertexOut;
}

fragment float4 final_fragment(ColorVertex inVertex [[stage_in]]) {
    return float4(inVertex.color);
}

kernel void computeShader(
                          texture2d<float, access::read> texture1 [[ texture(0) ]],
                          texture2d<float, access::read> texture2 [[ texture(1) ]],
                          texture2d<float, access::write> dest [[ texture(2) ]],
                          uint2 gid [[ thread_position_in_grid ]]
                          ) {
    float4 source_color = texture1.read(gid);
    float4 mask_color = texture2.read(gid);
    float4 result_color = source_color + mask_color;

    dest.write(result_color, gid);
}
