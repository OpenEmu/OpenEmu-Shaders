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
import CSPIRVCross

extension ShaderPassCompiler {
    public func compile(options: ShaderCompilerOptions) throws -> Compiled.Shader {
        func mapPass(_ pass: ShaderPass) throws -> Compiled.ShaderPass {
            try compilePass(pass, options: options)
        }
        
        let passes = try shader.passes.map(mapPass(_:))
        
        return Compiled.Shader(passes: passes, parameters: [], luts: [])
    }
    
    func compilePass(_ pass: ShaderPass, options: ShaderCompilerOptions) throws -> Compiled.ShaderPass {
        var ctx: __SPVContext?
        __spvc_context_create(&ctx)
        guard let ctx = ctx else {
            throw ShaderError.buildFailed
        }
        defer { ctx.destroy() }
        
        let errorHandler: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?) -> Void = { userData, errorMsg in
            guard
                let userData = userData,
                let errorMsg = errorMsg
            else { return }
            
            let compiler = Unmanaged<ShaderPassCompiler>.fromOpaque(userData).takeUnretainedValue()
            compiler.compileError(String(cString: errorMsg))
        }
        
        spvc_context_set_error_callback(ctx, errorHandler, Unmanaged.passUnretained(self).toOpaque())
        
        var vsCompiler: SPVCompiler?, fsCompiler: SPVCompiler?
        try makeCompilersForPass(pass, context: ctx, options: options, vertexCompiler: &vsCompiler, fragmentCompiler: &fsCompiler)
        
        guard
            let vsCompiler = vsCompiler,
            let fsCompiler = fsCompiler
        else {
            throw ShaderError.buildFailed
        }

        var vsCode: UnsafePointer<Int8>?
        vsCompiler.compile(&vsCode)
        
        var fsCode: UnsafePointer<Int8>?
        fsCompiler.compile(&fsCode)
        
        guard let sym = makeSymbols() else { throw ShaderError.processFailed }
        guard let ref = reflect(passNumber: pass.index, withSymbols: sym, withVertexCompiler: vsCompiler, fragmentCompiler: fsCompiler)
        else {
            throw ShaderError.processFailed
        }
        
        // TODO: Determine isFeedback
        let isFeedback = false
        
        // TODO: Populate buffer descriptors
        let buffers  = [
            makeBuffersForSemantics(ref, source: \.ubo, offset: \.uboOffset, textureOffset: \.uboOffset),
            makeBuffersForSemantics(ref, source: \.push, offset: \.pushOffset, textureOffset: \.pushOffset),
        ]
        
        // TODO: Populate texture descriptos
        let textures = [Compiled.TextureDescriptor]()

        return .init(index: pass.index,
                     vertexSource: String(cString: vsCode!),
                     fragmentSource: String(cString: fsCode!),
                     format: try .init(pass.format),
                     isFeedback: isFeedback,
                     buffers: buffers,
                     textures: textures)
    }
    
    private func makeTextures(_ ref: ShaderReflection) -> [Compiled.TextureDescriptor] {
        fatalError("not implemented")
    }
    
    private func makeBuffersForSemantics(_ ref: ShaderPassReflection,
                                         source: KeyPath<ShaderPassReflection, BufferBindingDescriptor?>,
                                         offset: KeyPath<ShaderSemanticMeta, Int?>,
                                         textureOffset: KeyPath<ShaderTextureSemanticMeta, Int?>
    ) -> Compiled.BufferDescriptor {
        guard let b = ref[keyPath: source]
        else { return .init(bindingVert: nil, bindingFrag: nil, size: 0, uniforms: []) }
        
        let semantics = ref.semantics.compactMap { sem, meta in
            if let offset = meta[keyPath: offset] {
                return Compiled.BufferUniformDescriptor(semantic: .init(sem),
                                                        index: nil,
                                                        size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                                        offset: offset)
            }
            return nil
        }
        
        let parameters = ref.floatParameters.values.compactMap { meta in
            if let offset = meta[keyPath: offset] {
                return Compiled.BufferUniformDescriptor(semantic: .floatParameter,
                                                        index: meta.index,
                                                        size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                                        offset: offset)
            }
            return nil
        }
        
        let textures = ref.textures.flatMap { sem, a in
            a.values.compactMap { meta in
                if let offset = meta[keyPath: textureOffset] {
                    return Compiled.BufferUniformDescriptor(semantic: .init(sem),
                                                            index: meta.index,
                                                            size: 4 * MemoryLayout<Float>.size,
                                                            offset: offset)
                }
                return nil
            }
        }
        
        return .init(bindingVert: b.bindingVert,
                     bindingFrag: b.bindingFrag,
                     size: (b.size + 0xf) & ~0xf, // round up to nearest 16 bytes
                     uniforms: semantics + parameters + textures)
    }
}
