// Copyright (c) 2022, OpenEmu Team
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

import Foundation

extension FilterChain {
    func updateBindings(passBindings: ShaderPassBindings, forPassNumber passNumber: Int, passSemantics: ShaderPassSemantics, pass: Compiled.ShaderPass) {
        passBindings.format = pass.format.metalPixelFormat
        passBindings.isFeedback = pass.isFeedback
        
        // UBO
        let uboB = passBindings.buffers[0]
        if pass.buffers[0].size > 0 {
            let b = pass.buffers[0]
            uboB.bindingVert = b.bindingVert
            uboB.bindingFrag = b.bindingFrag
            uboB.size        = (b.size + 0xf) & ~0xf // round up to nearest 16 bytes
        }
        
        // push constants
        let pshB = passBindings.buffers[1]
        if pass.buffers[1].size > 0 {
            let b = pass.buffers[1]
            pshB.bindingVert = b.bindingVert
            pshB.bindingFrag = b.bindingFrag
            pshB.size        = (b.size + 0xf) & ~0xf // round up to nearest 16 bytes
        }
        
        for u in pass.buffers[0].uniforms {
            if let sem = ShaderBufferSemantic(u.semantic) {
                if sem == .floatParameter {
                    guard let param = passSemantics.parameter(at: u.index!)
                    else { fatalError("Unable to find parameter at index \(u.index!)") }
                    uboB.addUniformData(param.data,
                                        size: u.size,
                                        offset: u.offset,
                                        name: u.name)
                } else {
                    uboB.addUniformData(passSemantics.uniforms[sem]!.data,
                                        size: u.size,
                                        offset: u.offset,
                                        name: u.name)
                }
            } else if let sem = ShaderTextureSemantic(u.semantic) {
                let tex = passSemantics.textures[sem]!
                
                uboB.addUniformData(tex.textureSize.advanced(by: u.index! * tex.sizeStride),
                                    size: u.size,
                                    offset: u.offset,
                                    name: u.name)
            }
        }

        for u in pass.buffers[1].uniforms {
            if let sem = ShaderBufferSemantic(u.semantic) {
                if sem == .floatParameter {
                    guard let param = passSemantics.parameter(at: u.index!)
                    else { fatalError("Unable to find parameter at index \(u.index!)") }
                    pshB.addUniformData(param.data,
                                        size: u.size,
                                        offset: u.offset,
                                        name: u.name)
                } else {
                    pshB.addUniformData(passSemantics.uniforms[sem]!.data,
                                        size: u.size,
                                        offset: u.offset,
                                        name: u.name)

                }
            } else if let sem = ShaderTextureSemantic(u.semantic) {
                let tex = passSemantics.textures[sem]!
                
                pshB.addUniformData(tex.textureSize.advanced(by: u.index! * tex.sizeStride),
                                    size: u.size,
                                    offset: u.offset,
                                    name: u.name)
            }
        }
        
        for t in pass.textures {
            guard let sem = ShaderTextureSemantic(t.semantic)
            else { continue }
            
            let index = t.index!
            
            let tex = passSemantics.textures[sem]!
            
            let ptr = tex.texture.advanced(by: index * tex.textureStride)
            let bind = passBindings.addTexture(ptr, binding: t.binding, name: t.name)
            bind.wrap = .init(t.wrap)
            bind.filter = .init(t.filter)
        }
    }
}
