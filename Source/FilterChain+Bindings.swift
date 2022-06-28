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
        func addUniforms(bufferIndex: Int) {
            let desc = pass.buffers[bufferIndex]
            guard desc.size > 0 else { return }

            let bind = passBindings.buffers[bufferIndex]
            bind.bindingVert = desc.bindingVert
            bind.bindingFrag = desc.bindingFrag
            bind.size        = (desc.size + 0xf) & ~0xf // round up to nearest 16 bytes
            
            for u in desc.uniforms {
                if let sem = ShaderBufferSemantic(u.semantic) {
                    if sem == .floatParameter {
                        guard let param = passSemantics.parameter(at: u.index!)
                        else { fatalError("Unable to find parameter at index \(u.index!)") }
                        bind.addUniformData(param.data,
                                            size: u.size,
                                            offset: u.offset,
                                            name: u.name)
                    } else {
                        bind.addUniformData(passSemantics.uniforms[sem]!.data,
                                            size: u.size,
                                            offset: u.offset,
                                            name: u.name)
                    }
                } else if let sem = ShaderTextureSemantic(u.semantic) {
                    let tex = passSemantics.textures[sem]!
                    
                    bind.addUniformData(tex.textureSize.advanced(by: u.index! * tex.sizeStride),
                                        size: u.size,
                                        offset: u.offset,
                                        name: u.name)
                }
            }
        }
        
        // UBO
        addUniforms(bufferIndex: 0)
        // Push
        addUniforms(bufferIndex: 1)
        
        for t in pass.textures {
            guard let sem = ShaderTextureSemantic(t.semantic)
            else { continue }
            
            let tex  = passSemantics.textures[sem]!
            let bind = passBindings.addTexture(tex.texture.advanced(by: t.index! * tex.textureStride),
                                               binding: t.binding,
                                               name: t.name)
            bind.wrap   = .init(t.wrap)
            bind.filter = .init(t.filter)
        }
    }
}
