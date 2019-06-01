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

@objc
public class ShaderConfigSerialization: NSObject {
    public enum Errors: LocalizedError {
        case invalidPathExtension(String)
        case missingKey(String)
        case zeroShaders
        
        public var errorDescription: String? {
            switch self {
            case .invalidPathExtension(let ext):
                return String(format: NSLocalizedString("unsupported path extension '%@'", comment: "unexpected path extension"), ext)
            case .missingKey(let key):
                return String(format: NSLocalizedString("missing key '%@'", comment: "shader is missing expected key"), key)
            case .zeroShaders:
                return NSLocalizedString("shader count must be > 0", comment: "")
            }
        }
    }
    
    @objc
    public class func config(fromURL url: URL) throws -> [String: AnyObject] {
        if url.pathExtension == "plist" {
            let data = try Data(contentsOf: url)
            var fmt  = PropertyListSerialization.PropertyListFormat.xml
            return try PropertyListSerialization.propertyList(from: data, format: &fmt) as! [String: AnyObject]
        }
        
        if url.pathExtension == "slangp" {
            return try self.parseConfig(try String(contentsOf: url))
        }
        
        throw Errors.invalidPathExtension(url.pathExtension)
    }
    
    class func parseConfig(_ from: String) throws -> [String: AnyObject] {
        var scanner = ConfigScanner(from)
        
        var d: [String: String] = [:]
        scanning: while true {
            switch scanner.scan() {
            case .keyval(let (key, val)):
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
        
        var res    = Dictionary<String, AnyObject>()
        var passes = [[String: AnyObject]]()
        for i in 0..<shaders {
            passes.append(try Pass.parse(pass: i, d: d))
        }
        
        res["passes"] = passes as AnyObject
        
        if let textures = Textures.parse(d: d) {
            res["textures"] = textures as AnyObject
        }
        
        if let parameters = Parameters.parse(d: d) {
            res["parameters"] = parameters as AnyObject
        }
        
        return res
    }
    
    struct Textures {
        static func parse(d: [String: String]) -> [String: AnyObject]? {
            guard let tv = d["textures"] else {
                return nil
            }
            
            let textures = tv.split(separator: ";")
            if textures.count == 0 {
                return nil
            }
            
            var res = [String: AnyObject]()
            
            for t in textures {
                let name    = String(t)
                var texture = [String: AnyObject]()
                
                if let path = d[name] {
                    texture["path"] = path as AnyObject
                } else {
                    // skip if no <name> = <path> key
                    continue
                }
                
                if let v = d["\(name)_wrap_mode"] {
                    texture["wrapMode"] = v as AnyObject
                }
                if let v = d["\(name)_linear"], let bv = Bool(v) {
                    texture["linear"] = bv as AnyObject
                }
                if let v = d["\(name)_mipmap"], let bv = Bool(v) {
                    texture["mipmapInput"] = bv as AnyObject
                }
                
                res[name] = texture as AnyObject
            }
            
            return res
        }
    }
    
    struct Parameters {
        static func parse(d: [String: String]) -> [String: AnyObject]? {
            guard let pv = d["parameters"] else {
                return nil
            }
            
            let parameters = pv.split(separator: ";")
            if parameters.count == 0 {
                return nil
            }
            
            var res = [String: AnyObject]()
            
            for t in parameters {
                let name = String(t)
                if let v = d[name], let dv = Double(v) {
                    res[name] = dv as AnyObject
                }
            }
            
            return res
        }
    }
    
    struct Pass {
        static func parse(pass i: Int, d: [String: String]) throws -> [String: AnyObject] {
            var pass = [String: AnyObject]()
            
            let key = "shader\(i)"
            guard let shader = d[key] else {
                throw Errors.missingKey(key)
            }
            pass["shader"] = shader as AnyObject
            
            for (from, to) in strings {
                if let v = d["\(from)\(i)"] {
                    pass[to] = v as AnyObject
                }
            }
            for (from, to) in bools {
                if let v = d["\(from)\(i)"], let bv = Bool(v) {
                    pass[to] = bv as AnyObject
                }
            }
            for (from, to) in ints {
                if let v = d["\(from)\(i)"], let iv = Int(v) {
                    pass[to] = iv as AnyObject
                }
            }
            for (from, to) in doubles {
                if let v = d["\(from)\(i)"], let dv = Double(v) {
                    pass[to] = dv as AnyObject
                }
            }
            
            return pass
        }
        
        static let strings = [
            ("wrap_mode", "wrapMode"),
            ("alias", "alias"),
            ("scale_type", "scaleType"),
            ("scale_type_x", "scaleTypeX"),
            ("scale_type_y", "scaleTypeY"),
        ]
        
        static let bools = [
            ("filter_linear", "filterLinear"),
            ("srgb_framebuffer", "srgbFramebuffer"),
            ("float_framebuffer", "floatFramebuffer"),
            ("mipmap_input", "mipmapInput"),
        ]
        
        static let ints = [
            ("frame_count_mod", "frameCountMod"),
        ]
        
        static let doubles = [
            ("scale", "scale"),
            ("scale_x", "scaleX"),
            ("scale_y", "scaleY"),
        ]
    }
}

enum ConfigKeyValue {
    case keyval(key: String, val: String)
    case eof
}

struct ConfigScanner {
    private let lines: [String]
    private var line:  Int
    private var pos:   String.Index
    
    init(_ text: String) {
        lines = text.split { $0.isNewline }.map(String.init)
        line = 0
        pos = text.startIndex
    }
    
    private var text: String {
        return lines[line]
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
            
            guard let key = self.scanKey(), let val = self.scanValue() else {
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
        
        return true
    }
    
    private mutating func scanKey() -> String? {
        if CharacterSet.letters.contains(text.unicodeScalars[pos]) {
            let scalars    = text.unicodeScalars
            let startIndex = pos
            pos = scalars.index(after: pos)
            while pos < scalars.endIndex && CharacterSet.identifierCharacters.contains(scalars[pos]) {
                pos = scalars.index(after: pos)
            }
            
            return String(scalars[startIndex..<pos])
        }
        return nil
    }
    
    private mutating func scanValue() -> String? {
        if !self.skipWhitespace() {
            return nil
        }
        
        let scalars = text.unicodeScalars
        
        if scalars[pos] != "=" {
            return nil
        }
        
        pos = scalars.index(after: pos)
        
        if !self.skipWhitespace() {
            return nil
        }
        
        if CharacterSet.doubleQuotes.contains(scalars[pos]) {
            pos = scalars.index(after: pos)
            let startIndex = pos
            while pos < scalars.endIndex && !CharacterSet.doubleQuotes.contains(scalars[pos]) {
                pos = scalars.index(after: pos)
            }
            let v = String(scalars[startIndex..<pos])
            pos = scalars.index(after: pos)
            return v
        }
        
        let startIndex = pos
        while pos < scalars.endIndex && !CharacterSet.whitespacesAndComment.contains(scalars[pos]) {
            pos = scalars.index(after: pos)
        }
        
        return String(scalars[startIndex..<pos])
    }
}
