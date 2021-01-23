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

@objc
@objcMembers
public final class SlangShader: NSObject {
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
    
    public var url: URL
    public var passes: [ShaderPass] = []
    public var parameters: [ShaderParameter] = []
    public var luts: [ShaderLUT] = []
    
    private var parametersMap: [String: ShaderParameter] = [:]
    
    public init(fromURL url: URL) throws {
        self.url = url
        
        let d = try ShaderConfigSerialization.config(fromURL: url)
        
        let base = url.deletingLastPathComponent()
        
        // process passes
        guard let specs = d["passes"] as? [[String: AnyObject]] else { throw Errors.missingKey("passes") }
        passes.reserveCapacity(specs.count)
        for (i, spec) in specs.enumerated() {
            guard let path = spec["shader"] as? String else { throw Errors.missingKey("shader") }
            passes.append(try ShaderPass(from: URL(string: path, relativeTo: base)!, index: i, dictionary: spec))
        }
        
        // process lookup textures
        if let textures = d["textures"] as? [String: [String: AnyObject]] {
            luts.reserveCapacity(textures.count)
            for (key, spec) in textures {
                guard let path = spec["path"] as? String else { throw Errors.missingKey("path") }
                luts.append(ShaderLUT(url: URL(string: path, relativeTo: base)!, name: key, dictionary: spec))
            }
        }
        
        // NOTE: using lazy.flatMap SIGABRTs the XPC process in DEBUG builds:
        // for param in passes.lazy.flatMap({ $0.source.parameters }) {
        
        // collect #pragma parameter declarations from passes
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
        
        // resolve parameter overrides from config
        if let params = d["parameters"] as? [String: NSNumber] {
            for (key, val) in params {
                if let existing = parametersMap[key] {
                    existing.initial = val.floatValue
                    existing.value   = val.floatValue
                }
            }
        }
    }
    
    @objc(setValue:forParameter:)
    public func set(value: Double, forParameter name: String) {
        if let param = parametersMap[name] {
            param.value = Float(value)
        }
    }
}

@objc
@objcMembers
public final class ShaderPass: NSObject {
    public var url: URL
    public var index: Int
    public var frameCountMod: UInt
    public var scaleX: OEShaderPassScale = .invalid
    public var scaleY: OEShaderPassScale = .invalid
    public var filter: OEShaderPassFilter
    public var wrapMode: OEShaderPassWrap
    public var scale: CGSize = CGSize(width: 1, height: 1)
    public var size: CGSize = CGSize(width: 0, height: 0)
    public var isScaled: Bool = false
    public var isFloat: Bool
    public var issRGB: Bool
    public var isMipmap: Bool
    public var alias: String?
    
    public var format: MTLPixelFormat {
        let format = source.format
        if format == .invalid {
            if issRGB {
                return .bgra8Unorm_srgb
            }
            
            if isFloat {
                return .rgba16Float
            }
            
            return .bgra8Unorm
        }
        return format
    }
    
    internal let source: SourceParser
    
    init(from url: URL, index: Int, dictionary d: [String: AnyObject]) throws {
        self.url        = url
        self.index      = index
        filter          = OEShaderPassFilter(bool: d["filterLinear"] as? Bool)
        wrapMode        = OEShaderPassWrap(string: d["wrapMode"] as? String)
        frameCountMod   = d["frameCountMod"] as? UInt ?? 0
        issRGB          = d["srgbFramebuffer"] as? Bool ?? false
        isFloat         = d["floatFramebuffer"] as? Bool ?? false
        isMipmap        = d["mipmapInput"] as? Bool ?? false
        
        if d["scaleType"] != nil || d["scaleTypeX"] != nil || d["scaleTypeY"] != nil {
            isScaled  = true
            scaleX    = .source
            scaleY    = .source
            
            if let scaleType = OEShaderPassScale(string: d["scaleType"] as? String) {
                scaleX = scaleType
                scaleY = scaleType
            } else {
                if let scaleType = OEShaderPassScale(string: d["scaleTypeX"] as? String) {
                    scaleX = scaleType
                }
                
                if let scaleType = OEShaderPassScale(string: d["scaleTypeY"] as? String) {
                    scaleY = scaleType
                }
            }
            
            if let val = d["scale"] as? Double ?? d["scaleX"] as? Double {
                if scaleX == .absolute {
                    size.width = CGFloat(val)
                } else {
                    scale.width = CGFloat(val)
                }
            }

            if let val = d["scale"] as? Double ?? d["scaleY"] as? Double {
                if scaleY == .absolute {
                    size.height = CGFloat(val)
                } else {
                    scale.height = CGFloat(val)
                }
            }
        }
        
        let source  = try SourceParser(fromURL: url)
        alias       = d["alias"] as? String ?? source.name
        self.source = source
    }
}

@objc
@objcMembers
public final class ShaderLUT: NSObject {
    public var url: URL
    public var name: String
    public var filter: OEShaderPassFilter
    public var wrapMode: OEShaderPassWrap
    public var isMipmap: Bool
    
    init(url: URL, name: String, dictionary d: [String: AnyObject]) {
        self.url      = url
        self.name     = name
        self.filter   = OEShaderPassFilter(bool: d["linear"] as? Bool)
        self.wrapMode = OEShaderPassWrap(string: d["wrapMode"] as? String)
        self.isMipmap = d["mipmapInput"] as? Bool ?? false
    }
}

extension OEShaderPassFilter {
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

extension OEShaderPassWrap {
    init(string: String?) {
        guard let v = string else {
            self = .default
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
            self = .default
        }
    }
}

extension OEShaderPassScale {
    init?(string: String?) {
        switch string {
        case "source":
            self = .source
        case "viewport":
            self = .viewport
        case "absolute":
            self = .absolute
        default:
            return nil
        }
    }
}
