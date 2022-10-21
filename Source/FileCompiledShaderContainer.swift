//
//  FileCompiledShaderContainer.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 19/10/2022.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation

public enum FileCompiledShaderContainer {
    enum Error: Swift.Error {
        /// The specified path does not exist.
        case pathNotExists
        
        /// The specified path is not a valid archive.
        case invalidArchive
        
        /// The specified path is missing shader.json.
        case missingCompiledShader
    }
    
    public final class Decoder: CompiledShaderContainer {
        public let shader: Compiled.Shader
        
        public init(shader: Compiled.Shader) {
            self.shader = shader
        }
        
        public func getLUTByName(_ name: String) throws -> Data {
            if let lut = shader.luts.first(where: { $0.name == name }) {
                return try Data(contentsOf: lut.url)
            } else {
                throw CompiledShaderContainerError.invalidLUTName
            }
        }
    }
}
