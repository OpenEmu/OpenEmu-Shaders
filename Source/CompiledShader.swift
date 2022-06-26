//
//  CompiledShader.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/20.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation

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
        public let scale: CGSize
        public let size: CGSize
        public let isScaled: Bool
        public let format: PixelFormat
        public internal(set) var isFeedback: Bool
        public let buffers: [BufferDescriptor]
        public let textures: [TextureDescriptor]
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
    
    public enum ShaderPassScale: String, CaseIterable, Codable {
        case invalid, source, absolute, viewport
        
        static let mapFrom: [OpenEmuShaders.ShaderPassScale: Self] = [
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
        
        static let mapFrom: [OpenEmuShaders.ShaderPassFilter: Self] = [
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
        
        static let mapFrom: [OpenEmuShaders.ShaderPassWrap: Self] = [
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
            .frameDirection: .frameCount,
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
        // swiftlint: disable identifier_name
        case rgba8Unorm_srgb
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
        case bgra8Unorm_srgb
        case bgra8Unorm
        
        // swiftlint: disable cyclomatic_complexity
        init(_ pf: MTLPixelFormat) throws {
            switch pf {
            case .r8Unorm:
                self = .r8Unorm
            case .r8Uint:
                self = .r8Uint
            case .r8Sint:
                self = .r8Sint
            case .rg8Unorm:
                self = .rg8Unorm
            case .rg8Uint:
                self = .rg8Uint
            case .rg8Sint:
                self = .rg8Sint
            case .rgba8Unorm:
                self = .rgba8Unorm
            case .rgba8Uint:
                self = .rgba8Uint
            case .rgba8Sint:
                self = .rgba8Sint
            case .rgba8Unorm_srgb:
                self = .rgba8Unorm_srgb
            case .rgb10a2Unorm:
                self = .rgb10a2Unorm
            case .rgb10a2Uint:
                self = .rgb10a2Uint
            case .r16Uint:
                self = .r16Uint
            case .r16Sint:
                self = .r16Sint
            case .r16Float:
                self = .r16Float
            case .rg16Uint:
                self = .rg16Uint
            case .rg16Sint:
                self = .rg16Sint
            case .rg16Float:
                self = .rg16Float
            case .rgba16Uint:
                self = .rgba16Uint
            case .rgba16Sint:
                self = .rgba16Sint
            case .rgba16Float:
                self = .rgba16Float
            case .r32Uint:
                self = .r32Uint
            case .r32Sint:
                self = .r32Sint
            case .r32Float:
                self = .r32Float
            case .rg32Uint:
                self = .rg32Uint
            case .rg32Sint:
                self = .rg32Sint
            case .rg32Float:
                self = .rg32Float
            case .rgba32Uint:
                self = .rgba32Uint
            case .rgba32Sint:
                self = .rgba32Sint
            case .rgba32Float:
                self = .rgba32Float
            case .bgra8Unorm_srgb:
                self = .bgra8Unorm_srgb
            case .bgra8Unorm:
                self = .bgra8Unorm
            default:
                throw PixelFormatError.invalidFormat(val: pf)
            }
        }
    }
}
