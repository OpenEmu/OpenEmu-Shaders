//
//  FilterChain+Shader.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 19/10/2022.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation
@_implementationOnly import os.log
@_implementationOnly import QuartzCore

public extension FilterChain {
    func setShader(fromURL url: URL, options shaderOptions: ShaderCompilerOptions) throws {
        os_log("Loading shader from '%{public}@'", log: .default, type: .debug, url.absoluteString)
        
        let start = CACurrentMediaTime()
        
        let shader = try SlangShader(fromURL: url)
        let compiler = ShaderPassCompiler(shaderModel: shader)
        
        os_log("Compiling shader from '%{public}@'", log: .default, type: .debug, url.absoluteString)
        
        let compiled = try compiler.compile(options: shaderOptions)
        let sc = FileCompiledShaderContainer.Decoder(shader: compiled)
        
        let end = CACurrentMediaTime() - start
        os_log("Shader compilation completed in %{xcode:interval}f seconds", log: .default, type: .debug, end)
        
        try setCompiledShader(sc)
    }
}
