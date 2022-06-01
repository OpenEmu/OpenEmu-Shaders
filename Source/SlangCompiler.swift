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
import CGLSLang
import CSPIRVTools
import os.log

var initialized: Bool = {
    glslang_initialize_process()
    return true
}()

enum ShaderType {
    case vertex
    case fragment
}

class SlangCompiler {
    func compileSource(_ source: String, ofType type: ShaderType) throws -> Data {
        _ = initialized
        
        switch type {
        case .vertex:
            return try compileSPIRV(source, stage: .vertex)
        case .fragment:
            return try compileSPIRV(source, stage: .fragment)
        @unknown default:
            fatalError("Unexpected type")
        }
    }
    
    static let defaultVersion = Int32(110)
    
    func compileSPIRV(_ src: String, stage: glslang_stage_t) throws -> Data {
        try src.withCString { code in
            var inp = glslang_input_s(
                language: .glsl,
                stage: stage,
                client: .vulkan,
                client_version: .vulkan1_1,
                target_language: .spv,
                target_language_version: .spv1_5,
                code: code,
                default_version: Self.defaultVersion,
                default_profile: .noProfile,
                force_default_version_and_profile: 0,
                forward_compatible: 0,
                messages: [.default, .vulkanRules, .spvRules],
                resource: glslang_get_default_resource(),
                includer_type: .forbid,
                includer: nil,
                includer_context: nil)
            
            guard let shader = CGLSLangShader(input: &inp)
            else {
                throw NSError(domain: OEShaderErrorDomain, code: OEShaderCompilePreprocessError)
            }
            
            defer { glslang_shader_delete(shader) }
            
            guard shader.preprocess(input: &inp)
            else {
                let msg = shader.preprocessed_code
                os_log(.error, log: .shaders, "Error preprocessing shader: %{public}s", msg)
                
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: NSLocalizedString("Failed to preprocess shader", comment: "Shader failed to compile"),
                    NSLocalizedFailureReasonErrorKey: String(cString: msg),
                ]
                throw NSError(domain: OEShaderErrorDomain,
                              code: OEShaderCompilePreprocessError,
                              userInfo: userInfo)
            }
            
            guard shader.parse(input: &inp)
            else {
                let msg = shader.preprocessed_code
                os_log(.error, log: .shaders, "Error parsing shader: %{public}s", msg)
                
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: NSLocalizedString("Failed to parse shader", comment: "Shader failed to compile"),
                    NSLocalizedFailureReasonErrorKey: String(cString: msg),
                ]
                throw NSError(domain: OEShaderErrorDomain,
                              code: OEShaderCompilePreprocessError,
                              userInfo: userInfo)
            }
            
            let program = CGLSLangProgram()
            defer { glslang_program_delete(program) }
            
            program.add_shader(shader)
            
            guard program.link(messages: inp.messages)
            else {
                let infoLog = program.info_log
                let infoDebugLog = program.info_debug_log
                
                os_log(.error, log: .shaders, "Error linking shader info log: %{public}s", infoLog)
                os_log(.error, log: .shaders, "Error linking shader info debug log: %{public}s", infoDebugLog)
                
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: NSLocalizedString("Failed to link shader", comment: "Shader failed to compile"),
                    NSLocalizedFailureReasonErrorKey: String(cString: infoLog),
                ]
                throw NSError(domain: OEShaderErrorDomain,
                              code: OEShaderCompilePreprocessError,
                              userInfo: userInfo)
            }
            
            program.spirv_generate(stage: stage)
            
            let opt = CSPVTOptimizer(environment: .universal1_5)
            defer { opt.destroy() }
            
            opt.register_ccp_pass()
            opt.register_dead_branch_elim_pass()
            opt.register_aggressive_dce_pass()
            opt.register_ssa_rewrite_pass()
            opt.register_aggressive_dce_pass()
            opt.register_eliminate_dead_constant_pass()
            opt.register_aggressive_dce_pass()
            
            let opts = CSPVTOptimizerOptions()
            defer { opts.destroy() }
            
            opts.setRunValidator(false)
            let vec = opt.run(original: program.spirv_pointer, size: program.spirv_size, options: opts)
            
            var spirv: Data
            if let vec = vec {
                let buf = UnsafeBufferPointer(start: vec.ptr.assumingMemoryBound(to: UInt32.self), count: vec.size / MemoryLayout<UInt32>.size)
                spirv = Data(buffer: buf)
            } else {
                let buf = UnsafeBufferPointer(start: program.spirv_pointer, count: program.spirv_size)
                spirv = Data(buffer: buf)
            }
            
            return spirv
        }
    }
    
}
