//
//  CompiledShader.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/20.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation
import Metal

public enum Compiled {
    /// Shader is the root object of a compiled shader.
    public struct Shader: Codable {
        public let passes: [ShaderPass]
        public let parameters: [Parameter]
        public let luts: [LUT]
        public let historyCount: Int
    }
    
    public struct LUT: Codable {
        public let url: URL
        public let name: String
        public let filter: ShaderPassFilter
        public let wrapMode: ShaderPassWrap
        public let isMipmap: Bool
    }
    
    public struct Parameter: Codable {
        public let index: Int
        public let name: String
        public let desc: String
        public let initial: Float
        public let minimum: Float
        public let maximum: Float
        public let step: Float
        
        init(index: Int, source p: ShaderParameter) {
            self.index   = index
            self.name    = p.name
            self.desc    = p.desc
            self.initial = p.initial
            self.minimum = p.minimum
            self.maximum = p.maximum
            self.step    = p.step
        }
    }
    
    public struct ShaderPass: Codable {
        public let index: Int
        public let vertexSource: String
        public let fragmentSource: String
        public let frameCountMod: UInt
        public let scaleX: ShaderPassScale
        public let scaleY: ShaderPassScale
        public let filter: ShaderPassFilter
        public let wrapMode: ShaderPassWrap
        public let scale: CGSize
        public let size: CGSize
        public let isScaled: Bool
        public let format: PixelFormat
        public internal(set) var isFeedback: Bool
        public let buffers: [BufferDescriptor]
        public let textures: [TextureDescriptor]
        public let alias: String?
    }
    
    /// An object that describes how to organize and map data
    /// to a shader pass buffer.
    public struct BufferDescriptor: Codable {
        public let bindingVert: Int?
        public let bindingFrag: Int?
        public let size: Int
        public let uniforms: [BufferUniformDescriptor]
    }
    
    /// An object that describes how to store uniform data in memory
    /// and map it to the arguments of a shader pass.
    public struct BufferUniformDescriptor: Codable {
        // public let name: String
        public let semantic: ShaderBufferSemantic
        /// An optional index if the uniform is an array
        public let index: Int?
        public let name: String
        public let size: Int
        public let offset: Int
    }
    
    public struct TextureDescriptor: Codable {
        public let name: String
        public let semantic: ShaderTextureSemantic
        public let binding: Int
        public let wrap: ShaderPassWrap
        public let filter: ShaderPassFilter
        public let index: Int?
    }
    
    // MARK: - Enumerations
    
    enum LanguageVersionError: Error {
        case unsupportedVersion
    }
    
    public enum LanguageVersion: String, CaseIterable, Codable {
        // swiftlint:disable:next identifier_name
        case version2_4, version2_3, version2_2, version2_1
        
        init(_ mtl: MTLLanguageVersion) throws {
            switch mtl {
#if swift(>=5.5)
            case .version2_4:
                self = .version2_4
#endif
            case .version2_3:
                self = .version2_3
            case .version2_2:
                self = .version2_2
            case .version2_1:
                self = .version2_1
            default:
                throw LanguageVersionError.unsupportedVersion
            }
        }
    }
    
    public enum ShaderPassScale: String, CaseIterable, Codable {
        case invalid, source, absolute, viewport
        
        private static let mapFrom: [OpenEmuShaders.ShaderPassScale: Self] = [
            .invalid: .invalid,
            .source: .source,
            .absolute: .absolute,
            .viewport: .viewport,
        ]
        
        init(_ scale: OpenEmuShaders.ShaderPassScale) {
            self = Self.mapFrom[scale]!
        }
    }
    
    public enum ShaderPassFilter: String, CaseIterable, Codable {
        case unspecified, linear, nearest
        
        private static let mapFrom: [OpenEmuShaders.ShaderPassFilter: Self] = [
            .unspecified: .unspecified,
            .linear: .linear,
            .nearest: .nearest,
        ]
        
        init(_ filter: OpenEmuShaders.ShaderPassFilter) {
            self = Self.mapFrom[filter]!
        }
    }
    
    public enum ShaderPassWrap: String, CaseIterable, Codable {
        case border, edge, `repeat`, mirroredRepeat
        
        private static let mapFrom: [OpenEmuShaders.ShaderPassWrap: Self] = [
            .border: .border,
            .edge: .edge,
            .repeat: .repeat,
            .mirroredRepeat: .mirroredRepeat,
        ]
        
        init(_ wrap: OpenEmuShaders.ShaderPassWrap) {
            self = Self.mapFrom[wrap]!
        }
    }
    
    public enum ShaderTextureSemantic: String, Codable {
        /// Identifies the input texture to the filter chain.
        ///
        /// Shaders refer to the input texture via the `Original` and `OriginalSize` symbols.
        case original
        
        /// Identifies the output texture from the previous pass.
        ///
        /// Shaders can refer to the previous source texture via
        /// the `Source` and `SourceSize` symbols.
        ///
        /// - Note: If the filter chain is executing the first pass, this is the same as
        /// `Original`.
        case source
        
        /// Identifies the historical input textures.
        ///
        /// Shaders can refer to the history textures via the
        /// `OriginalHistoryN` and `OriginalSizeN` symbols, where `N`
        /// specifies the number of `Original` frames back to read.
        ///
        /// - Note: To read 2 frames prior, use `OriginalHistory2` and `OriginalSize2`.
        case originalHistory
        
        /// Identifies the pass output textures.
        ///
        /// Shaders can refer to the output of prior passes via the
        /// `PassOutputN` and `PassOutputSizeN` symbols, where `N` specifies the
        /// pass number.
        ///
        /// - NOTE: In pass 5, sampling the output of pass 2
        /// would use `PassOutput2` and `PassOutputSize2`.
        case passOutput
        
        /// Identifies the pass feedback textures.
        ///
        /// Shaders can refer to the output of the previous
        /// frame of pass `N` via the `PassFeedbackN` and `PassFeedbackSizeN`
        /// symbols, where `N` specifies the pass number.
        ///
        /// - NOTE: To sample the output of pass 2 from the prior frame,
        /// use `PassFeedback2` and `PassFeedbackSize2`.
        case passFeedback
        
        /// Identifies the lookup or user textures.
        ///
        /// Shaders refer to user lookup or user textures by name as defined
        /// in the `.slangp` file.
        case user
        
        static let mapFrom: [OpenEmuShaders.ShaderTextureSemantic: Self] = [
            .original: .original,
            .source: .source,
            .originalHistory: .originalHistory,
            .passOutput: .passOutput,
            .passFeedback: .passFeedback,
            .user: .user,
        ]
        
        init(_ sem: OpenEmuShaders.ShaderTextureSemantic) {
            self = Self.mapFrom[sem]!
        }
    }
    
    public enum ShaderBufferSemantic: String, Codable {
        /// Identifies the 4x4 float model-view-projection matrix buffer.
        ///
        /// Shaders refer to the matrix constant via the `MVP` symbol.
        ///
        case mvp
        
        /// Identifies the vec4 float containing the viewport size of the current pass.
        ///
        /// Shaders refer to the viewport size constant via the `OutputSize` symbol.
        ///
        /// - NOTE: The `x` and `y` fields refer to the size of the output in pixels.
        /// The `z` and `w` fields refer to the inverse; `1/x` and `1/y`.
        case outputSize
        
        /// Identifies the vec4 float containing the final viewport output size.
        ///
        /// Shaders refer to the final output size constant via the `FinalViewportSize` symbol.
        ///
        /// - NOTE: The `x` and `y` fields refer to the size of the output in pixels.
        /// The `z` and `w` fields refer to the inverse; `1/x` and `1/y`.
        case finalViewportSize
        
        /// Identifies the uint containing the frame count.
        ///
        /// Shaders refer to the frame count constant via the `FrameCount` symbol.
        ///
        /// - NOTE: This value increments by one each frame.
        case frameCount
        
        /// Identifies the int containing the frame direction; 1 is forward, -1 is backwards.
        ///
        /// Shaders refer to the frame direction constant via the `FrameDirection` symbol.
        case frameDirection
        
        /// Identifies a float parameter buffer.
        ///
        /// Shaders refer to float parameters by name.
        case floatParameter
        
        /// Identifies the input texture size to the filter chain.
        ///
        /// Shaders refer to the input texture size via the `OriginalSize` symbol.
        case originalSize
        
        /// Identifies the output texture size from the previous pass.
        ///
        /// Shaders can refer to the previous source texture size via
        /// the `SourceSize` symbol.
        ///
        /// - Note: If the filter chain is executing the first pass, this is the same as
        /// `OriginalSize`.
        case sourceSize
        
        /// Identifies the historical input texture sizes.
        ///
        /// Shaders can refer to the history texture sizes via the
        /// `OriginalSizeN` symbols, where `N`
        /// specifies the number of frames back to read.
        ///
        /// - Note: To read 2 frames prior, use `OriginalHistorySize2`.
        case originalHistorySize
        
        /// Identifies the pass output texture sizes.
        ///
        /// Shaders can refer to the output texture sizes of prior passes via the
        /// `PassOutputSizeN` symbols, where `N` specifies the
        /// pass number.
        ///
        /// - NOTE: In pass 5, sampling the output of pass 2
        /// would use `PassOutputSize2`.
        case passOutputSize
        
        /// Identifies the pass feedback texture sizes.
        ///
        /// Shaders can refer to the output of the previous
        /// frame of pass `N` via the `PassFeedbackSizeN`
        /// symbols, where `N` specifies the pass number.
        ///
        /// - NOTE: To sample the output of pass 2 from the prior frame,
        /// use `PassFeedbackSize2`.
        case passFeedbackSize
        
        /// Identifies the lookup or user texture sizes.
        ///
        /// Shaders refer to user lookup or user textures by name as defined
        /// in the `.slangp` file.
        case userSize
        
        private static let shaderBufferSemanticMap: [OpenEmuShaders.ShaderBufferSemantic: Self] = [
            .mvp: .mvp,
            .outputSize: .outputSize,
            .finalViewportSize: .finalViewportSize,
            .frameCount: .frameCount,
            .frameDirection: .frameDirection,
            .floatParameter: .floatParameter,
        ]
        
        private static let shaderTextureSemanticMap: [OpenEmuShaders.ShaderTextureSemantic: Self] = [
            .original: .originalSize,
            .source: .sourceSize,
            .originalHistory: .originalHistorySize,
            .passOutput: .passOutputSize,
            .passFeedback: .passFeedbackSize,
            .user: .userSize,
        ]
        
        init(_ sem: OpenEmuShaders.ShaderBufferSemantic) {
            self = Self.shaderBufferSemanticMap[sem]!
        }
        
        init(_ sem: OpenEmuShaders.ShaderTextureSemantic) {
            self = Self.shaderTextureSemanticMap[sem]!
        }
    }
    
    enum PixelFormatError: Error {
        case invalidFormat(val: MTLPixelFormat)
    }
    
    public enum PixelFormat: String, Codable {
        case r8Unorm
        case r8Uint
        case r8Sint
        case rg8Unorm
        case rg8Uint
        case rg8Sint
        case rgba8Unorm
        case rgba8Uint
        case rgba8Sint
        case rgba8Unorm_srgb    // swiftlint:disable:this identifier_name
        case rgb10a2Unorm
        case rgb10a2Uint
        case r16Uint
        case r16Sint
        case r16Float
        case rg16Uint
        case rg16Sint
        case rg16Float
        case rgba16Uint
        case rgba16Sint
        case rgba16Float
        case r32Uint
        case r32Sint
        case r32Float
        case rg32Uint
        case rg32Sint
        case rg32Float
        case rgba32Uint
        case rgba32Sint
        case rgba32Float
        case bgra8Unorm_srgb    // swiftlint:disable:this identifier_name
        case bgra8Unorm
        
        private static let mapFrom: [MTLPixelFormat: Self] = [
            .r8Unorm: .r8Unorm,
            .r8Uint: .r8Uint,
            .r8Sint: .r8Sint,
            .rg8Unorm: .rg8Unorm,
            .rg8Uint: .rg8Uint,
            .rg8Sint: .rg8Sint,
            .rgba8Unorm: .rgba8Unorm,
            .rgba8Uint: .rgba8Uint,
            .rgba8Sint: .rgba8Sint,
            .rgba8Unorm_srgb: .rgba8Unorm_srgb,
            .rgb10a2Unorm: .rgb10a2Unorm,
            .rgb10a2Uint: .rgb10a2Uint,
            .r16Uint: .r16Uint,
            .r16Sint: .r16Sint,
            .r16Float: .r16Float,
            .rg16Uint: .rg16Uint,
            .rg16Sint: .rg16Sint,
            .rg16Float: .rg16Float,
            .rgba16Uint: .rgba16Uint,
            .rgba16Sint: .rgba16Sint,
            .rgba16Float: .rgba16Float,
            .r32Uint: .r32Uint,
            .r32Sint: .r32Sint,
            .r32Float: .r32Float,
            .rg32Uint: .rg32Uint,
            .rg32Sint: .rg32Sint,
            .rg32Float: .rg32Float,
            .rgba32Uint: .rgba32Uint,
            .rgba32Sint: .rgba32Sint,
            .rgba32Float: .rgba32Float,
            .bgra8Unorm_srgb: .bgra8Unorm_srgb,
            .bgra8Unorm: .bgra8Unorm,
        ]
        
        init(_ pf: MTLPixelFormat) throws {
            guard let v = Self.mapFrom[pf]
            else { throw PixelFormatError.invalidFormat(val: pf) }
            self = v
        }
        
        var metalPixelFormat: MTLPixelFormat {
            switch self {
            case .r8Unorm:
                return .r8Unorm
            case .r8Uint:
                return .r8Uint
            case .r8Sint:
                return .r8Sint
            case .rg8Unorm:
                return .rg8Unorm
            case .rg8Uint:
                return .rg8Uint
            case .rg8Sint:
                return .rg8Sint
            case .rgba8Unorm:
                return .rgba8Unorm
            case .rgba8Uint:
                return .rgba8Uint
            case .rgba8Sint:
                return .rgba8Sint
            case .rgba8Unorm_srgb:
                return .rgba8Unorm_srgb
            case .rgb10a2Unorm:
                return .rgb10a2Unorm
            case .rgb10a2Uint:
                return .rgb10a2Uint
            case .r16Uint:
                return .r16Uint
            case .r16Sint:
                return .r16Sint
            case .r16Float:
                return .r16Float
            case .rg16Uint:
                return .rg16Uint
            case .rg16Sint:
                return .rg16Sint
            case .rg16Float:
                return .rg16Float
            case .rgba16Uint:
                return .rgba16Uint
            case .rgba16Sint:
                return .rgba16Sint
            case .rgba16Float:
                return .rgba16Float
            case .r32Uint:
                return .r32Uint
            case .r32Sint:
                return .r32Sint
            case .r32Float:
                return .r32Float
            case .rg32Uint:
                return .rg32Uint
            case .rg32Sint:
                return .rg32Sint
            case .rg32Float:
                return .rg32Float
            case .rgba32Uint:
                return .rgba32Uint
            case .rgba32Sint:
                return .rgba32Sint
            case .rgba32Float:
                return .rgba32Float
            case .bgra8Unorm_srgb:
                return .bgra8Unorm_srgb
            case .bgra8Unorm:
                return .bgra8Unorm
            }
        }
    }
}

extension ShaderTextureSemantic {
    private static let fromShaderBufferSemantic: [Compiled.ShaderBufferSemantic: Self] = [
        .originalSize: .original,
        .sourceSize: .source,
        .originalHistorySize: .originalHistory,
        .passOutputSize: .passOutput,
        .passFeedbackSize: .passFeedback,
    ]
    
    init?(_ sem: Compiled.ShaderBufferSemantic) {
        if let v = Self.fromShaderBufferSemantic[sem] {
            self = v
        } else {
            return nil
        }
    }
    
    private static let fromShaderTextureSemantic: [Compiled.ShaderTextureSemantic: Self] = [
        .original: .original,
        .source: .source,
        .originalHistory: .originalHistory,
        .passOutput: .passOutput,
        .passFeedback: .passFeedback,
        .user: .user,
    ]
    
    init?(_ sem: Compiled.ShaderTextureSemantic) {
        if let v = Self.fromShaderTextureSemantic[sem] {
            self = v
        } else {
            return nil
        }
    }
}

extension ShaderBufferSemantic {
    private static let fromShaderBufferSemantic: [Compiled.ShaderBufferSemantic: Self] = [
        .mvp: .mvp,
        .outputSize: .outputSize,
        .finalViewportSize: .finalViewportSize,
        .frameCount: .frameCount,
        .frameDirection: .frameDirection,
        .floatParameter: .floatParameter,
    ]
    
    init?(_ sem: Compiled.ShaderBufferSemantic) {
        if let v = Self.fromShaderBufferSemantic[sem] {
            self = v
        } else {
            return nil
        }
    }
}

extension ShaderPassFilter {
    private static let fromCompiled: [Compiled.ShaderPassFilter: Self] = [
        .unspecified: .unspecified,
        .linear: .linear,
        .nearest: .nearest,
    ]
    
    init(_ sem: Compiled.ShaderPassFilter) {
        self = Self.fromCompiled[sem]!
    }
}

extension ShaderPassWrap {
    private static let fromCompiled: [Compiled.ShaderPassWrap: Self] = [
        .border: .border,
        .edge: .edge,
        .repeat: .repeat,
        .mirroredRepeat: .mirroredRepeat,
    ]
    
    init(_ sem: Compiled.ShaderPassWrap) {
        self = Self.fromCompiled[sem]!
    }
}
