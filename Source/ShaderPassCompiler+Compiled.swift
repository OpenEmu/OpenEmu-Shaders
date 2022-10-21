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

@_implementationOnly import CSPIRVCross
import Foundation

extension ShaderPassCompiler {
    public func compile(options: ShaderCompilerOptions) throws -> Compiled.Shader {
        var passes = try shader.passes.map { pass in
            try compilePass(pass, options: options)
        }
        
        // The set contains the pass numbers of all passes
        // that are used as feedback. We search through all
        // passes that refer to a texture of type passFeedback.
        let feedback = Set<Int>(passes.flatMap { pass in
            pass.textures
                .filter { $0.semantic == .passFeedback }
                .map(\.index)
        })
        
        for passNumber in feedback {
            passes[passNumber].isFeedback = true
        }
        
        let parameters = shader.parameters
            .enumerated()
            .map { index, p in
                Compiled.Parameter(index: index, source: p)
            }
        
        let luts = shader.luts
            .map {
                Compiled.LUT(url: $0.url,
                             name: $0.name,
                             filter: $0.filter,
                             wrapMode: $0.wrapMode,
                             isMipmap: $0.isMipmap)
            }
        
        // Find the maximum index for the OriginalHistory texture semantic to determine
        // how many frames of original history is required.
        let historyCount = passes
            .flatMap {
                $0.textures
                    .filter { $0.semantic == .originalHistory }
                    .map(\.index)
            }
            .max() ?? 0
        
        return Compiled.Shader(passes: passes,
                               parameters: parameters,
                               luts: luts,
                               historyCount: historyCount,
                               languageVersion: try .init(options.languageVersion))
    }
    
    func compilePass(_ pass: ShaderPass, options: ShaderCompilerOptions) throws -> Compiled.ShaderPass {
        var ctx: __SPVContext?
        __spvc_context_create(&ctx)
        guard let ctx else {
            throw ShaderError.buildFailed
        }
        defer { ctx.destroy() }
        
        let errorHandler: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?) -> Void = { userData, errorMsg in
            guard
                let userData,
                let errorMsg
            else { return }
            
            let compiler = Unmanaged<ShaderPassCompiler>.fromOpaque(userData).takeUnretainedValue()
            compiler.compileError(String(cString: errorMsg))
        }
        
        spvc_context_set_error_callback(ctx, errorHandler, Unmanaged.passUnretained(self).toOpaque())
        
        let (vsCompiler, fsCompiler) = try makeCompilersForPass(pass, context: ctx, options: options)
        
        var vsCode: UnsafePointer<Int8>?
        vsCompiler.compile(&vsCode)
        
        var fsCode: UnsafePointer<Int8>?
        fsCompiler.compile(&fsCode)
        
        guard let sym = makeSymbols() else { throw ShaderError.processFailed }
        guard let ref = reflect(passNumber: pass.index, withSymbols: sym, withVertexCompiler: vsCompiler, fragmentCompiler: fsCompiler)
        else {
            throw ShaderError.processFailed
        }
        
        let buffers = [
            makeBuffersForSemantics(ref, source: \.ubo, offset: \.uboOffset),
            makeBuffersForSemantics(ref, source: \.push, offset: \.pushOffset),
        ]
        
        let textures = makeTextures(ref, symbols: sym)
        
        return .init(index: pass.index,
                     vertexSource: String(cString: vsCode!),
                     fragmentSource: String(cString: fsCode!),
                     frameCountMod: pass.frameCountMod,
                     scaleX: pass.scaleX,
                     scaleY: pass.scaleY,
                     filter: pass.filter,
                     wrapMode: pass.wrapMode,
                     format: pass.format,
                     isFeedback: false,
                     buffers: buffers,
                     textures: textures,
                     alias: pass.alias)
    }
    
    /// Find all the bound textures for the pass.
    private func makeTextures(_ ref: ShaderPassReflection, symbols sym: ShaderSymbols) -> [Compiled.TextureDescriptor] {
        var textures = [Compiled.TextureDescriptor]()
        
        for (sem, a) in ref.textures {
            for meta in a.values {
                if let binding = meta.binding {
                    let wrap: Compiled.ShaderPassWrap
                    let filter: Compiled.ShaderPassFilter
                    if sem == .user {
                        wrap = shader.luts[meta.index].wrapMode
                        filter = shader.luts[meta.index].filter
                    } else {
                        wrap = shader.passes[ref.passNumber].wrapMode
                        filter = shader.passes[ref.passNumber].filter
                    }
                    
                    textures.append(Compiled.TextureDescriptor(name: meta.name,
                                                               semantic: sem,
                                                               binding: binding,
                                                               wrap: wrap,
                                                               filter: filter,
                                                               index: meta.index))
                }
            }
        }
        
        return textures
    }
    
    /// Find all the bound buffer values for the pass
    private func makeBuffersForSemantics(_ ref: ShaderPassReflection,
                                         source: KeyPath<ShaderPassReflection, BufferBindingDescriptor?>,
                                         offset: KeyPath<ShaderBufferSemanticMeta, Int?>) -> Compiled.BufferDescriptor
    {
        guard let b = ref[keyPath: source]
        else { return .init(bindingVert: nil, bindingFrag: nil, size: 0, uniforms: []) }
        
        // Find bound global semantics, like MVP, FrameCount, etc
        let semantics = ref.semantics.compactMap { sem, meta -> Compiled.BufferUniformDescriptor? in
            if let offset = meta[keyPath: offset] {
                return Compiled.BufferUniformDescriptor(semantic: sem,
                                                        index: nil,
                                                        name: meta.name,
                                                        size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                                        offset: offset)
            }
            return nil
        }
        
        // Find bound parameters
        let parameters = ref.floatParameters.values.compactMap { meta -> Compiled.BufferUniformDescriptor? in
            if let offset = meta[keyPath: offset] {
                return Compiled.BufferUniformDescriptor(semantic: .floatParameter,
                                                        index: meta.index,
                                                        name: meta.name,
                                                        size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                                        offset: offset)
            }
            return nil
        }
        
        // Find bound texture sizes such as OriginalSize, <LUT alias>Size, etc
        let textures = ref.textureUniforms.flatMap { sem, a in
            a.values.compactMap { meta -> Compiled.BufferUniformDescriptor? in
                if let offset = meta[keyPath: offset] {
                    return Compiled.BufferUniformDescriptor(semantic: sem,
                                                            index: meta.index,
                                                            name: meta.name,
                                                            size: 4 * MemoryLayout<Float>.size,
                                                            offset: offset)
                }
                return nil
            }
        }
        
        return .init(bindingVert: b.bindingVert,
                     bindingFrag: b.bindingFrag,
                     size: b.size,
                     uniforms: semantics + parameters + textures)
    }
}
