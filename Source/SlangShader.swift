// Copyright (c) 2019, 2020 OpenEmu Team
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
import Metal

public final class SlangShader {
    public enum Errors: LocalizedError {
        case missingKey(String)
        case parameterConflict(String)
        
        public var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return String(format: NSLocalizedString("missing key '%@'", comment: "shader is missing expected key"), key)
            case .parameterConflict(let name):
                return String(format: NSLocalizedString("conflicting definition for parameter '%@'",
                                                        comment: ""),
                              name)
            }
        }
    }
    
    public let url: URL
    public let passes: [ShaderPass]
    public let parameters: [ShaderParameter]
    public let luts: [ShaderLUT]
    
    private let parametersMap: [String: ShaderParameter]
    
    public init(fromURL url: URL) throws {
        self.url = url
        
        let d = try ShaderConfigSerialization.config(fromURL: url)
        
        let base = url.deletingLastPathComponent()
        
        // process passes
        guard let specs = d["passes"] as? [[String: AnyObject]] else { throw Errors.missingKey("passes") }
        var passes = [ShaderPass]()
        passes.reserveCapacity(specs.count)
        for (i, spec) in specs.enumerated() {
            guard let path = spec["shader"] as? String else { throw Errors.missingKey("shader") }
            passes.append(try ShaderPass(from: URL(string: path, relativeTo: base)!, index: i, dictionary: spec))
        }
        self.passes = passes
        
        // process lookup textures
        if let textures = d["textures"] as? [String: [String: AnyObject]] {
            var luts = [ShaderLUT]()
            luts.reserveCapacity(textures.count)
            for (key, spec) in textures {
                guard let path = spec["path"] as? String else { throw Errors.missingKey("path") }
                luts.append(ShaderLUT(url: URL(string: path, relativeTo: base)!, name: key, dictionary: spec))
            }
            self.luts = luts
        } else {
            self.luts = []
        }
        
        // NOTE: using lazy.flatMap SIGABRTs the XPC process in DEBUG builds:
        // for param in passes.lazy.flatMap({ $0.source.parameters }) {
        
        // collect #pragma parameter declarations from passes
        var parameters    = [ShaderParameter]()
        var parametersMap = [String: ShaderParameter]()
        
        for pass in passes {
            for param in pass.source.parameters {
                if let existing = parametersMap[param.name] {
                    if existing != param {
                        throw Errors.parameterConflict(param.name)
                    }
                    // skip reprocessing duplicates
                    continue
                }
                parameters.append(param)
                parametersMap[param.name] = param
            }
        }
        
        self.parameters     = parameters
        self.parametersMap  = parametersMap
        
        // resolve parameter overrides from config
        if let params = d["parameters"] as? [String: NSNumber] {
            for (key, val) in params {
                if let existing = parametersMap[key] {
                    existing.initial = val.floatValue
                }
            }
        }
    }
}

public final class ShaderPass {
    public let url: URL
    public let index: Int
    public let frameCountMod: UInt
    public let scaleX: Compiled.ShaderPassScale?
    public let scaleY: Compiled.ShaderPassScale?
    public let filter: Compiled.ShaderPassFilter
    public let wrapMode: Compiled.ShaderPassWrap
    public let isFloat: Bool
    public let issRGB: Bool
    public let isMipmap: Bool
    public let alias: String?
    
    public var format: Compiled.PixelFormat {
        if let format = source.format {
            return format
        }
        if issRGB {
            return .bgra8Unorm_srgb
        }
        
        if isFloat {
            return .rgba16Float
        }
        
        return .bgra8Unorm
    }
    
    internal let source: SourceParser
    
    init(from url: URL, index: Int, dictionary d: [String: AnyObject]) throws {
        self.url        = url
        self.index      = index
        filter          = Compiled.ShaderPassFilter(bool: d["filterLinear"] as? Bool)
        wrapMode        = Compiled.ShaderPassWrap(string: d["wrapMode"] as? String)
        frameCountMod   = d["frameCountMod"] as? UInt ?? 0
        issRGB          = d["srgbFramebuffer"] as? Bool ?? false
        isFloat         = d["floatFramebuffer"] as? Bool ?? false
        isMipmap        = d["mipmapInput"] as? Bool ?? false
        
        if Self.isValidScale(d) {
            scaleX = Self.readScale("X", d) ?? .source(scale: 1)
            scaleY = Self.readScale("Y", d) ?? .source(scale: 1)
        } else {
            scaleX = nil
            scaleY = nil
        }
        
        let source  = try SourceParser(fromURL: url)
        alias       = d["alias"] as? String ?? source.name
        self.source = source
    }
    
    static func isValidScale(_ d: [String: AnyObject]) -> Bool {
        // Either the shader pass specifies a scale_type
        d["scaleType"] != nil ||
        // or both a scale type for the X and Y
        (d["scaleTypeX"] != nil && d["scaleTypeY"] != nil)
    }
    
    static func readScale(_ axis: String, _ d: [String: AnyObject]) -> Compiled.ShaderPassScale? {
        guard let scaleType = d["scaleType"] as? String ?? d["scaleType\(axis)"] as? String else {
            return nil
        }
        
        let val = d["scale"] as? Double ?? d["scale\(axis)"] as? Double
        
        switch scaleType {
        case "source":
            return .source(scale: val ?? 1)
        case "viewport":
            return .viewport(scale: val ?? 1)
        case "absolute":
            return .absolute(size: Int(val?.rounded() ?? 0))
        default:
            return nil
        }
    }
}

public final class ShaderLUT {
    public let url: URL
    public let name: String
    public let filter: Compiled.ShaderPassFilter
    public let wrapMode: Compiled.ShaderPassWrap
    public let isMipmap: Bool
    
    init(url: URL, name: String, dictionary d: [String: AnyObject]) {
        self.url      = url
        self.name     = name
        self.filter   = Compiled.ShaderPassFilter(bool: d["linear"] as? Bool)
        self.wrapMode = Compiled.ShaderPassWrap(string: d["wrapMode"] as? String)
        self.isMipmap = d["mipmapInput"] as? Bool ?? false
    }
}

extension Compiled.ShaderPassFilter {
    init(bool: Bool?) {
        switch bool {
        case true:
            self = .linear
        case false:
            self = .nearest
        default:
            self = .unspecified
        }
    }
}

extension Compiled.ShaderPassWrap {
    init(string: String?) {
        guard let v = string else {
            self = .border
            return
        }
        
        switch v {
        case "clamp_to_border":
            self = .border
        case "clamp_to_edge":
            self = .edge
        case "repeat":
            self = .repeat
        case "mirrored_repeat":
            self = .mirroredRepeat
        default:
            // user specified an invalid value
            self = .border
        }
    }
}
