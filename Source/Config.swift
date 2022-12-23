// Copyright (c) 2019, OpenEmu Team
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

public class ShaderConfigSerialization {
    public enum Errors: LocalizedError {
        case missingKey(String)
        case zeroShaders
        
        public var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return String(format: NSLocalizedString("missing key '%@'", comment: "shader is missing expected key"), key)
            case .zeroShaders:
                return NSLocalizedString("shader count must be > 0", comment: "")
            }
        }
    }
    
    public class func makeShaderModel(from s: String) throws -> ShaderModel {
        var scanner = ConfigScanner(s)
        
        var d: [String: String] = [:]
        scanning:
            while true
        {
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
        
        pass.wrapMode = d["wrap_mode\(i)"]
        
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
    
    private static func makeTextures(from d: [String: String]) -> [ShaderTextureModel]? {
        guard let tv = d["textures"] else {
            return nil
        }
        
        var res = [ShaderTextureModel]()
        for t in tv.split(separator: ";") {
            let name = String(t)
            guard let path = d[name] else { continue }
            
            let wrapMode = d["\(name)_wrap_mode"]
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
            
            res.append(.init(name: name,
                             path: path,
                             wrapMode: wrapMode,
                             linear: linear,
                             mipmapInput: mipmapInput))
        }
        
        return res.isEmpty ? nil : res
    }
    
    private static func makeParameters(from d: [String: String]) -> [ShaderParameterModel]? {
        guard let pv = d["parameters"] else {
            return nil
        }
        
        var res = [ShaderParameterModel]()
        for t in pv.split(separator: ";") {
            let name = String(t)
            if let v = d[name], let dv = Decimal(string: v) {
                res.append(ShaderParameterModel(name: name, value: dv))
            }
        }
        
        return res.isEmpty ? nil : res
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

enum ConfigKeyValue {
    case keyval(key: String, val: String)
    case eof
}

struct ConfigScanner {
    private let lines: [String]
    private var line: Int
    private var pos: String.Index
    
    init(_ text: String) {
        var lines = [String]()
        text.enumerateLines { line, _ in lines.append(line) }
        self.lines = lines
        line = 0
        pos = text.startIndex
    }
    
    private var text: String {
        lines[line]
    }
    
    mutating func reset() {
        line = 0
        pos = line < lines.count ? text.startIndex : "".startIndex
    }
    
    mutating func scan() -> ConfigKeyValue {
        while line < lines.count {
            if text.isEmpty {
                line += 1
                continue
            }
            
            pos = text.unicodeScalars.startIndex
            
            if !skipWhitespace() {
                // empty line or only a comment
                line += 1
                continue
            }
            
            guard let key = scanKey(), let val = scanValue() else {
                return .eof
            }
            
            line += 1
            
            return .keyval(key: key, val: val)
        }
        
        return .eof
    }
    
    private mutating func skipWhitespace() -> Bool {
        // skip whitespace
        let scalars = text.unicodeScalars
        if let next = scalars[pos...].firstIndex(where: { !CharacterSet.whitespaces.contains($0) }) {
            pos = next
        }
        
        if pos == scalars.endIndex {
            return false
        }
        
        // comment ignores the rest of the line
        if scalars[pos] == "#" {
            return false
        }
        
        if scalars[pos] == "/" {
            let peek = scalars.index(after: pos)
            if peek != scalars.endIndex, scalars[pos] == "/" {
                // comments can also be //
                return false
            }
        }
        
        return true
    }
    
    private mutating func scanKey() -> String? {
        if CharacterSet.letters.contains(text.unicodeScalars[pos]) {
            let scalars = text.unicodeScalars
            let startIndex = pos
            pos = scalars.index(after: pos)
            while pos < scalars.endIndex, CharacterSet.identifierCharacters.contains(scalars[pos]) {
                pos = scalars.index(after: pos)
            }
            
            return String(scalars[startIndex..<pos])
        }
        return nil
    }
    
    private mutating func scanValue() -> String? {
        if !skipWhitespace() {
            return nil
        }
        
        let scalars = text.unicodeScalars
        
        if scalars[pos] != "=" {
            return nil
        }
        
        pos = scalars.index(after: pos)
        
        if !skipWhitespace() {
            return nil
        }
        
        if CharacterSet.doubleQuotes.contains(scalars[pos]) {
            pos = scalars.index(after: pos)
            let startIndex = pos
            while pos < scalars.endIndex, !CharacterSet.doubleQuotes.contains(scalars[pos]) {
                pos = scalars.index(after: pos)
            }
            let v = String(scalars[startIndex..<pos])
            if pos < scalars.endIndex {
                pos = scalars.index(after: pos)
            } else {
                // Missing closing double quote
                pos = scalars.endIndex
            }
            return v
        }
        
        let startIndex = pos
        while pos < scalars.endIndex, !CharacterSet.whitespacesAndComment.contains(scalars[pos]) {
            pos = scalars.index(after: pos)
        }
        
        return String(scalars[startIndex..<pos])
    }
}
