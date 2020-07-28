#include <metal_stdlib>
using namespace metal;



kernel void computeFunc(texture2d<float, access::read> input [[ texture(0) ]],
                        texture2d<float, access::write> output [[ texture(1) ]],
                        uint2 id [[ thread_position_in_grid ]])
{
    float4 color = input.read(id);
    color = float4(color.g, color.b, color.r, 1.0);
    output.write(color, id);
}




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
