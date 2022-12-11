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

@_implementationOnly import CSPIRVCross
import Foundation
@_implementationOnly import os.log

public class ShaderPassCompiler {
    public enum ShaderError: Error {
        case buildFailed
        case processFailed
    }
    
    let shader: SlangShader
    
    public init(shaderModel shader: SlangShader) {
        self.shader = shader
    }
    
    func compileError(_ error: String) {}
    
    private func makeVersion(major: Int, minor: Int, patch: Int = 0) -> UInt32 {
        UInt32(major * 10000 + minor * 100 + patch)
    }
    
    func makeCompilersForPass(
        _ pass: ShaderPass,
        context ctx: __SPVContext,
        options: ShaderCompilerOptions) throws -> (vsCompiler: SPVCompiler, fsCompiler: SPVCompiler)
    {
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
        guard let vsIR else {
            // os_log_error(OE_LOG_DEFAULT, "error parsing vertex spirv '%@'", pass.url.absoluteString)
            throw ShaderError.buildFailed
        }
        
        var vsCompiler: SPVCompiler?
        ctx.create_compiler(backend: .msl, ir: vsIR, captureMode: .takeOwnership, compiler: &vsCompiler)

        guard let vsCompiler else {
            // os_log_error(OE_LOG_DEFAULT, "error creating vertex compiler '%@'", pass.url.absoluteString)
            throw ShaderError.buildFailed
        }
        
        // vertex compile
        var vsOptions: SPVCompilerOptions?
        vsCompiler.create_compiler_options(&vsOptions)
        guard let vsOptions else {
            throw ShaderError.buildFailed
        }
        vsOptions.set_uint(option: SPVC_COMPILER_OPTION_MSL_VERSION, with: version)
        vsCompiler.install_compiler_options(options: vsOptions)
        
        // fragment shader
        let fsData = try irForPass(pass, ofType: .fragment, options: options)
        var fsIR: SPVParsedIR?
        fsData.withUnsafeBytes { buf in
            _ = ctx.parse(data: buf.bindMemory(to: SpvId.self).baseAddress, buf.count / MemoryLayout<SpvId>.size, &fsIR)
        }
        guard let fsIR else {
            // os_log_error(OE_LOG_DEFAULT, "error parsing fragment spirv '%@'", pass.url.absoluteString)
            throw ShaderError.buildFailed
        }
        
        var fsCompiler: SPVCompiler?
        ctx.create_compiler(backend: .msl, ir: fsIR, captureMode: .takeOwnership, compiler: &fsCompiler)

        guard let fsCompiler else {
            // os_log_error(OE_LOG_DEFAULT, "error creating fragment compiler '%@'", pass.url.absoluteString)
            throw ShaderError.buildFailed
        }
        
        // fragment compile
        var fsOptions: SPVCompilerOptions?
        fsCompiler.create_compiler_options(&fsOptions)
        guard let fsOptions else {
            throw ShaderError.buildFailed
        }
        fsOptions.set_uint(option: SPVC_COMPILER_OPTION_MSL_VERSION, with: version)
        fsCompiler.install_compiler_options(options: fsOptions)
        
        return (vsCompiler, fsCompiler)
    }
    
    func irForPass(_ pass: ShaderPass, ofType type: ShaderType, options: ShaderCompilerOptions) throws -> Data {
        var filename: URL?
        
        // If caching, set the filename and try loading the IR data
        if let cacheDir = options.cacheDir, !options.isCacheDisabled {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            if let version = Bundle(for: Self.self).infoDictionary?["CFBundleShortVersionString"] as? String {
                let vorf = type == .vertex ? "vert" : "frag"
                let file = "\(pass.source.basename).\(pass.source.sha256).\(version.versionValue).\(vorf).spirv"
                filename = cacheDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: filename!) {
                    return data
                }
            }
        }
        
        let source = type == .vertex ? pass.source.vertexSource : pass.source.fragmentSource
        let c = SlangCompiler()
        let data = try c.compileSource(source, ofType: type)
        if let filename {
            // Ignore any error if we can't write
            try? data.write(to: filename, options: .atomic)
        }
        return data
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
    
    var errorResult: ErrorResult? { ErrorResult(self) }
}
