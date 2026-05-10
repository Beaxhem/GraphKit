//
//  LineChartShaders.metal
//  Querynaut
//
//  Created by Illia Senchukov on 15.11.2024.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float yPosition;
};

struct Uniforms {
    float4 color;
    float2 aspectRatio;
    float lineWidth;
    float2 scale;
    float2 scrollOffset;
};

vertex VertexOut line_vertex_main(constant VertexIn *vertexData [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]],
                                  uint groupVertexID [[vertex_id]]) {
    uint instanceID = groupVertexID / 4;
    uint vertexID = groupVertexID % 4;
    uint idOffset = instanceID * 4;
    float lineWidth = uniforms.lineWidth;
    float2 aspectRatio = uniforms.aspectRatio;

    VertexIn in = vertexData[idOffset + vertexID];

    float2 p1 = (in.position + uniforms.scrollOffset) * uniforms.scale;

    uint targetID = idOffset + vertexID + (vertexID < 2 ? 2 : -2);
    float2 p2 = (vertexData[targetID].position + uniforms.scrollOffset) * uniforms.scale;

    float2 direction = normalize((p2 - p1) * aspectRatio);
    float2 normal = normalize(float2(-direction.y, direction.x));
    float2 offset = (normal * (lineWidth / 2)) / (aspectRatio);

    offset = vertexID > 1 ? -offset : offset;
    p1 += vertexID % 2 == 0 ? offset : -offset;

    VertexOut out;
    out.position = float4(p1, 0.0, 1.0);
    out.yPosition = p1.y;
    return out;
}

fragment float4 line_fragment_main(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    return uniforms.color;
}

vertex VertexOut line_vertex_background(VertexIn in [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float2 position = (in.position + uniforms.scrollOffset) * uniforms.scale;
    out.position = float4(position, 0, 1);
    out.yPosition = in.position.y;
    return out;
}

fragment float4 line_fragment_background(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    float opacity = smoothstep(-1.0, 1.0, in.yPosition);
    float4 out = uniforms.color;
    out.a *= 0.6 * opacity * opacity;
    return out;
}
