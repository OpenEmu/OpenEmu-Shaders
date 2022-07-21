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

extension ShaderConfigSerialization {
    public class func makeShaderModel(from s: String) throws -> ShaderModel {
        var scanner = ConfigScanner(s)
        
        var d: [String: String] = [:]
        scanning: while true {
            switch scanner.scan() {
            case .keyval(let key, let val):
                d[key] = val
            case .eof:
                break scanning
            }
        }
        
        guard let v = d["shaders"], let shaders = Int(v) else {
            throw Errors.missingKey("shaders")
        }
        
        if shaders < 0 {
            throw Errors.zeroShaders
        }
        
        let passes = try (0..<shaders).map { try makeShaderPassModel(pass: $0, from: d) }
        let textures = makeTextures(from: d)
        let parameters = makeParameters(from: d)
        
        return ShaderModel(passes: passes, textures: textures, parameters: parameters)
    }
    
    private static func makeShaderPassModel(pass i: Int, from d: [String: String]) throws -> ShaderPassModel {
        let key = "shader\(i)"
        guard let shader = d[key] else {
            throw Errors.missingKey(key)
        }
        
        let pass = ShaderPassModel(pass: i, shader: shader)
        
        pass.wrapMode = ShaderPassWrap(string: d["wrap_mode\(i)"])
        
        for (from, to) in strings {
            if let v = d["\(from)\(i)"] {
                pass[keyPath: to] = v
            }
        }
        for (from, to) in bools {
            if let v = d["\(from)\(i)"], let bv = Bool(v) {
                pass[keyPath: to] = bv
            }
        }
        for (from, to) in uints {
            if let v = d["\(from)\(i)"], let iv = UInt(v) {
                pass[keyPath: to] = iv
            }
        }
        for (from, to) in doubles {
            if let v = d["\(from)\(i)"], let dv = Double(v) {
                pass[keyPath: to] = dv
            }
        }
        
        return pass
    }
    
    private static func makeTextures(from d: [String: String]) -> [ShaderTextureModel] {
        guard let tv = d["textures"] else {
            return []
        }
        
        var res = [ShaderTextureModel]()
        for t in tv.split(separator: ";") {
            let name = String(t)
            guard let path = d[name] else { continue }
            
            let wrapMode = ShaderPassWrap(string: d["\(name)_wrap_mode"])
            let linear: Bool?
            if let v = d["\(name)_linear"], let bv = Bool(v) {
                linear = bv
            } else {
                linear = nil
            }
            let mipmapInput: Bool?
            if let v = d["\(name)_mipmap"], let bv = Bool(v) {
                mipmapInput = bv
            } else {
                mipmapInput = nil
            }
            
            res.append(
                ShaderTextureModel(
                    name: name, path: path, wrapMode: wrapMode, linear: linear,
                    mipmapInput: mipmapInput))
        }
        
        return res
    }
    
    private static func makeParameters(from d: [String: String]) -> [ShaderParameterModel] {
        guard let pv = d["parameters"] else {
            return []
        }
        
        var res = [ShaderParameterModel]()
        for t in pv.split(separator: ";") {
            let name = String(t)
            if let v = d[name], let dv = Decimal(string: v) {
                res.append(ShaderParameterModel(name: name, value: dv))
            }
        }
        
        return res
    }
    
    static let strings = [
        ("alias", \ShaderPassModel.alias),
        ("scale_type", \ShaderPassModel.scaleType),
        ("scale_type_x", \ShaderPassModel.scaleTypeX),
        ("scale_type_y", \ShaderPassModel.scaleTypeY),
    ]
    
    static let bools = [
        ("filter_linear", \ShaderPassModel.filterLinear),
        ("srgb_framebuffer", \ShaderPassModel.srgbFramebuffer),
        ("float_framebuffer", \ShaderPassModel.floatFramebuffer),
        ("mipmap_input", \ShaderPassModel.mipmapInput),
    ]
    
    static let uints = [
        ("frame_count_mod", \ShaderPassModel.frameCountMod),
    ]
    
    static let doubles = [
        ("scale", \ShaderPassModel.scale),
        ("scale_x", \ShaderPassModel.scaleX),
        ("scale_y", \ShaderPassModel.scaleY),
    ]
}

public class ShaderModel {
    public var passes: [ShaderPassModel]
    public var textures: [ShaderTextureModel]
    public var parameters: [ShaderParameterModel]
    
    init(
        passes: [ShaderPassModel], textures: [ShaderTextureModel],
        parameters: [ShaderParameterModel]
    ) {
        self.passes = passes
        self.textures = textures
        self.parameters = parameters
    }
}

public class ShaderPassModel {
    public var pass: Int
    public var shader: String
    public var wrapMode: ShaderPassWrap?
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
}

public class ShaderTextureModel {
    var name: String
    var path: String
    var wrapMode: ShaderPassWrap?
    var linear: Bool?
    var mipmapInput: Bool?
    
    init(name: String, path: String, wrapMode: ShaderPassWrap?, linear: Bool?, mipmapInput: Bool?) {
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
