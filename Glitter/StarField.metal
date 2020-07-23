//
//  StarField.metal
//  Glitter
//
//  Created by Raheel Ahmad on 7/22/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


float map(float a, float b, float c, float d, float t) {
    float val = (t - a) / (b - a) * (d - c) + c;
    return clamp(val, 0.0, 1.0);
}

/// Normalize st within the box: if st.x == 0, it will be on left side; if st.y == 0, it will be on bottom side;
float2 withinRect(float2 st, float4 rect) {
    return (st - rect.xy) / (rect.zw - rect.xy);
}

float2x2 Rot(float a) {
    float s = sin(a), c = cos(a);
    return float2x2(c, -s, s, c);
}

float Star(float2 st, float flare, float rotation) {
    float d = length(st);
    
    float m = 0;
    
    float star = .05/d;
    m += star;
    
    // 2 rays:
    //  1st
    st *= Rot(rotation);
    st *= Rot(3.1415/4);
    float rays = max(0., 1. - abs(st.y * st.x * 1000));
    m += rays * flare;
    //  2nd rotated
    st *= Rot(3.1415/4);
    rays = max(0., 1. - abs(st.y * st.x * 1000));
    m += rays * .3 * flare;
    
    // don't project indefinitely outside the grid
    // (just in the next neighbor, but not the neighbor's neighbor)
    m *= smoothstep(0.9, .2, d);
    
    return m;
}

float Hash12(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}


float3 starField(float2 st, float tilt, float rotation) {
    float3 color = 0;
    float2 id = floor(st);
    float2 gv = fract(st)
    - 0.5 // move the coordinate-system so star is expected in the center
    ;
    
    for (int x=-1; x<=1; x++) {
        for (int y=-1; y<=1; y++) {
            float2 offset = float2(x, y);
            float contributingStarId = Hash12(id + offset);
            float2 gvPos = gv // place in the unit box for which we are asking for pixel value if star is centered in the grid
            - offset // consider the star to be in a different grid if we have an offset
            - (float2(
                      contributingStarId, // add a random offset for x inside the grid
                      fract(contributingStarId * 12) // same for y, but make it a different random
                      )
               - .5
               ) ;
            
            float size = fract(contributingStarId * 219.34);
            float flare = smoothstep(0.4, .8, size); // only for bigger stars
            float star = Star(gvPos, flare, rotation);
            float3 col = sin(float3(0.6, 0.4, 0.8) * fract(contributingStarId * 210) * 212.) * .5 + .5;
            float fade = tilt * contributingStarId;
            color += star * size * col * fade;
        }
    }
    return color;
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

struct StarFieldFragmentUniform {
    float2 displaySize;
    float displayScale;
    
    packed_float3 tilt;
};

vertex ColorVertex starfield_vertex(const device InColorVertex *vertices [[buffer(0)]],
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

float visibility(float3 tiltParams, float2 st) {
    float tiltX = tiltParams.x;
    tiltX = map(-1, 1, 1, 0, tiltX);
    tiltX = mix(0.3, 0.9, tiltX);
    float x = map(-.5, .5, 0, 1, st.x);    
    float visibilityX = (x - tiltX) * (1 - tiltX) + (1 - x) * tiltX;    
    
    float tiltY = tiltParams.y;
    tiltY = map(-1, 1, 1, 0, tiltY);
    tiltY = mix(0.1, 0.93, tiltY);
    float y = map(-.5, .5, 0, 1, st.y);    
    float visibilityY = (y - tiltY) * (1 - tiltY) + (1 - y) * tiltY;        
    
    float visibility = (visibilityX + visibilityY)/2.;
    
    return visibility;
}

fragment FragmentOut starfield_fragment(ColorVertex inVertex [[stage_in]],
                                      constant StarFieldFragmentUniform &params [[buffer(1)]]) {
    float2 st  = inVertex.position.xy / params.displaySize - .5;
    float fade = visibility(params.tilt, st);
    float rotation = params.tilt.z;
    
    st *= 3;
    
    float numLayers = 3;
    
    float3 color = 0;
    
    for (float i = 0; i < 1; i+=1/numLayers) {
        float depth = fract(i); // increading depth, b/w 0 and 1
        float scale = mix(20, .5, depth); // smaller in the back
        color += starField(st * scale, fade, rotation);
    }
    
    FragmentOut out;
    float4 rgbaCol = float4(color, 1.0);
    out.color0 = rgbaCol;
    
    return out;
}
