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

#import "RendererCommon.h"

matrix_float4x4 make_matrix_float4x4(const float *v)
{
    simd_float4 P = simd_make_float4(v[0], v[1], v[2], v[3]);
    v += 4;
    simd_float4 Q = simd_make_float4(v[0], v[1], v[2], v[3]);
    v += 4;
    simd_float4 R = simd_make_float4(v[0], v[1], v[2], v[3]);
    v += 4;
    simd_float4 S = simd_make_float4(v[0], v[1], v[2], v[3]);
    
    matrix_float4x4 mat = {P, Q, R, S};
    return mat;
}

matrix_float4x4 matrix_proj_ortho(float left, float right, float top, float bottom)
{
    float near = 0;
    float far = 1;
    
    float sx = 2 / (right - left);
    float sy = 2 / (top - bottom);
    float sz = 1 / (far - near);
    float tx = (right + left) / (left - right);
    float ty = (top + bottom) / (bottom - top);
    float tz = near / (far - near);
    
    simd_float4 P = simd_make_float4(sx, 0, 0, 0);
    simd_float4 Q = simd_make_float4(0, sy, 0, 0);
    simd_float4 R = simd_make_float4(0, 0, sz, 0);
    simd_float4 S = simd_make_float4(tx, ty, tz, 1);
    
    matrix_float4x4 mat = {P, Q, R, S};
    return mat;
}

matrix_float4x4 matrix_rotate_z(float rot)
{
    float cz, sz;
    __sincosf(rot, &sz, &cz);
    
    simd_float4 P = simd_make_float4(cz, -sz, 0, 0);
    simd_float4 Q = simd_make_float4(sz,  cz, 0, 0);
    simd_float4 R = simd_make_float4( 0,   0, 1, 0);
    simd_float4 S = simd_make_float4( 0,   0, 0, 1);
    
    matrix_float4x4 mat = {P, Q, R, S};
    return mat;
}
