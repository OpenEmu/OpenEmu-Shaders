// Copyright (c) 2022, OpenEmu Team
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

enum ShaderTextureSemantic: Int, RawRepresentable, CaseIterable, CustomStringConvertible {
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
    
    var description: String {
        switch self {
        case .original:
            return "Original"
        case .source:
            return "Source"
        case .originalHistory:
            return "OriginalHistory"
        case .passOutput:
            return "PassOutput"
        case .passFeedback:
            return "PassFeedback"
        case .user:
            return "User"
        }
    }
}

enum ShaderBufferSemantic: Int, CaseIterable, CustomStringConvertible {
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
    
    var description: String {
        switch self {
        case .mvp:
            return "MVP"
        case .outputSize:
            return "OutputSize"
        case .finalViewportSize:
            return "FinalViewportSize"
        case .frameCount:
            return "FrameCount"
        case .frameDirection:
            return "FrameDirection"
        case .floatParameter:
            return "FloatParameter"
        }
    }
}

enum Constants {
    static let maxShaderPasses = 26
    static let maxTextures = 8
    static let maxParameters = 256
    static let maxFrameHistory = 128
    static let maxConstantBuffers = 2
    static let maxShaderBindings = 16
}
