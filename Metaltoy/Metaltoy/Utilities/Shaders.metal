#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"


// Rec. 709 luma values for grayscale image conversion
constant float3 kRec709Luma = float3(0.2126, 0.7152, 0.0722);

kernel void
grayscaleKernel(texture2d<float, access::read> input [[ texture(0) ]],
                texture2d<float, access::write> output [[ texture(1) ]],
                constant Uniforms& uniforms [[ buffer(0) ]],
                uint2 gid [[ thread_position_in_grid ]])
{
    // check if the pixel is within the bounds of the output texture
    if ((gid.x >= output.get_width()) || (gid.y >= output.get_height())) {
        return;
    }

    float4 color = input.read(gid);
    color.r = sin(uniforms.time);
//    float gray = dot(color.rgb, kRec709Luma);
//
//    color = float4(gray, gray, gray, 1.0);
    output.write(color, gid);
}



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
