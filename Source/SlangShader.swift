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
        case parameterConflict(String)
        
        public var errorDescription: String? {
            switch self {
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
        let sm = try ShaderConfigSerialization.makeShaderModel(from: try String(contentsOf: url))
        
        let base = url.deletingLastPathComponent()
        
        passes = try sm.passes.map { spec in
            try .init(from: URL(string: spec.shader, relativeTo: base)!, pass: spec)
        }
        
        if let textures = sm.textures {
            luts = textures.map { spec in
                .init(url: URL(string: spec.path, relativeTo: base)!,
                      spec: spec)
            }
        } else {
            luts = []
        }
        
        var parametersMap = [String: ShaderParameter]()
        // collect #pragma parameter declarations from passes
        parameters = try passes.lazy
            .flatMap(\.source.parameters)
            .filter {
                if let existing = parametersMap[$0.name] {
                    if existing != $0 {
                        throw Errors.parameterConflict($0.name)
                    }
                    // skip processing duplicates
                    return false
                }
                parametersMap[$0.name] = $0
                return true
            }
        
        self.parametersMap = parametersMap
        
        // resolve parameter overrides from config
        sm.parameters?
            .forEach {
                if let existing = parametersMap[$0.name] {
                    existing.initial = $0.value
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

    // swiftformat:disable consecutiveSpaces redundantSelf
    init(from url: URL, pass: ShaderPassModel) throws {
        self.url        = url
        self.index      = pass.pass
        filter          = .init(bool: pass.filterLinear)
        wrapMode        = .init(string: pass.wrapMode)
        frameCountMod   = pass.frameCountMod ?? 0
        issRGB          = pass.srgbFramebuffer ?? false
        isFloat         = pass.floatFramebuffer ?? false
        isMipmap        = pass.mipmapInput ?? false
        
        if Self.isValidScale(pass) {
            scaleX = Self.readScale(.x, pass) ?? .source(scale: 1)
            scaleY = Self.readScale(.y, pass) ?? .source(scale: 1)
        } else {
            scaleX = nil
            scaleY = nil
        }
        
        source = try SourceParser(fromURL: url)
        alias = pass.alias ?? source.name
    }
    
    // swiftformat:enable all
    
    // MARK: - Model helpers
    
    static func isValidScale(_ pass: ShaderPassModel) -> Bool {
        // Either the shader pass specifies a scale_type for both axes
        pass.scaleType != nil ||
            // or individual scale type for the X and Y axis
            (pass.scaleTypeX != nil && pass.scaleTypeY != nil)
    }
    
    static func readScale(_ axis: ShaderPassModel.ScaleAxis, _ d: ShaderPassModel) -> Compiled.ShaderPassScale? {
        guard let scaleType = d.scaleType ?? d.scaleType(for: axis) else {
            return nil
        }
        
        let val = d.scale ?? d.scale(for: axis)
        
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
    
    // swiftformat:disable consecutiveSpaces redundantSelf
    init(url: URL, spec: ShaderTextureModel) {
        self.url      = url
        self.name     = spec.name
        self.filter   = .init(bool: spec.linear)
        self.wrapMode = .init(string: spec.wrapMode)
        self.isMipmap = spec.mipmapInput ?? false
    }
    // swiftformat:enable all
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
