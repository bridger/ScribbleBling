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

struct TextureFragmentUniform
{
    float red;
    float green;
    float blue;
    float alpha;
};


vertex TexturedVertex textured_vertex(const device InTexturedVertex *vertices [[buffer(0)]],
                                      uint vid [[vertex_id]])
{
    TexturedVertex vertexOut;
    vertexOut.position = float4(vertices[vid].position, 0, 1);
    vertexOut.texCoords = vertices[vid].textureCoordinates;
    return vertexOut;
}


fragment float4 shadow_texture_fragment(TexturedVertex inVertex [[stage_in]],
                                        texture2d<float> texture [[ texture(0) ]],
                                        constant TextureFragmentUniform &uniforms [[buffer(0)]]
                                        )
{
    constexpr sampler textureSampler(mag_filter::nearest,
                                     min_filter::nearest);
    float4 sampled = texture.sample(textureSampler, inVertex.texCoords);
    sampled.a *= uniforms.alpha;
    return sampled;
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
