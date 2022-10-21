// Copyright (c) 2020, OpenEmu Team
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

public class ShaderModel {
    public var passes: [ShaderPassModel]
    public var textures: [ShaderTextureModel]?
    public var parameters: [ShaderParameterModel]?
    
    init(passes: [ShaderPassModel],
         textures: [ShaderTextureModel]?,
         parameters: [ShaderParameterModel]?)
    {
        self.passes = passes
        self.textures = textures
        self.parameters = parameters
    }
}

public class ShaderPassModel {
    public enum ScaleAxis {
        case x, y
    }
    
    public var pass: Int
    public var shader: String
    public var wrapMode: String?
    public var alias: String?
    public var scaleType: String?
    public var scaleTypeX: String?
    public var scaleTypeY: String?
    
    public var filterLinear: Bool?
    public var srgbFramebuffer: Bool?
    public var floatFramebuffer: Bool?
    public var mipmapInput: Bool?
    
    public var frameCountMod: UInt?
    
    public var scale: Double?
    public var scaleX: Double?
    public var scaleY: Double?
    
    init(pass: Int, shader: String) {
        self.pass = pass
        self.shader = shader
    }
    
    public func scaleType(for a: ScaleAxis) -> String? {
        switch a {
        case .x: return scaleTypeX
        case .y: return scaleTypeY
        }
    }
    
    public func scale(for a: ScaleAxis) -> Double? {
        switch a {
        case .x: return scaleX
        case .y: return scaleY
        }
    }
}

public class ShaderTextureModel {
    let name: String
    let path: String
    let wrapMode: String?
    let linear: Bool?
    let mipmapInput: Bool?
    
    init(name: String, path: String, wrapMode: String?, linear: Bool?, mipmapInput: Bool?) {
        self.name = name
        self.path = path
        self.wrapMode = wrapMode
        self.linear = linear
        self.mipmapInput = mipmapInput
    }
}

public class ShaderParameterModel {
    let name: String
    let value: Decimal
    
    init(name: String, value: Decimal) {
        self.name = name
        self.value = value
    }
}
