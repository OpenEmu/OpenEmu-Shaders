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

@objc extension OEShaderPassCompiler {
    @nonobjc public func buildPass(_ passNumber: Int, options: ShaderCompilerOptions, passSemantics: ShaderPassSemantics?) throws -> (vert: String, frag: String) {
        var vert: NSString?, frag: NSString?
        try __buildPass(UInt(passNumber), options: options, passSemantics: passSemantics, vertex: &vert, fragment: &frag)
        
        return (vert! as String, frag! as String)
    }

    // swiftlint: disable cyclomatic_complexity
    public func reflectWith(_ ref: ShaderReflection, withVertexCompiler vsCompiler: SPVCompiler, fragmentCompiler fsCompiler: SPVCompiler) -> Bool {
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
        
        enum CheckError: Error {
            case apiError
            case unexpectedResource
        }

        func checkEmpty(_ r: SPVResources, _ t: SPVResourceType) throws {
            var list: UnsafePointer<__spvc_reflected_resource>?
            var listSize = 0
            if r.get_resource_list_for_type(type: t, list: &list, size: &listSize).errorResult != nil {
                throw CheckError.apiError
            }
            guard listSize == 0
            else {
                // os_log_error(OE_LOG_DEFAULT, "unexpected resource type in shader %{public}@", @#TYPE); \
                throw CheckError.unexpectedResource
            }
        }

        do {
            try checkEmpty(vsResources, .sampledImage)
            try checkEmpty(vsResources, .storageBuffer)
            try checkEmpty(vsResources, .subpassInput)
            try checkEmpty(vsResources, .storageImage)
            try checkEmpty(vsResources, .atomicCounter)
            try checkEmpty(fsResources, .storageBuffer)
            try checkEmpty(fsResources, .subpassInput)
            try checkEmpty(fsResources, .storageImage)
            try checkEmpty(fsResources, .atomicCounter)
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
                throw CheckError.apiError
            }
            guard listSize < 2
            else {
                // os_log_error(OE_LOG_DEFAULT, err);
                throw CheckError.unexpectedResource
            }
            
            return listSize == 1 ? list?.pointee : nil
        }
        
        let vertexUBO: __spvc_reflected_resource?
        let vertexPSH: __spvc_reflected_resource?
        let fragmentUBO: __spvc_reflected_resource?
        let fragmentPSH: __spvc_reflected_resource?
        do {
            vertexUBO = try getResource(vsResources, .uniformBuffer, "vertex shader must use zero or one uniform buffer")
            vertexPSH = try getResource(vsResources, .pushConstant, "vertex shader must use zero or one push constant buffer")
            fragmentUBO = try getResource(fsResources, .uniformBuffer, "fragment shader must use zero or one uniform buffer")
            fragmentPSH = try getResource(fsResources, .pushConstant, "fragment shader must use zero or one push constant buffer")
        } catch {
            return false
        }
        
        if let ubo = vertexUBO, vsCompiler.get_decoration(id: ubo.id, decoration: .descriptorSet) != 0 {
            // os_log_error(OE_LOG_DEFAULT, "vertex shader resources must use descriptor set #0");
            return false
        }
        
        if let ubo = fragmentUBO, fsCompiler.get_decoration(id: ubo.id, decoration: .descriptorSet) != 0 {
            // os_log_error(OE_LOG_DEFAULT, "fragment shader resources must use descriptor set #0");
            return false
        }
        
        let vertexUBOBinding = vertexUBO != nil ? vsCompiler.mslGetAutomaticResourceBinding(vertexUBO!.id) : .max
        let fragmentUBOBinding = fragmentUBO != nil ? fsCompiler.mslGetAutomaticResourceBinding(fragmentUBO!.id) : .max
        let hasVertUBO = vertexUBO != nil && vertexUBOBinding != .max
        let hasFragUBO = fragmentUBO != nil && fragmentUBOBinding != .max
        ref.uboBindingVert = hasVertUBO ? UInt(vertexUBOBinding) : 0
        ref.uboBindingFrag = hasFragUBO ? UInt(fragmentUBOBinding) : 0
        
        let vertexPSHBinding = vertexPSH != nil ? vsCompiler.mslGetAutomaticResourceBinding(vertexPSH!.id) : .max
        let fragmentPSHBinding = fragmentPSH != nil ? fsCompiler.mslGetAutomaticResourceBinding(fragmentPSH!.id) : .max
        let hasVertPSH = vertexPSH != nil && vertexPSHBinding != .max
        let hasFragPSH = fragmentPSH != nil && fragmentPSHBinding != .max
        ref.pushBindingVert = hasVertPSH ? UInt(vertexPSHBinding) : 0
        ref.pushBindingFrag = hasFragPSH ? UInt(fragmentPSHBinding) : 0
        
        if hasVertUBO {
            ref.uboStageUsage = .vertex
            var sz = 0
            vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(vertexUBO!.base_type_id), size: &sz)
            ref.uboSize = sz
        }
        
        if hasVertPSH {
            ref.pushStageUsage = .vertex
            var sz = 0
            vsCompiler.get_declared_struct_size(type: vsCompiler.get_type_handle(vertexPSH!.base_type_id), size: &sz)
            ref.pushSize = sz
        }
        
        if hasFragUBO {
            ref.uboStageUsage.insert(.fragment)
            var sz = 0
            fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(fragmentUBO!.base_type_id), size: &sz)
            ref.uboSize = max(ref.uboSize, sz)
        }
        
        if hasFragPSH {
            ref.pushStageUsage.insert(.fragment)
            var sz = 0
            fsCompiler.get_declared_struct_size(type: fsCompiler.get_type_handle(fragmentPSH!.base_type_id), size: &sz)
            ref.pushSize = max(ref.pushSize, sz)
        }
        
        // Find all relevant uniforms and push constants
        if hasVertUBO && !addActiveBufferRanges(ref, compiler: vsCompiler, resource: vertexUBO!, ubo: true) {
            return false
        }
        if hasFragUBO && !addActiveBufferRanges(ref, compiler: fsCompiler, resource: fragmentUBO!, ubo: true) {
            return false
        }
        if hasVertPSH && !addActiveBufferRanges(ref, compiler: vsCompiler, resource: vertexPSH!, ubo: false) {
            return false
        }
        if hasFragPSH && !addActiveBufferRanges(ref, compiler: fsCompiler, resource: fragmentPSH!, ubo: false) {
            return false
        }

        listSize = 0
        fsResources.get_resource_list_for_type(type: .sampledImage, list: &list, size: &listSize)
        resources = UnsafeBufferPointer(start: list, count: listSize)
        
        var bindings: UInt = 0
        for tex in resources {
            if fsCompiler.get_decoration(id: tex.id, decoration: .descriptorSet) != 0 {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture must use descriptor set #0");
                return false
            }
            
            let binding = fsCompiler.mslGetAutomaticResourceBinding(tex.id)
            guard binding != -1
            else {
                // no binding
                continue
            }
            
            if binding >= kMaxShaderBindings {
                // os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding exceeds %d", kMaxShaderBindings);
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
            
            ref.setBinding(UInt(binding), forTextureSemantic: sem.semantic, at: sem.index)
        }
        
        os_log(.debug, log: .shaders, "%{public}@", ref.debugDescription)
        
        return true
    }
    
    @nonobjc func validate(type: __SPVType, forBufferSemantic sem: OEShaderBufferSemantic) -> Bool {
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
    
    @nonobjc func validate(type: __SPVType, forTextureSemantic sem: OEShaderTextureSemantic) -> Bool {
        if type.num_array_dimensions > 0 {
            return false
        }
        
        return type.basetype == .fp32 && type.vector_size == 4 && type.columns == 1
    }
    
    @nonobjc func addActiveBufferRanges(_ ref: ShaderReflection, compiler: SPVCompiler, resource res: __spvc_reflected_resource, ubo: Bool) -> Bool {
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
            
            let vecsz = type.vector_size
            let cols  = type.columns
            
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
