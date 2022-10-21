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

import ArgumentParser
import Compression
import Foundation
import OpenEmuShaders

extension OEShaders {
    enum LanguageVersion: String, Codable, ExpressibleByArgument {
        // case v30 = "3.0"
        case v24 = "2.4"
        case v23 = "2.3"
        case v22 = "2.2"
        case v21 = "2.1"
        
        static var `default`: Self {
            .v24
        }
    }

    struct Compile: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Compile a shader effects into a single bundle.")
        
        @Flag(inversion: .prefixedEnableDisable)
        var cache: Bool = true
        
        @Argument(help: "Name of Slang shader",
                  transform: { URL(fileURLWithPath: $0) })
        var shaderPath: URL
        
        @Argument(help: .init("Name of shader bundle",
                              discussion: "If omitted, will default to the shader path name and .oecompiledshader extension."),
                  transform: { URL(fileURLWithPath: $0) })
        var outputPath: URL?
        
        @Argument(help: .init("Metal language version",
                              discussion: "Specify the desired Metal language version used to generate the compiled shader."))
        var languageVersion: LanguageVersion = .default
        
        func run() throws {
            let shader: SlangShader
            do {
                shader = try SlangShader(fromURL: shaderPath)
            } catch {
                print("Failed to load shader: \(error.localizedDescription)")
                throw ExitCode.failure
            }
            
            let options = ShaderCompilerOptions()
            options.isCacheDisabled = cache == false
            switch languageVersion {
            case .v24:
                options.languageVersion = .version2_4
            case .v23:
                options.languageVersion = .version2_3
            case .v22:
                options.languageVersion = .version2_2
            case .v21:
                options.languageVersion = .version2_1
            }
            let compiler = ShaderPassCompiler(shaderModel: shader)
            let res = try compiler.compile(options: options)
            
            var out: URL
            if let outputPath {
                out = outputPath
            } else {
                out = URL(fileURLWithPath: shaderPath.deletingPathExtension().lastPathComponent.appending(".oecompiledshader"))
            }
            
            try ZipCompiledShaderContainer.encode(shader: res, to: out)
        }
    }
}
