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

@objc public class ShaderPassUniformBinding: NSObject {
    @objc public var data: UnsafeRawPointer
    @objc public var size: Int
    @objc public var offset: Int
    @objc public var name: String
    
    init(data: UnsafeRawPointer, size: Int, offset: Int, name: String) {
        self.data = data
        self.size = size
        self.offset = offset
        self.name = name
    }
}

@objc public class ShaderPassBufferBinding: NSObject {
    @objc public var stageUsage: OEStageUsage = []
    @objc public var bindingVert: UInt = 0
    @objc public var bindingFrag: UInt = 0
    @objc public var size: Int = 0
    @objc public var uniforms: [ShaderPassUniformBinding] = []
    
    @discardableResult
    func addUniformData(_ data: UnsafeRawPointer, size: Int, offset: Int, name: String) -> ShaderPassUniformBinding {
        let u = ShaderPassUniformBinding(data: data, size: size, offset: offset, name: name)
        uniforms.append(u)
        return u
    }
}

@objc public class ShaderPassTextureBinding: NSObject {
    @objc public var texture: UnsafeRawPointer
    @objc public var wrap: OEShaderPassWrap = .default
    @objc public var filter: OEShaderPassFilter = .nearest
    @objc public var stageUsage: OEStageUsage = []
    @objc public var binding: UInt = 0
    @objc public var name: String = ""
    
    init(texture: UnsafeRawPointer) {
        self.texture = texture
    }
}

@objc public class ShaderPassBindings: NSObject {
    @objc public let index: Int
    @objc public var format: MTLPixelFormat = .bgra8Unorm
    @objc public var isFeedback: Bool = false
    @objc public private(set) var buffers = [ShaderPassBufferBinding(), ShaderPassBufferBinding()] // equivalent to kMaxConstantBuffers
    @objc public private(set) var textures: [ShaderPassTextureBinding] = []
    
    init(index: Int) {
        self.index = index
    }
    
    func addTexture(_ texture: UnsafeRawPointer) -> ShaderPassTextureBinding {
        let t = ShaderPassTextureBinding(texture: texture)
        textures.append(t)
        return t
    }
}
