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
@_implementationOnly import os.log

extension ShaderPassCompiler {
    func makeSymbols() -> ShaderSymbols? {
        let sym = ShaderSymbols()
        
        // add aliases
        for pass in shader.passes {
            guard let name = pass.alias, !name.isEmpty else { continue }
            
            let index = pass.index
            
            guard sym.addTextureSemantic(.passOutput, atIndex: index, name: name) else { return nil }
            guard sym.addTextureBufferSemantic(.passOutputSize, atIndex: index, name: "\(name)Size") else { return nil }
            guard sym.addTextureSemantic(.passFeedback, atIndex: index, name: "\(name)Feedback") else { return nil }
            guard sym.addTextureBufferSemantic(.passFeedbackSize, atIndex: index, name: "\(name)FeedbackSize") else { return nil }
        }
        
        for (i, lut) in shader.luts.enumerated() {
            guard sym.addTextureSemantic(.user, atIndex: i, name: lut.name) else { return nil }
            guard sym.addTextureBufferSemantic(.userSize, atIndex: i, name: "\(lut.name)Size") else { return nil }
        }
        
        for (i, param) in shader.parameters.enumerated() {
            guard sym.addFloatParameterSemantic(atIndex: i, name: param.name) else { return nil }
        }
        
        return sym
    }
    
    // swiftlint:disable cyclomatic_complexity
    func reflect(passNumber: Int, withSymbols sym: ShaderSymbols, withVertexCompiler vsCompiler: SPVCompiler, fragmentCompiler fsCompiler: SPVCompiler) -> ShaderPassReflection? {
        let ref = ShaderPassReflection(passNumber: passNumber)
        
        var vsResources: SPVResources?
        vsCompiler.create_shader_resources(&vsResources)
        guard let vsResources else {
            return nil
        }
        
        var fsResources: SPVResources?
        fsCompiler.create_shader_resources(&fsResources)
        guard let fsResources else {
            return nil
        }
        
        do {
            try validateResources(vsResources: vsResources, fsResources: fsResources)
        } catch {
            return nil
        }

        // validate input to vertex shader
        var list: UnsafePointer<__spvc_reflected_resource>?
        var listSize = 0
        vsResources.get_resource_list_for_type(type: .stageInput, list: &list, size: &listSize)
        
        if listSize != 2 {
            // os_log_error(OE_LOG_DEFAULT, "vertex shader input must have two attributes");
            return nil
        }
        
        var resources = UnsafeBufferPointer<__spvc_reflected_resource>(start: list, count: listSize)
        
        var mask: UInt = 0
        mask |= 1 << vsCompiler.get_decoration(id: resources[0].id, decoration: .location)
        mask |= 1 << vsCompiler.get_decoration(id: resources[1].id, decoration: .location)
        if mask != 3 {
            // os_log_error(OE_LOG_DEFAULT, "vertex shader input attributes must use (location = 0) and (location = 1)");
            return nil
        }
        
        // validate number of render targets for fragment shader
        listSize = 0
        fsResources.get_resource_list_for_type(type: .stageOutput, list: &list, size: &listSize)
        
        if listSize != 1 {
            // os_log_error(OE_LOG_DEFAULT, "fragment shader must have a single output");
            return nil
        }
        
        resources = UnsafeBufferPointer<__spvc_reflected_resource>(start: list, count: listSize)
        if fsCompiler.get_decoration(id: resources[0].id, decoration: .location) != 0 {
            // os_log_error(OE_LOG_DEFAULT, "fragment shader output must use (location = 0)");
            return nil
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
        do {
            if let bufRes = try getResource(vsResources, .uniformBuffer, "vertex shader must use zero or one uniform buffer") {
                if vsCompiler.get_decoration(id: bufRes.id, decoration: .descriptorSet) != 0 {
                    // os_log_error(OE_LOG_DEFAULT, "vertex shader resources must use descriptor set #0");
                    return nil
                }
                
                let binding = Int(vsCompiler.mslGetAutomaticResourceBinding(bufRes.id))
                var desc = ref.ubo ?? BufferBindingDescriptor()
                desc.bindingVert = binding
                var sz = 0
                vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(bufRes.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.ubo = desc
                
                if !addActiveBufferRanges(ref, symbols: sym, compiler: vsCompiler, resource: bufRes, ubo: true) {
                    return nil
                }
            }
        } catch {
            return nil
        }

        // fragment UBO binding
        do {
            if let bufRes = try getResource(fsResources, .uniformBuffer, "fragment shader must use zero or one uniform buffer") {
                if fsCompiler.get_decoration(id: bufRes.id, decoration: .descriptorSet) != 0 {
                    // os_log_error(OE_LOG_DEFAULT, "fragment shader resources must use descriptor set #0");
                    return nil
                }
                
                let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(bufRes.id))
                var desc = ref.ubo ?? BufferBindingDescriptor()
                desc.bindingFrag = binding
                var sz = 0
                fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(bufRes.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.ubo = desc
                
                if !addActiveBufferRanges(ref, symbols: sym, compiler: fsCompiler, resource: bufRes, ubo: true) {
                    return nil
                }
            }
        } catch {
            return nil
        }

        // vertex Push binding
        do {
            if let bufRes = try getResource(vsResources, .pushConstant, "vertex shader must use zero or one push constant buffer") {
                let binding = Int(vsCompiler.mslGetAutomaticResourceBinding(bufRes.id))
                var desc = ref.push ?? BufferBindingDescriptor()
                desc.bindingVert = binding
                var sz = 0
                vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(bufRes.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.push = desc
                
                if !addActiveBufferRanges(ref, symbols: sym, compiler: vsCompiler, resource: bufRes, ubo: false) {
                    return nil
                }
            }
        } catch {
            return nil
        }

        // fragment Push binding
        do {
            if let bufRes = try getResource(fsResources, .pushConstant, "fragment shader must use zero or one push constant buffer") {
                let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(bufRes.id))
                var desc = ref.push ?? BufferBindingDescriptor()
                desc.bindingFrag = binding
                var sz = 0
                fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(bufRes.base_type_id), size: &sz)
                desc.size = max(desc.size, sz)
                ref.push = desc
                
                if !addActiveBufferRanges(ref, symbols: sym, compiler: fsCompiler, resource: bufRes, ubo: false) {
                    return nil
                }
            }
        } catch {
            return nil
        }

        listSize = 0
        fsResources.get_resource_list_for_type(type: .sampledImage, list: &list, size: &listSize)
        resources = UnsafeBufferPointer(start: list, count: listSize)
        
        var bindings = 0
        for tex in resources {
            if fsCompiler.get_decoration(id: tex.id, decoration: .descriptorSet) != 0 {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture must use descriptor set #0");
                return nil
            }
            
            let binding = Int(fsCompiler.mslGetAutomaticResourceBinding(tex.id))
            guard binding != -1
            else {
                // no binding
                continue
            }
            
            if binding >= Constants.maxShaderBindings {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding exceeds %d", Constants.maxShaderBindings);
                return nil
            }
            
            if bindings & (1 << binding) != 0 {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding %lu already in use", binding);
                return nil
            }
            
            bindings |= 1 << binding
            let name = String(cString: tex.name)
            guard let sem = sym.textureSemantic(forName: name)
            else {
                // os_log_error(OE_LOG_DEFAULT, "invalid texture %{public}s", tex->name);
                return nil
            }
            
            ref.setBinding(binding, forTextureSemantic: sem.semantic, at: sem.index, name: sem.name)
        }
        
        os_log(.debug, log: .default, "%{public}@", ref.debugDescription)
        
        return ref
    }
    
    func addActiveBufferRanges(_ ref: ShaderPassReflection, symbols sym: ShaderSymbols, compiler: SPVCompiler, resource res: __spvc_reflected_resource, ubo: Bool) -> Bool {
        var rangesPtr: UnsafePointer<spvc_buffer_range>?
        var numRanges = 0
        compiler.get_active_buffer_ranges(id: res.id, list: &rangesPtr, size: &numRanges)
        guard let rangesPtr else { return true }
        
        let ranges = UnsafeBufferPointer(start: rangesPtr, count: numRanges)
        for range in ranges {
            let name = String(cString: compiler.get_member_name(id: res.base_type_id, index: range.index))
            let type = compiler.get_type_handle(compiler.get_type_handle(res.base_type_id)!.get_member_type(index: range.index))!
            
            if let bufferSem = sym.bufferSemantic(forUniformName: name) {
                if !bufferSem.validateType(type) {
                    // os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s", name);
                    return false
                }
                
                let vecsz = Int(type.vector_size)
                let cols = Int(type.columns)
                
                if bufferSem.semantic == .floatParameter {
                    if !ref.setOffset(range.offset, vecSize: vecsz, forFloatParameterAt: bufferSem.index, name: name, ubo: ubo) {
                        return false
                    }
                } else {
                    if !ref.setOffset(range.offset, vecSize: vecsz * cols, forSemantic: bufferSem.semantic, ubo: ubo) {
                        return false
                    }
                }
            } else if let texSem = sym.textureSemantic(forUniformName: name) {
                if texSem.semantic == .passOutputSize, texSem.index >= ref.passNumber {
                    // os_log_error(OE_LOG_DEFAULT, "shader pass #%lu is attempting to use output from self or later pass #%lu", ref.passNumber, texSem.index);
                    return false
                }
                
                if !texSem.validateType(type) {
                    // os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s; expected a vec4 of type float", name);
                    return false
                }
                
                if !ref.setOffset(range.offset, forTextureSemantic: texSem.semantic, at: texSem.index, name: name, ubo: ubo) {
                    return false
                }
            }
        }

        return true
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
}

class ShaderSymbols {
    private(set) var floatParameterSemanticMap: [String: ShaderBufferSemanticMap] = [:]
    private(set) var textureSemanticMap: [String: ShaderTextureSemanticMap] = [:]
    private(set) var textureUniformSemanticMap: [String: ShaderBufferSemanticMap] = [:]
    
    func addTextureSemantic(_ semantic: Compiled.ShaderTextureSemantic, atIndex i: Int, name: String) -> Bool {
        if textureSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: alias %{public}@ already exists for texture semantic %{public}@",
                   i, name, semantic.description as NSString)
            return false
        }
        
        textureSemanticMap[name] = ShaderTextureSemanticMap(textureSemantic: semantic, index: i, name: name)
        
        return true
    }
    
    func addTextureBufferSemantic(_ semantic: Compiled.ShaderBufferSemantic, atIndex i: Int, name: String) -> Bool {
        if textureUniformSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: alias %{public}@ already exists for texture buffer semantic %{public}@",
                   i, name, semantic.description as NSString)
            return false
        }
        
        textureUniformSemanticMap[name] = ShaderBufferSemanticMap(semantic: semantic, index: i, name: name, baseType: .fp32, vecSize: 4, cols: 1)
        
        return true
    }
    
    func addFloatParameterSemantic(atIndex i: Int, name: String) -> Bool {
        if floatParameterSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: float parameter %{public}@ already exists",
                   i, name)
            return false
        }
        
        floatParameterSemanticMap[name] = ShaderBufferSemanticMap(semantic: .floatParameter,
                                                                  index: i,
                                                                  name: name,
                                                                  baseType: .fp32,
                                                                  vecSize: 1,
                                                                  cols: 1)
        
        return true
    }
    
    func bufferSemantic(forUniformName name: String) -> ShaderBufferSemanticMap? {
        floatParameterSemanticMap[name] ?? Self.semanticUniformNames[name]
    }
    
    func textureSemanticIsArray(_ semantic: Compiled.ShaderTextureSemantic) -> Bool {
        Self.textureSemanticArrays.contains(semantic)
    }
    
    func textureSemantic(forUniformName name: String) -> ShaderBufferSemanticMap? {
        textureUniformSemanticMap[name] ?? Self.textureSemanticForUniformName(name)
    }
    
    func textureSemantic(forName name: String) -> ShaderTextureSemanticMap? {
        textureSemanticMap[name] ?? Self.textureSemanticForName(name)
    }
    
    // MARK: - Private functions
    
    private static func textureSemanticForUniformName(_ name: String) -> ShaderBufferSemanticMap? {
        for (key, sem) in textureSemanticUniformNames {
            if uniformSemanticArrays.contains(sem) {
                // An array texture may be referred to as PassOutput0, PassOutput1, etc
                if name.hasPrefix(key) {
                    // TODO: Validate the suffix is a number and within range
                    let index = Int(name.suffix(from: key.endIndex))
                    return ShaderBufferSemanticMap(semantic: sem, index: index ?? 0, name: name, baseType: .fp32, vecSize: 4, cols: 1)
                }
            } else if name == key {
                return ShaderBufferSemanticMap(semantic: sem, index: 0, name: name, baseType: .fp32, vecSize: 4, cols: 1)
            }
        }
        return nil
    }
    
    private static func textureSemanticForName(_ name: String) -> ShaderTextureSemanticMap? {
        for (key, sem) in textureSemanticNames {
            if textureSemanticArrays.contains(sem) {
                // An array texture may be referred to as PassOutput0, PassOutput1, etc
                if name.hasPrefix(key) {
                    // TODO: Validate the suffix is a number and within range
                    let index = Int(name.suffix(from: key.endIndex))
                    return ShaderTextureSemanticMap(textureSemantic: sem, index: index ?? 0, name: name)
                }
            } else if name == key {
                return ShaderTextureSemanticMap(textureSemantic: sem, index: 0, name: name)
            }
        }
        return nil
    }

    // MARK: - Static variables
    
    static let textureSemanticArrays: Set<Compiled.ShaderTextureSemantic> = [.originalHistory, .passOutput, .passFeedback, .user]
    static let uniformSemanticArrays: Set<Compiled.ShaderBufferSemantic> = [.originalHistorySize, .passOutputSize, .passFeedbackSize, .userSize]
    
    static let textureSemanticNames: [String: Compiled.ShaderTextureSemantic] = [
        "Original": .original,
        "Source": .source,
        "OriginalHistory": .originalHistory,
        "PassOutput": .passOutput,
        "PassFeedback": .passFeedback,
        "User": .user,
    ]
    
    static let textureSemanticUniformNames: [String: Compiled.ShaderBufferSemantic] = [
        "OriginalSize": .originalSize,
        "SourceSize": .sourceSize,
        "OriginalHistorySize": .originalHistorySize,
        "PassOutputSize": .passOutputSize,
        "PassFeedbackSize": .passFeedbackSize,
        "UserSize": .userSize,
    ]
    
    static let semanticUniformNames: [String: ShaderBufferSemanticMap] = [
        "MVP": .init(semantic: .mvp, baseType: .fp32, vecSize: 4, cols: 4),
        "OutputSize": .init(semantic: .outputSize, baseType: .fp32, vecSize: 4, cols: 1),
        "FinalViewportSize": .init(semantic: .finalViewportSize, baseType: .fp32, vecSize: 4, cols: 1),
        "FrameCount": .init(semantic: .frameCount, baseType: .uint32, vecSize: 1, cols: 1),
        "FrameDirection": .init(semantic: .frameDirection, baseType: .int32, vecSize: 1, cols: 1),
    ]
}

class ShaderPassReflection {
    let passNumber: Int
    var ubo: BufferBindingDescriptor?
    var push: BufferBindingDescriptor?
    
    init(passNumber: Int) {
        self.passNumber = passNumber
    }
    
    private(set) var textures: [Compiled.ShaderTextureSemantic: [Int: ShaderTextureSemanticMeta]] = [
        .original: [:],
        .source: [:],
        .originalHistory: [:],
        .passOutput: [:],
        .passFeedback: [:],
        .user: [:],
    ]
    
    private(set) var textureUniforms: [Compiled.ShaderBufferSemantic: [Int: ShaderBufferSemanticMeta]] = [
        .originalSize: [:],
        .sourceSize: [:],
        .originalHistorySize: [:],
        .passOutputSize: [:],
        .passFeedbackSize: [:],
        .userSize: [:],
    ]
    
    private(set) var semantics: [Compiled.ShaderBufferSemantic: ShaderBufferSemanticMeta] = [
        .mvp: .init(.mvp),
        .outputSize: .init(.outputSize),
        .finalViewportSize: .init(.finalViewportSize),
        .frameCount: .init(.frameCount),
        .frameDirection: .init(.frameDirection),
    ]
    
    private(set) var floatParameters: [Int: ShaderBufferSemanticMeta] = [:]

    func setOffset(_ offset: Int, vecSize: Int, forFloatParameterAt index: Int, name: String, ubo: Bool) -> Bool {
        let sem: ShaderBufferSemanticMeta
        if let tmp = floatParameters[index] {
            sem = tmp
        } else {
            sem = ShaderBufferSemanticMeta(index: index, name: name)
            floatParameters[index] = sem
        }
        
        if sem.numberOfComponents != vecSize, sem.uboOffset != nil || sem.pushOffset != nil {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same parameter #%lu (%lu / %lu)",
                   index, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, vecSize: Int, forSemantic semantic: Compiled.ShaderBufferSemantic, ubo: Bool) -> Bool {
        guard let sem = semantics[semantic] else { return false }
        
        if sem.numberOfComponents != vecSize, sem.uboOffset != nil || sem.pushOffset != nil {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same semantic %@ (%lu / %lu)",
                   semantic.description as NSString, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.description as NSString, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.description as NSString, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, forTextureSemantic semantic: Compiled.ShaderBufferSemantic, at index: Int, name: String, ubo: Bool) -> Bool {
        guard var map = textureUniforms[semantic] else { return false }
        var sem: ShaderBufferSemanticMeta
        if let tmp = map[index] {
            sem = tmp
        } else {
            sem = ShaderBufferSemanticMeta(index: index, name: name)
            map[index] = sem
            textureUniforms[semantic] = map
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.description as NSString, index, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.description as NSString, index, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        return true
    }
    
    @discardableResult
    func setBinding(_ binding: Int, forTextureSemantic semantic: Compiled.ShaderTextureSemantic, at index: Int, name: String) -> Bool {
        guard var map = textures[semantic] else { return false }
        var sem: ShaderTextureSemanticMeta
        if let tmp = map[index] {
            sem = tmp
        } else {
            sem = ShaderTextureSemanticMeta(index: index, name: name)
            map[index] = sem
            textures[semantic] = map
        }
        
        sem.binding = binding
        
        return true
    }
}

extension ShaderPassReflection: CustomDebugStringConvertible {
    var debugDescription: String {
        var desc = ""
        desc.append("\n")
        desc.append("  → textures:\n")
        
        for sem in Compiled.ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.binding != nil {
                desc.append(String(format: "      %@ (%@ #%lu)\n",
                                   sem.description as NSString, meta.name as NSString, meta.index))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Uniforms (vertex: %@, fragment %@):\n",
                           ubo?.bindingVert != nil ? "YES" : "NO",
                           ubo?.bindingFrag != nil ? "YES" : "NO"))
        
        for sem in Compiled.ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], let offset = meta.uboOffset {
                desc.append(String(format: "      %@ (offset: %lu)\n",
                                   sem.description as NSString, offset))
            }
        }
        
        for sem in Compiled.ShaderBufferSemantic.allCases {
            guard let t = textureUniforms[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.uboOffset != nil {
                desc.append(String(format: "      %@ (#%lu) (offset: %lu)\n",
                                   meta.name as NSString, meta.index, meta.uboOffset!))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Push (vertex: %@, fragment %@):\n",
                           push?.bindingVert != nil ? "YES" : "NO",
                           push?.bindingFrag != nil ? "YES" : "NO"))
        
        for sem in Compiled.ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], let offset = meta.pushOffset {
                desc.append(String(format: "      %@ (offset: %lu)\n",
                                   sem.description as NSString, offset))
            }
        }
        
        for sem in Compiled.ShaderBufferSemantic.allCases {
            guard let t = textureUniforms[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.pushOffset != nil {
                desc.append(String(format: "      %@ (#%lu) (offset: %lu)\n",
                                   meta.name as NSString, meta.index, meta.pushOffset!))
            }
        }
        
        desc.append("\n")
        desc.append("  → Parameters:\n")
        
        for meta in floatParameters.values.sorted(by: { $0.index < $1.index }) {
            if let offset = meta.uboOffset {
                desc.append(String(format: "      UBO  %@ #%lu (offset: %lu)\n", meta.name, meta.index, offset))
            }
            if let offset = meta.pushOffset {
                desc.append(String(format: "      PUSH %@ #%lu (offset: %lu)\n", meta.name, meta.index, offset))
            }
        }
        
        desc.append("\n")
        
        return desc
    }
}
