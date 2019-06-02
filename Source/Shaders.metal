// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

#pragma mark - functions using projected coordinates

vertex ColorInOut basic_vertex_proj_tex(const Vertex in [[ stage_in ]],
                                        const device Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    out.position = uniforms.projectionMatrix * in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 basic_fragment_proj_tex(ColorInOut in [[stage_in]],
                                        constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                        texture2d<half> tex          [[ texture(TextureIndexColor) ]],
                                        sampler samp                 [[ sampler(SamplerIndexDraw) ]])
{
    half4 colorSample = tex.sample(samp, in.texCoord.xy);
    return float4(colorSample);
}

#pragma mark - filter kernels, texture to texture

kernel void convert_bgra4444_to_bgra8888(texture2d<ushort, access::read> in  [[ texture(0) ]],
                                         texture2d<half, access::write>  out [[ texture(1) ]],
                                         uint2                           gid [[ thread_position_in_grid ]])
{
    ushort pix  = in.read(gid).r;
    uchar4 pix2 = uchar4(
                         extract_bits(pix,  4, 4),
                         extract_bits(pix,  8, 4),
                         extract_bits(pix, 12, 4),
                         extract_bits(pix,  0, 4)
                         );
    
    out.write(half4(pix2) / 15.0, gid);
}

kernel void convert_rgb565_to_bgra8888(texture2d<ushort, access::read> in  [[ texture(0) ]],
                                       texture2d<half, access::write>  out [[ texture(1) ]],
                                       uint2                           gid [[ thread_position_in_grid ]])
{
    ushort pix  = in.read(gid).r;
    uchar4 pix2 = uchar4(
                         extract_bits(pix, 11, 5),
                         extract_bits(pix,  5, 6),
                         extract_bits(pix,  0, 5),
                         0xf
                         );
    
    out.write(half4(pix2) / half4(0x1f, 0x3f, 0x1f, 0xf), gid);
}

#pragma mark - filter kernels, buffer to texture

kernel void convert_bgra4444_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                             constant uint & stride  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid  [[ thread_position_in_grid ]])
{
    ushort pix  = in[gid.y * stride + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix,  4, 4),
                         extract_bits(pix,  8, 4),
                         extract_bits(pix, 12, 4),
                         extract_bits(pix,  0, 4)
                         );

    out.write(half4(pix2) / 15.0, gid);
}

kernel void convert_bgra5551_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                             constant uint & stride  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid [[ thread_position_in_grid ]])
{
    ushort pix  = in[gid.y * stride + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix,  0, 5),
                         extract_bits(pix,  5, 5),
                         extract_bits(pix, 10, 5),
                         extract_bits(pix, 15, 1)
                         );

    out.write(half4(pix2) / half4(0x1f, 0x1f, 0x1f, 0xff), gid);
}

kernel void convert_rgb565_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                           constant uint & stride  [[ buffer(1) ]],
                                           texture2d<half, access::write> out [[ texture(0) ]],
                                           uint2 gid [[ thread_position_in_grid ]])
{
    ushort pix  = in[gid.y * stride + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix, 11, 5),
                         extract_bits(pix,  5, 6),
                         extract_bits(pix,  0, 5),
                         0xf
                         );

    out.write(half4(pix2) / half4(0x1f, 0x3f, 0x1f, 0xf), gid);
}


kernel void convert_rgba8888_to_bgra8888_buf(device uchar4 * in  [[ buffer(0) ]],
                                             constant uint & stride  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid [[ thread_position_in_grid ]])
{
    uchar4 pix  = in[gid.y * stride + gid.x];
    out.write(half4(pix.abgr) / 255.0, gid);
}
