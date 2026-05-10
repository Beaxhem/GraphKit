//
//  BarChart.metal
//  Querynaut
//
//  Created by Illia Senchukov on 22.11.2024.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
};

struct Uniforms {
    float4 color;
    float2 aspectRatio;
    float2 scale;
    float2 scrollOffset;
};

vertex VertexOut bar_vertex_main(VertexIn in [[stage_in]],
                                 constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float2 position = (in.position + uniforms.scrollOffset) * uniforms.scale;
    out.position = float4(position, 0, 1);
    return out;
}

fragment float4 bar_fragment_main(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    return uniforms.color;
}

vertex VertexOut bar_vertex_background(VertexIn in [[stage_in]],
                                        constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float2 position = (in.position + uniforms.scrollOffset) * uniforms.scale;
    out.position = float4(position, 0, 1);
    return out;
}

fragment float4 bar_fragment_background(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    float4 out = uniforms.color;;
    out.a *= 0.4;
    return out;
}
