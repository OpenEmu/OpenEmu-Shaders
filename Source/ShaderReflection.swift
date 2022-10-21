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

@_implementationOnly import CSPIRVCross
import Foundation
@_implementationOnly import os.log

class ShaderTextureSemanticMeta {
    let index: Int
    let name: String
    var binding: Int?
    
    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

class ShaderBufferSemanticMeta {
    let index: Int
    let name: String
    var uboOffset: Int?
    var pushOffset: Int?
    var numberOfComponents: Int = 0
    
    convenience init(name: String) {
        self.init(index: 0, name: name)
    }
    
    convenience init(_ sem: Compiled.ShaderBufferSemantic) {
        self.init(index: 0, name: sem.description)
    }
    
    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

class ShaderTextureSemanticMap {
    let semantic: Compiled.ShaderTextureSemantic
    let index: Int
    let name: String
    
    init(textureSemantic semantic: Compiled.ShaderTextureSemantic, index: Int, name: String) {
        self.semantic = semantic
        self.index = index
        self.name = name
    }
}

class ShaderBufferSemanticMap {
    let semantic: Compiled.ShaderBufferSemantic
    let index: Int
    let name: String
    
    let baseType: SPVBaseType
    let vecSize: Int
    let cols: Int
    
    init(semantic: Compiled.ShaderBufferSemantic, index: Int, name: String, baseType: SPVBaseType, vecSize: Int, cols: Int) {
        self.semantic = semantic
        self.index = index
        self.name = name
        self.baseType = baseType
        self.vecSize = vecSize
        self.cols = cols
    }
    
    init(semantic: Compiled.ShaderBufferSemantic, baseType: SPVBaseType, vecSize: Int, cols: Int) {
        self.semantic = semantic
        index = 0
        name = semantic.description
        self.baseType = baseType
        self.vecSize = vecSize
        self.cols = cols
    }
    
    func validateType(_ type: __SPVType) -> Bool {
        type.num_array_dimensions == 0 &&
            type.basetype == baseType &&
            type.vector_size == vecSize &&
            type.columns == cols
    }
}

struct BufferBindingDescriptor {
    var size: Int = 0
    var bindingVert: Int?
    var bindingFrag: Int?
}
