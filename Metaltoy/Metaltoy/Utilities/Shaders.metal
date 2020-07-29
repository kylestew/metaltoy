#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

// =============================================================================

// Rec. 709 luma values for grayscale image conversion
constant float3 kRec709Luma = float3(0.2126, 0.7152, 0.0722);

kernel void grayscaleKernel(
                            texture2d<float, access::read> input [[ texture(0) ]],
                            texture2d<float, access::write> output [[ texture(2) ]],
                            constant Uniforms& uniforms [[ buffer(0) ]],
                            uint2 gid [[ thread_position_in_grid ]])
{
    // check if the pixel is within the bounds of the output texture
    if ((gid.x >= output.get_width()) || (gid.y >= output.get_height())) {
        return;
    }

    float4 color = input.read(gid);
    float gray = dot(color.rgb, kRec709Luma);

    color = float4(gray, gray, gray, 1.0);
    output.write(color, gid);
}

// =============================================================================
// http://redqueengraphics.com/2018/08/11/metal-shaders-blending-basics/

half4 multiply(half4 base, half4 overlay)
{
    return overlay * base + overlay *
        (1.0h - base.a) + base * (1.0h - overlay.a);
}

kernel void
imageBlend(texture2d<half, access::read> tex0 [[ texture(0) ]],
           texture2d<half, access::read> tex1 [[ texture(1) ]],
           texture2d<half, access::write> output [[ texture(2) ]],
           constant Uniforms& uniforms [[ buffer(0) ]],
           uint2 gid [[ thread_position_in_grid ]])
{
    // check if the pixel is within the bounds of the output texture
    if ((gid.x >= output.get_width()) || (gid.y >= output.get_height())) {
        return;
    }

    half4 base = tex0.read(gid);
    half4 overlay = tex1.read(gid);

    half4 color = multiply(base, overlay);

    output.write(color, gid);
}

// =============================================================================
// http://redqueengraphics.com/2018/07/29/metal-shaders-color-adjustments/

kernel void
colorShift(texture2d<half, access::read> tex0 [[ texture(0) ]],
           texture2d<half, access::read> tex1 [[ texture(1) ]],
           texture2d<half, access::write> output [[ texture(2) ]],
           constant Uniforms& uniforms [[ buffer(0) ]],
           uint2 gid [[ thread_position_in_grid ]])
{
    // check if the pixel is within the bounds of the output texture
    if ((gid.x >= output.get_width()) || (gid.y >= output.get_height())) {
        return;
    }

    // using more colorful image
    half4 color = tex1.read(gid);

    color = half4(color.r * abs( sin( 0.4 * uniforms.time )),
                  color.g * abs( cos( 0.4 * uniforms.time )),
                  color.b * abs( sin( 0.25 * uniforms.time )),
                  color.a);

    output.write(color, gid);
}

// =============================================================================

kernel void
glowWorms(texture2d<float, access::write> output [[ texture(2) ]],
          constant Uniforms& uniforms [[ buffer(0) ]],
          uint2 position [[ thread_position_in_grid ]])
{
    float2 resolution = float2(output.get_width(), output.get_height());
    float2 p = ( float2(position) / resolution ) * 2.0 - 1.0;

    float3 c = float3( 0.0 );

    float speed = uniforms.time;
    float amplitude = 1.0;
    float glowMultiplier = 1.0;

    float glowT = sin(speed) * 0.5 + 0.5;
    float glowFactor = mix( 0.15, 0.35, glowT );
    glowFactor *= glowMultiplier;

    c += float3(0.02, 0.03, 0.13) * ( glowFactor * abs( 1.0 / sin(p.x + sin( p.y + speed ) * amplitude ) ));
    c += float3(0.02, 0.10, 0.03) * ( glowFactor * abs( 1.0 / sin(p.x + cos( p.y + speed+1.00 ) * amplitude+0.1 ) ));
    c += float3(0.15, 0.05, 0.20) * ( glowFactor * abs( 1.0 / sin(p.y + sin( p.x + speed+1.30 ) * amplitude+0.15 ) ));
    c += float3(0.20, 0.05, 0.05) * ( glowFactor * abs( 1.0 / sin(p.y + cos( p.x + speed+3.00 ) * amplitude+0.3 ) ));
    c += float3(0.17, 0.17, 0.05) * ( glowFactor * abs( 1.0 / sin(p.y + cos( p.x + speed+5.00 ) * amplitude+0.2 ) ));

    output.write(float4(c, 1), position);
}

// =============================================================================

float2 mod(float2 x, float y) {
    return x - y * floor(x/y);
}

kernel void
silex(texture2d<float, access::write> output [[ texture(2) ]],
      constant Uniforms& uniforms [[ buffer(0) ]],
      uint2 position [[ thread_position_in_grid ]])
{
    float2 resolution = float2(output.get_width(), output.get_height());

    float3 c;
    float l, z = uniforms.time;
    for (int i = 0; i < 3; i++) {
        float2 uv, p = float2(position) / resolution;
        uv = p;
        p -= 0.5;
        p.x*=resolution.x/resolution.y;
        z+=.07;
        l=length(p);
        uv+=p/l*(sin(z)+1.)*abs(sin(l*9.-z*2.));
        c[i]=.01/length(abs(mod(uv,1.)-.5));
    }

    output.write(float4(c/l, uniforms.time), position);
}

// =============================================================================
// https://www.shadertoy.com/view/Ml2GWy

kernel void
fractalTiling(texture2d<float, access::write> output [[ texture(2) ]],
              constant Uniforms& uniforms [[ buffer(0) ]],
              uint2 position [[ thread_position_in_grid ]])
{
    float2 resolution = float2(output.get_width(), output.get_height());
    float2 pos = 256.0 * float2(position) / resolution.x + uniforms.time;

    float3 col = float3(0.0);
    for(int i=0; i<6; i++) {
        float2 a = floor(pos);
        float2 b = fract(pos);

        float4 w = fract((sin(a.x*7.0+31.0*a.y + 0.01*uniforms.time)+float4(0.035,0.01,0.0,0.7))*13.545317); // randoms

        col += w.xyz *                                   // color
               2.0*smoothstep(0.45,0.55,w.w) *           // intensity
               sqrt( 16.0*b.x*b.y*(1.0-b.x)*(1.0-b.y) ); // pattern

        pos /= 2.0; // lacunarity
        col /= 2.0; // attenuate high frequencies
    }

    col = pow( col, float3(0.7,0.8,0.5) );    // contrast and color shape

    output.write(float4(col, 1.0), position);
}


// =============================================================================
// https://www.shadertoy.com/view/MsjSW3


/*
struct VertexInOut
{
    float4 position [[position]];
    float2 texCoord [[user(texturecoord)]];
    float4 color;
};

vertex VertexInOut vertexShader(uint vid [[ vertex_id ]],
                                constant float4* position [[ buffer(0) ]],
                                constant packed_float2* texCoords [[ buffer(1) ]],
                                constant packed_float4* color [[ buffer(2) ]])
{
    VertexInOut outVertex;

    // pass through the vertex, tex coord and color
    outVertex.position =  position[vid];
    outVertex.texCoord =  texCoords[vid];
    outVertex.color    =  color[vid];

    return outVertex;
}

fragment float4
fragmentShader(VertexInOut inFrag [[ stage_in ]]) {
    return inFrag.color;
}
 */
