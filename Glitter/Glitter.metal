//
//  Glitter.metal
//  ScribbleApp
//
//  Created by Bridger Maxwell on 3/31/19.
//  Copyright © 2019 Bridger Maxwell. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float3 rgb2hsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float random(float2 co) {
    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
    float dt= dot(co.xy ,float2(a,b));
    float sn= fmod(dt,3.14);
    return fract(sin(sn) * c);
}

float rand(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Permutation polynomial: (34x^2 + x) mod 289
float4 permute(float4 x) {
    return fmod((34.0 * x + 1.0) * x, 289.0);
}

float2 cellular2x2(float2 P) {
#define K 0.142857142857 // 1/7
#define K2 0.0714285714285 // K/2
#define jitter 0.9 // jitter 1.0 makes F1 wrong more often
    float2 Pi = fmod(floor(P), 288.992);
    float2 Pf = fract(P);
    float4 Pfx = Pf.x + float4(-0.5, -1.5, -0.5, -1.5);
    float4 Pfy = Pf.y + float4(-0.5, -0.5, -1.5, -1.5);
    float4 p = permute(Pi.x + float4(0.0, 1.0, 0.0, 1.0));
    p = permute(p + Pi.y + float4(0.0, 0.0, 1.0, 1.0));

    float4 ox = fmod(p, 7.0)*K+K2;
    float4 oy = fmod(floor(p*K),7.0)*K+K2;
    float4 dx = Pfx + jitter*ox;
    float4 dy = Pfy + jitter*oy;
    float4 d = dx * dx + dy * dy; // d11, d12, d21 and d22, squared
                                  // Sort out the two smallest distances

    float2 smallest = min(d.xy, d.zw);
    smallest.x = min(smallest.x, smallest.y);

    if (smallest.x == d.x) {
        return float2(dx.x, dy.x) - P;

    } else if (smallest.x == d.y) {
        return float2(dx.y, dy.y) - P;

    } else if (smallest.x == d.z) {
        return float2(dx.z, dy.z) - P;

    } else {
        // smallest.x == d.w
        return float2(dx.w, dy.w) - P;
    }
}

struct InColorVertex
{
    float2 position;
    packed_float4 color;
};

struct ColorVertex
{
    float4 position [[position]];
    float4 color;
};

struct GlitterFragmentUniform {
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

vertex ColorVertex glitter_vertex(const device InColorVertex *vertices [[buffer(0)]],
                                  uint vid [[vertex_id]])
{
    ColorVertex vertexOut;
    vertexOut.position = float4(vertices[vid].position, 0, 1);
    vertexOut.color = vertices[vid].color;
    return vertexOut;
}

struct FragmentOut {
  float4 color0 [[ color(0) ]];
  float4 color1 [[ color(1) ]];
};

fragment FragmentOut glitter_fragment(ColorVertex inVertex [[stage_in]],
                                 constant GlitterFragmentUniform &params [[buffer(1)]]) {
#define UPRIGHT 1.5 // upright-ness of glitter particles. Higher means they are more aligned and go off at the same time when direct on
#define VARIANCE 4.0 // variance of glitter in x-y. Make it smaller to make the max-tilt relatively less bright compared to straight-on

    float cellSize = params.cellSize;

    float2 screenPos = (inVertex.position.xy / params.displaySize - 0.5) * 2.0 * UPRIGHT;

    // Each pixel is part of two glitter cells. If either of those cells light up then the pixel lights up. This gives more change for glimmer and size differences in points of light
    float2 glitterCoord1 = inVertex.position.xy / params.displayScale;
    float glitterCell1 = random(cellular2x2(glitterCoord1 * cellSize)); // The smaller this constant the bigger the cells are

    float2 glitterCoord2 = glitterCoord1 + float2(2000.0, 2000.0);
    float glitterCell2 = random(cellular2x2(glitterCoord2 * cellSize)); // The smaller this constant the bigger the cells are

    // GlitterRandom has an x and y that each go from -1 to 1
    float2 glitterRandom1 = float2(glitterCell1 * 2.0 - 1.0,
                                   rand(glitterCell1 + 3.2) * 2.0 - 1.0);
    float3 normal1 = normalize(float3(glitterRandom1.x * VARIANCE + screenPos.x,
                                      glitterRandom1.y * VARIANCE + screenPos.y,
                                      UPRIGHT));
    float lightIncidence1 = abs(dot(normal1, float3(params.tilt))); // Because of the abs this will reflect in the negative direction too, so each glitter lights up more

    // GlitterRandom has an x and y that each go from -1 to 1
    float2 glitterRandom2 = float2(glitterCell2 * 2.0 - 1.0,
                                   rand(glitterCell2 + 3.2) * 2.0 - 1.0);
    float3 normal2 = normalize(float3(glitterRandom2.x * VARIANCE + screenPos.x,
                                      glitterRandom2.y * VARIANCE + screenPos.y,
                                      UPRIGHT));
    float lightIncidence2 = abs(dot(normal2, float3(params.tilt))); // Because of the abs this will reflect in the negative direction too, so each glitter lights up more

    float brightness = pow(max(lightIncidence1, lightIncidence2), 30) * 2.0;
    float brightestCell = lightIncidence1 > lightIncidence2 ? glitterCell1 : glitterCell2;

    // This adds a little randomness to ever cell so none look "blank"
    brightness = max(brightness, glitterCell1 * params.backgroundLight);

    float hues[] = {
        0.83, 0.74, 0.59, 0.66, 0.42, 0.14, 0.93, 0.36, 0.03, 0.19
    };

    float value = brightness / 2.0;
    float saturation = max((brightness - 1.0), 0.0);
    int hueIndex = int(rand(brightestCell) * 10.0);
    float hue = hues[hueIndex];
    float3 hsvCol = {hue, saturation, value};

    float3 rgbCol = hsv2rgb(hsvCol);
    if (params.useWideColor) {
        const float minP3 = -0.752941;
        const float maxP3 = 1.25098;
        rgbCol = rgbCol * (maxP3 - minP3) + minP3;
    }

    FragmentOut out;
    float4 rgbaCol = float4(rgbCol, 1.0);
    out.color0 = rgbaCol;
    out.color1 = brightness > 1.2 ? rgbaCol : 0.0;

    return out;
}
