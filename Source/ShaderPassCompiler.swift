// Copyright (c) 2021, OpenEmu Team
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
import os.log

public class ShaderPassCompiler {
    public enum ShaderError: Error {
        case buildFailed
        case processFailed
    }
    
    let shader: SlangShader
    let bindings: [ShaderPassBindings]
    private(set) var historyCount: Int = 0
    
    public init(shaderModel shader: SlangShader) {
        self.shader     = shader
        self.bindings   = (0..<shader.passes.count).map(ShaderPassBindings.init)
    }
    
    public func buildPass(_ passNumber: Int, options: ShaderCompilerOptions, passSemantics: ShaderPassSemantics?) throws -> (vert: String, frag: String) {
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
        let pass = shader.passes[passNumber]
        let bind = bindings[passNumber]
        bind.format = pass.format
        
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
        
        if let passSemantics = passSemantics {
            guard let ref = makeReflection(passNumber,
                                           withVertexCompiler: vsCompiler,
                                           fragmentCompiler: fsCompiler,
                                           passSemantics: passSemantics,
                                           passBindings: bind)
            else {
                throw ShaderError.processFailed
            }
            updateBindings(passSemantics: passSemantics, passBindings: bind, ref: ref)
        }
        return (String(cString: vsCode!), String(cString: fsCode!))
    }
    
    private func compileError(_ error: String) {
        
    }
    
    private func makeVersion(major: Int, minor: Int, patch: Int = 0) -> UInt32 {
        UInt32(major * 10000 + minor * 100 + patch)
    }
    
    func makeCompilersForPass(
        _ pass: ShaderPass,
        context ctx: __SPVContext,
        options: ShaderCompilerOptions,
        vertexCompiler vsCompiler: UnsafeMutablePointer<SPVCompiler?>,
        fragmentCompiler fsCompiler: UnsafeMutablePointer<SPVCompiler?>
    ) throws {
        let version: UInt32
        switch options.languageVersion {
        case .version2_4:
            version = makeVersion(major: 2, minor: 4)
        case .version2_3:
            version = makeVersion(major: 2, minor: 3)
        case .version2_2:
            version = makeVersion(major: 2, minor: 2)
        default:
            version = makeVersion(major: 2, minor: 1)
        }
        
        let vsData = try irForPass(pass, ofType: .vertex, options: options)
        var vsIR: SPVParsedIR?
        vsData.withUnsafeBytes { buf in
            _ = ctx.parse(data: buf.bindMemory(to: SpvId.self).baseAddress, buf.count / MemoryLayout<SpvId>.size, &vsIR)
        }
        guard let vsIR = vsIR else {
            // os_log_error(OE_LOG_DEFAULT, "error parsing vertex spirv '%@'", pass.url.absoluteString)
            return
        }
        
        ctx.create_compiler(backend: .msl, ir: vsIR, captureMode: .takeOwnership, compiler: vsCompiler)

        guard let vsCompiler = vsCompiler.pointee else {
            // os_log_error(OE_LOG_DEFAULT, "error creating vertex compiler '%@'", pass.url.absoluteString)
            return
        }
        
        // vertex compile
        var vsOptions: SPVCompilerOptions?
        vsCompiler.create_compiler_options(&vsOptions)
        guard let vsOptions = vsOptions else {
            return
        }
        vsOptions.set_uint(option: SPVC_COMPILER_OPTION_MSL_VERSION, with: version)
        vsCompiler.install_compiler_options(options: vsOptions)
        
        // fragment shader
        let fsData = try irForPass(pass, ofType: .fragment, options: options)
        var fsIR: SPVParsedIR?
        fsData.withUnsafeBytes { buf in
            _ = ctx.parse(data: buf.bindMemory(to: SpvId.self).baseAddress, buf.count / MemoryLayout<SpvId>.size, &fsIR)
        }
        guard let fsIR = fsIR else {
            // os_log_error(OE_LOG_DEFAULT, "error parsing fragment spirv '%@'", pass.url.absoluteString)
            return
        }
        
        ctx.create_compiler(backend: .msl, ir: fsIR, captureMode: .takeOwnership, compiler: fsCompiler)

        guard let fsCompiler = fsCompiler.pointee else {
            // os_log_error(OE_LOG_DEFAULT, "error creating fragment compiler '%@'", pass.url.absoluteString)
            return
        }
        
        // fragment compile
        var fsOptions: SPVCompilerOptions?
        fsCompiler.create_compiler_options(&fsOptions)
        guard let fsOptions = fsOptions else {
            return
        }
        fsOptions.set_uint(option: SPVC_COMPILER_OPTION_MSL_VERSION, with: version)
        fsCompiler.install_compiler_options(options: fsOptions)
    }
    
    func irForPass(_ pass: ShaderPass, ofType type: ShaderType, options: ShaderCompilerOptions) throws -> Data {
        var filename: URL?
        
        // If caching, set the filename and try loading the IR data
        if let cacheDir = options.cacheDir, !options.isCacheDisabled {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            if let version = Bundle(for: Self.self).infoDictionary?["CFBundleShortVersionString"] as? String {
                let vorf    = type == .vertex ? "vert" : "frag"
                let file    = "\(pass.source.basename).\(pass.source.sha256).\(version.versionValue).\(vorf).spirv"
                filename = cacheDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: filename!) {
                    return data
                }
            }
        }
        
        let source = type == .vertex ? pass.source.vertexSource : pass.source.fragmentSource
        let c = SlangCompiler()
        let data = try c.compileSource(source, ofType: type)
        if let filename = filename {
            // Ignore any error if we can't write
            try? data.write(to: filename, options: .atomic)
        }
        return data
    }
    
    func updateBindings(passSemantics: ShaderPassSemantics, passBindings: ShaderPassBindings, ref: ShaderReflection) {
        // UBO
        let uboB = passBindings.buffers[0]
        if let b = ref.ubo {
            uboB.bindingVert = b.bindingVert
            uboB.bindingFrag = b.bindingFrag
            uboB.size        = (b.size + 0xf) & ~0xf // round up to nearest 16 bytes
        }
        
        // push constants
        let pshB = passBindings.buffers[1]
        if let b = ref.push {
            pshB.bindingVert = b.bindingVert
            pshB.bindingFrag = b.bindingFrag
            pshB.size        = (b.size + 0xf) & ~0xf // round up to nearest 16 bytes
        }
        
        for (sem, meta) in ref.semantics {
            let name = ref.name(forBufferSemantic: sem, index: 0)!
            if let offset = meta.uboOffset {
                uboB.addUniformData(passSemantics.uniforms[sem]!.data,
                                    size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                    offset: offset,
                                    name: name)
            }
            if let offset = meta.pushOffset {
                pshB.addUniformData(passSemantics.uniforms[sem]!.data,
                                    size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                    offset: offset,
                                    name: name)
            }
        }
        
        for meta in ref.floatParameters.values {
            let name = ref.name(forBufferSemantic: .floatParameter, index: meta.index)!
            guard let param = passSemantics.parameter(at: meta.index)
            else { fatalError("Unable to find parameter at index \(meta.index)") }
            
            if let offset = meta.uboOffset {
                uboB.addUniformData(param.data,
                                    size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                    offset: offset,
                                    name: name)
            }
            if let offset = meta.pushOffset {
                pshB.addUniformData(param.data,
                                    size: meta.numberOfComponents * MemoryLayout<Float>.size,
                                    offset: offset,
                                    name: name)
            }
        }
        
        for (sem, a) in ref.textures {
            let tex = passSemantics.textures[sem]!
            for meta in a.values where meta.binding != nil || meta.uboOffset != nil || meta.pushOffset != nil {
                if let binding = meta.binding {
                    let ptr = tex.texture.advanced(by: meta.index * tex.textureStride)
                    let bind = passBindings.addTexture(ptr)
                    
                    if sem == .user {
                        bind.wrap   = shader.luts[meta.index].wrapMode
                        bind.filter = shader.luts[meta.index].filter
                    } else {
                        bind.wrap   = shader.passes[ref.passNumber].wrapMode
                        bind.filter = shader.passes[ref.passNumber].filter
                    }
                    
                    bind.binding    = binding
                    bind.name       = ref.name(forTextureSemantic: sem, index: meta.index)!
                    
                    if sem == .passFeedback {
                        bindings[meta.index].isFeedback = true
                    } else if sem == .originalHistory && historyCount < meta.index {
                        historyCount = meta.index
                    }
                }
                
                let name = ref.sizeName(forTextureSemantic: sem, index: meta.index)!
                if let offset = meta.uboOffset {
                    uboB.addUniformData(tex.textureSize.advanced(by: meta.index * tex.sizeStride),
                                        size: 4 * MemoryLayout<Float>.size,
                                        offset: offset,
                                        name: name)
                }
                if let offset = meta.pushOffset {
                    pshB.addUniformData(tex.textureSize.advanced(by: meta.index * tex.sizeStride),
                                        size: 4 * MemoryLayout<Float>.size,
                                        offset: offset,
                                        name: name)
                }
            }
        }
    }
    
    func makeReflection(_ passNumber: Int,
                        withVertexCompiler vsCompiler: SPVCompiler,
                        fragmentCompiler fsCompiler: SPVCompiler,
                        passSemantics: ShaderPassSemantics,
                        passBindings: ShaderPassBindings) -> ShaderReflection? {
        let ref = ShaderReflection(passNumber: passNumber)
        
        // add aliases
        for pass in shader.passes.prefix(passNumber + 1) {
            guard let name = pass.alias, !name.isEmpty else { continue }
            
            let index = pass.index
            
            guard ref.addTextureSemantic(.passOutput, atIndex: index, name: name) else { return nil }
            guard ref.addTextureBufferSemantic(.passOutput, atIndex: index, name: "\(name)Size") else { return nil }
            guard ref.addTextureSemantic(.passFeedback, atIndex: index, name: "\(name)Feedback") else { return nil }
            guard ref.addTextureBufferSemantic(.passFeedback, atIndex: index, name: "\(name)FeedbackSize") else { return nil }
        }
        
        for (i, lut) in shader.luts.enumerated() {
            guard ref.addTextureSemantic(.user, atIndex: i, name: lut.name) else { return nil }
            guard ref.addTextureBufferSemantic(.user, atIndex: i, name: "\(lut.name)Size") else { return nil }
        }
        
        for (i, param) in shader.parameters.enumerated() {
            guard ref.addBufferSemantic(.floatParameter, atIndex: i, name: param.name) else { return nil }
        }
        
        guard reflectWith(ref, withVertexCompiler: vsCompiler, fragmentCompiler: fsCompiler)
        else {
            // os_log_error(OE_LOG_DEFAULT, "reflect failed");
            return nil
        }
        
        return ref
    }

    private enum ValidationError: Error {
        case apiError
        case unexpectedResource
    }
    
    private func validateResources(vsResources: SPVResources, fsResources: SPVResources) throws {
        
        func checkEmpty(_ r: SPVResources, _ t: SPVResourceType) throws {
            var list: UnsafePointer<__spvc_reflected_resource>?
            var listSize = 0
            if r.get_resource_list_for_type(type: t, list: &list, size: &listSize).errorResult != nil {
                throw ValidationError.apiError
            }
            guard listSize == 0
            else {
                // os_log_error(OE_LOG_DEFAULT, "unexpected resource type in shader %{public}@", @#TYPE); \
                throw ValidationError.unexpectedResource
            }
        }

        try checkEmpty(vsResources, .sampledImage)
        try checkEmpty(vsResources, .storageBuffer)
        try checkEmpty(vsResources, .subpassInput)
        try checkEmpty(vsResources, .storageImage)
        try checkEmpty(vsResources, .atomicCounter)
        try checkEmpty(fsResources, .storageBuffer)
        try checkEmpty(fsResources, .subpassInput)
        try checkEmpty(fsResources, .storageImage)
        try checkEmpty(fsResources, .atomicCounter)
    }

    // swiftlint: disable cyclomatic_complexity
    func reflectWith(_ ref: ShaderReflection, withVertexCompiler vsCompiler: SPVCompiler, fragmentCompiler fsCompiler: SPVCompiler) -> Bool {
        var vsResources: SPVResources?
        vsCompiler.create_shader_resources(&vsResources)
        guard let vsResources = vsResources else {
            return false
        }
        
        var fsResources: SPVResources?
        fsCompiler.create_shader_resources(&fsResources)
        guard let fsResources = fsResources else {
            return false
        }
        
        do {
            try validateResources(vsResources: vsResources, fsResources: fsResources)
        } catch {
            return false
        }

        // validate input to vertex shader
        var list: UnsafePointer<__spvc_reflected_resource>?
        var listSize = 0
        vsResources.get_resource_list_for_type(type: .stageInput, list: &list, size: &listSize)
        
        if listSize != 2 {
            // os_log_error(OE_LOG_DEFAULT, "vertex shader input must have two attributes");
            return false
        }
        
        var resources = UnsafeBufferPointer<__spvc_reflected_resource>(start: list, count: listSize)
        
        var mask: UInt = 0
        mask |= 1 << vsCompiler.get_decoration(id: resources[0].id, decoration: .location)
        mask |= 1 << vsCompiler.get_decoration(id: resources[1].id, decoration: .location)
        if mask != 3 {
            // os_log_error(OE_LOG_DEFAULT, "vertex shader input attributes must use (location = 0) and (location = 1)");
            return false
        }
        
        // validate number of render targets for fragment shader
        listSize = 0
        fsResources.get_resource_list_for_type(type: .stageOutput, list: &list, size: &listSize)
        
        if listSize != 1 {
            // os_log_error(OE_LOG_DEFAULT, "fragment shader must have a single output");
            return false
        }
        
        resources = UnsafeBufferPointer<__spvc_reflected_resource>(start: list, count: listSize)
        if fsCompiler.get_decoration(id: resources[0].id, decoration: .location) != 0 {
            // os_log_error(OE_LOG_DEFAULT, "fragment shader output must use (location = 0)");
            return false
        }
        
        // get uniform and push buffers
        func getResource(_ r: SPVResources, _ t: SPVResourceType, _ err: String) throws -> __spvc_reflected_resource? {
            var list: UnsafePointer<__spvc_reflected_resource>?
            var listSize = 0
            if r.get_resource_list_for_type(type: t, list: &list, size: &listSize).errorResult != nil {
                throw ValidationError.apiError
            }
            guard listSize < 2
            else {
                // os_log_error(OE_LOG_DEFAULT, err);
                throw ValidationError.unexpectedResource
            }
            
            return listSize == 1 ? list?.pointee : nil
        }

        // vertex UBO binding
        var vertexUBO: __spvc_reflected_resource?
        do {
            if let br = try getResource(vsResources, .uniformBuffer, "vertex shader must use zero or one uniform buffer") {
                vertexUBO = br
                if vsCompiler.get_decoration(id: br.id, decoration: .descriptorSet) != 0 {
                    // os_log_error(OE_LOG_DEFAULT, "vertex shader resources must use descriptor set #0");
                    return false
                }
                
                let binding = Int(vsCompiler.mslGetAutomaticResourceBinding(br.id))
                var desc = ref.ubo ?? BufferBindingDescriptor()
                desc.bindingVert = binding
                var sz = 0
                vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(br.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.ubo = desc
            }
        } catch {
            return false
        }

        // fragment UBO binding
        var fragmentUBO: __spvc_reflected_resource?
        do {
            if let br = try getResource(fsResources, .uniformBuffer, "fragment shader must use zero or one uniform buffer") {
                fragmentUBO = br
                if fsCompiler.get_decoration(id: br.id, decoration: .descriptorSet) != 0 {
                    // os_log_error(OE_LOG_DEFAULT, "fragment shader resources must use descriptor set #0");
                    return false
                }
                
                let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(br.id))
                var desc = ref.ubo ?? BufferBindingDescriptor()
                desc.bindingFrag = binding
                var sz = 0
                fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(br.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.ubo = desc
            }
        } catch {
            return false
        }

        // vertex Push binding
        var vertexPSH: __spvc_reflected_resource?
        do {
            if let br = try getResource(vsResources, .pushConstant, "vertex shader must use zero or one push constant buffer") {
                vertexPSH = br
                let binding = Int(vsCompiler.mslGetAutomaticResourceBinding(br.id))
                var desc = ref.push ?? BufferBindingDescriptor()
                desc.bindingVert = binding
                var sz = 0
                vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(br.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.push = desc
            }
        } catch {
            return false
        }

        // fragment UBO binding
        var fragmentPSH: __spvc_reflected_resource?
        do {
            if let br = try getResource(fsResources, .pushConstant, "fragment shader must use zero or one push constant buffer") {
                fragmentPSH = br
                let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(br.id))
                var desc = ref.push ?? BufferBindingDescriptor()
                desc.bindingFrag = binding
                var sz = 0
                fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(br.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.push = desc
            }
        } catch {
            return false
        }

        // Find all relevant uniforms and push constants
        if let res = vertexUBO, !addActiveBufferRanges(ref, compiler: vsCompiler, resource: res, ubo: true) {
            return false
        }
        if let res = fragmentUBO, !addActiveBufferRanges(ref, compiler: fsCompiler, resource: res, ubo: true) {
            return false
        }
        if let res = vertexPSH, !addActiveBufferRanges(ref, compiler: vsCompiler, resource: res, ubo: false) {
            return false
        }
        if let res = fragmentPSH, !addActiveBufferRanges(ref, compiler: fsCompiler, resource: res, ubo: false) {
            return false
        }

        listSize = 0
        fsResources.get_resource_list_for_type(type: .sampledImage, list: &list, size: &listSize)
        resources = UnsafeBufferPointer(start: list, count: listSize)
        
        var bindings = 0
        for tex in resources {
            if fsCompiler.get_decoration(id: tex.id, decoration: .descriptorSet) != 0 {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture must use descriptor set #0");
                return false
            }
            
            let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(tex.id))
            guard binding != -1
            else {
                // no binding
                continue
            }
            
            if binding >= Constants.maxShaderBindings {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding exceeds %d", Constants.maxShaderBindings);
                return false
            }
            
            if bindings & (1 << binding) != 0 {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding %lu already in use", binding);
                return false
            }
            
            bindings |= 1 << binding
            let name = String(cString: tex.name)
            guard let sem = ref.textureSemantic(forName: name)
            else {
                // os_log_error(OE_LOG_DEFAULT, "invalid texture %{public}s", tex->name);
                return false
            }
            
            ref.setBinding(binding, forTextureSemantic: sem.semantic, at: sem.index)
        }
        
        os_log(.debug, log: .default, "%{public}@", ref.debugDescription)
        
        return true
    }
    
    func validate(type: __SPVType, forBufferSemantic sem: ShaderBufferSemantic) -> Bool {
        if type.num_array_dimensions > 0 {
            return false
        }
        
        let bt = type.basetype
        if bt != .fp32 && bt != .int32 && bt != .uint32 {
            return false
        }
        
        let vecsz = type.vector_size
        let cols  = type.columns
        
        switch sem {
        case .mvp:
            return bt == .fp32 && vecsz == 4 && cols == 4
            
        case .frameCount:
            return bt == .uint32 && vecsz == 1 && cols == 1
            
        case .frameDirection:
            return bt == .int32 && vecsz == 1 && cols == 1
            
        case .floatParameter:
            return bt == .fp32 && vecsz == 1 && cols == 1
            
        default:
            // all other semantics (Size) are vec4
            return bt == .fp32 && vecsz == 4 && cols == 1
        }
    }
    
    func validate(type: __SPVType, forTextureSemantic sem: ShaderTextureSemantic) -> Bool {
        if type.num_array_dimensions > 0 {
            return false
        }
        
        return type.basetype == .fp32 && type.vector_size == 4 && type.columns == 1
    }
    
    func addActiveBufferRanges(_ ref: ShaderReflection, compiler: SPVCompiler, resource res: __spvc_reflected_resource, ubo: Bool) -> Bool {
        var rangesPtr: UnsafePointer<spvc_buffer_range>?
        var numRanges = 0
        compiler.get_active_buffer_ranges(id: res.id, list: &rangesPtr, size: &numRanges)
        guard let rangesPtr = rangesPtr else {
            return true
        }
        
        let ranges = UnsafeBufferPointer(start: rangesPtr, count: numRanges)
        for range in ranges {
            let name = String(cString: compiler.get_member_name(id: res.base_type_id, index: range.index))
            let type = compiler.get_type_handle(compiler.get_type_handle(res.base_type_id)!.get_member_type(index: range.index))!
            
            let bufferSem = ref.bufferSemantic(forUniformName: name)
            let texSem    = ref.textureSemantic(forUniformName: name)
            
            if let texSem = texSem, texSem.semantic == .passOutput && texSem.index >= ref.passNumber {
                // os_log_error(OE_LOG_DEFAULT, "shader pass #%lu is attempting to use output from self or later pass #%lu", ref.passNumber, texSem.index);
                return false
            }
            
            let vecsz = Int(type.vector_size)
            let cols  = Int(type.columns)
            
            if let bufferSem = bufferSem {
                if !validate(type: type, forBufferSemantic: bufferSem.semantic) {
                    // os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s", name);
                    return false
                }
                
                if bufferSem.semantic == .floatParameter {
                    if !ref.setOffset(range.offset, vecSize: vecsz, forFloatParameterAt: bufferSem.index, ubo: ubo) {
                        return false
                    }
                } else {
                    if !ref.setOffset(range.offset, vecSize: vecsz * cols, forSemantic: bufferSem.semantic, ubo: ubo) {
                        return false
                    }
                }
            } else if let texSem = texSem {
                if !validate(type: type, forTextureSemantic: texSem.semantic) {
                    // os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s; expected a vec4", name);
                    return false
                }
                
                if !ref.setOffset(range.offset, forTextureSemantic: texSem.semantic, at: texSem.index, ubo: ubo) {
                    return false
                }
            }
            
        }

        return true
    }
}

extension SPVResult {
    enum ErrorResult: Int, LocalizedError {
        case invalidSpirv = -1
        case unsupportedSpirv = -2
        case outOfMemory = -3
        case invalidArgument = -4
        case unknownError = 0xffff
        
        init?(_ res: SPVResult) {
            switch res {
            case .invalidSpirv:
                self = .invalidSpirv
            case .unsupportedSpirv:
                self = .unsupportedSpirv
            case .outOfMemory:
                self = .outOfMemory
            case .invalidArgument:
                self = .invalidArgument
            case .success:
                return nil
            default:
                self = .unknownError
            }
        }
    }
    
    var errorResult: ErrorResult? { return ErrorResult(self) }
}
