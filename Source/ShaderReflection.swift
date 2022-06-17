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
import os.log

class ShaderTextureSemanticMeta {
    let index: Int
    var binding: Int?
    var uboOffset: Int?
    var pushOffset: Int?
    
    init(index: Int) {
        self.index = index
    }
}

class ShaderSemanticMeta {
    let index: Int
    var uboOffset: Int?
    var pushOffset: Int?
    var numberOfComponents: Int = 0
    
    convenience init() {
        self.init(index: 0)
    }
    
    init(index: Int) {
        self.index = index
    }
}

class ShaderTextureSemanticMap {
    var semantic: ShaderTextureSemantic
    var index: Int
    
    init(textureSemantic semantic: ShaderTextureSemantic, index: Int) {
        self.semantic = semantic
        self.index    = index
    }
}

class ShaderSemanticMap {
    var semantic: ShaderBufferSemantic
    var index: Int
    
    //
    
    init(semantic: ShaderBufferSemantic, index: Int) {
        self.semantic = semantic
        self.index    = index
    }
    
    init(semantic: ShaderBufferSemantic) {
        self.semantic = semantic
        self.index    = 0
    }
}

struct BufferBindingDescriptor {
    var size: Int = 0
    var bindingVert: Int?
    var bindingFrag: Int?
}

class ShaderReflection {
    var ubo: BufferBindingDescriptor?
    var push: BufferBindingDescriptor?
    
    private(set) var textures: [ShaderTextureSemantic: [Int: ShaderTextureSemanticMeta]] = [
        .original: [:],
        .source: [:],
        .originalHistory: [:],
        .passOutput: [:],
        .passFeedback: [:],
        .user: [:],
    ]
    
    private(set) var semantics: [ShaderBufferSemantic: ShaderSemanticMeta] = [
        .mvp: .init(),
        .outputSize: .init(),
        .finalViewportSize: .init(),
        .frameCount: .init(),
        .frameDirection: .init(),
    ]
    
    private(set) var floatParameters: [Int: ShaderSemanticMeta] = [:]
    private(set) var floatParameterSemanticMap: [String: ShaderSemanticMap] = [:]
    private(set) var textureSemanticMap: [String: ShaderTextureSemanticMap] = [:]
    private(set) var textureUniformSemanticMap: [String: ShaderTextureSemanticMap] = [:]
    
    func addTextureSemantic(_ semantic: ShaderTextureSemantic, atIndex i: Int, name: String) -> Bool {
        if textureSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: alias %{public}@ already exists for texture semantic %{public}@",
                   i, name, semantic.description as NSString)
            return false
        }
        
        textureSemanticMap[name] = ShaderTextureSemanticMap(textureSemantic: semantic, index: i)
        
        return true
    }
    
    func addTextureBufferSemantic(_ semantic: ShaderTextureSemantic, atIndex i: Int, name: String) -> Bool {
        if textureUniformSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: alias %{public}@ already exists for texture buffer semantic %{public}@",
                   i, name, semantic.description as NSString)
            return false
        }
        
        textureUniformSemanticMap[name] = ShaderTextureSemanticMap(textureSemantic: semantic, index: i)
        
        return true
    }
    
    func addFloatParameterSemantic(atIndex i: Int, name: String) -> Bool {
        if floatParameterSemanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: float parameter %{public}@ already exists",
                   i, name)
            return false
        }
        
        floatParameterSemanticMap[name] = ShaderSemanticMap(semantic: .floatParameter, index: i)
        
        return true
    }
    
    func name(forBufferSemantic semantic: ShaderBufferSemantic) -> String? {
        Self.semanticToUniformName[semantic]
    }
    
    func name(forFloatParameterAtIndex index: Int) -> String? {
        return floatParameterSemanticMap.first { (_, v) in
            v.index == index
        }?.key
    }

    func name(forTextureSemantic semantic: ShaderTextureSemantic, index: Int) -> String? {
        if let name = Self.textureSemanticToName[semantic] {
            return textureSemanticIsArray(semantic) ? "\(name)\(index)" : name
        }
        
        return textureSemanticMap.first { (_, v) in
            v.semantic == semantic && v.index == index
        }?.key
    }
    
    func sizeName(forTextureSemantic semantic: ShaderTextureSemantic, index: Int) -> String? {
        if let name = Self.textureSemanticToUniformName[semantic] {
            return textureSemanticIsArray(semantic) ? "\(name)\(index)" : name
        }
        
        return textureUniformSemanticMap.first { (_, v) in
            v.semantic == semantic && v.index == index
        }?.key
    }
    
    func bufferSemantic(forUniformName name: String) -> ShaderSemanticMap? {
        floatParameterSemanticMap[name] ?? Self.semanticUniformNames[name]
    }
    
    func textureSemanticIsArray(_ semantic: ShaderTextureSemantic) -> Bool {
        Self.textureSemanticArrays.contains(semantic)
    }
    
    func textureSemantic(forUniformName name: String) -> ShaderTextureSemanticMap? {
        textureUniformSemanticMap[name] ?? textureSemanticForUniformName(name, names: Self.textureSemanticUniformNames)
    }
    
    func textureSemantic(forName name: String) -> ShaderTextureSemanticMap? {
        textureSemanticMap[name] ?? textureSemanticForUniformName(name, names: Self.textureSemanticNames)
    }
    
    func setOffset(_ offset: Int, vecSize: Int, forFloatParameterAt index: Int, ubo: Bool) -> Bool {
        let sem: ShaderSemanticMeta
        if let tmp = floatParameters[index] {
            sem = tmp
        } else {
            sem = ShaderSemanticMeta(index: index)
            floatParameters[index] = sem
        }
        
        if sem.numberOfComponents != vecSize && (sem.uboOffset != nil || sem.pushOffset != nil) {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same parameter #%lu (%lu / %lu)",
                   index, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, vecSize: Int, forSemantic semantic: ShaderBufferSemantic, ubo: Bool) -> Bool {
        guard let sem = semantics[semantic] else { return false }
        
        if sem.numberOfComponents != vecSize && (sem.uboOffset != nil || sem.pushOffset != nil) {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same semantic %@ (%lu / %lu)",
                   semantic.description as NSString, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.description as NSString, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.description as NSString, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, forTextureSemantic semantic: ShaderTextureSemantic, at index: Int, ubo: Bool) -> Bool {
        guard var map = textures[semantic] else { return false }
        var sem: ShaderTextureSemanticMeta
        if let tmp = map[index] {
            sem = tmp
        } else {
            sem = ShaderTextureSemanticMeta(index: index)
            map[index] = sem
            textures[semantic] = map
        }
        
        if ubo {
            if let existing = sem.uboOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.description as NSString, index, existing, offset)
                return false
            }
            sem.uboOffset = offset
        } else {
            if let existing = sem.pushOffset, existing != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.description as NSString, index, existing, offset)
                return false
            }
            sem.pushOffset = offset
        }
        
        return true
    }
    
    @discardableResult
    func setBinding(_ binding: Int, forTextureSemantic semantic: ShaderTextureSemantic, at index: Int) -> Bool {
        guard var map = textures[semantic] else { return false }
        var sem: ShaderTextureSemanticMeta
        if let tmp = map[index] {
            sem = tmp
        } else {
            sem = ShaderTextureSemanticMeta(index: index)
            map[index] = sem
            textures[semantic] = map
        }
        
        sem.binding = binding
        
        return true
    }
    
    // MARK: - Private functions
    
    private func textureSemanticForUniformName(_ name: String, names: [String: ShaderTextureSemantic]) -> ShaderTextureSemanticMap? {
        for (key, sem) in names {
            if textureSemanticIsArray(sem) {
                // An array texture may be referred to as PassOutput0, PassOutput1, etc
                if name.hasPrefix(key) {
                    // TODO: Validate the suffix is a number and within range
                    let index = Int(name.suffix(from: key.endIndex))
                    return ShaderTextureSemanticMap(textureSemantic: sem, index: index ?? 0)
                }
            } else if name == key {
                return ShaderTextureSemanticMap(textureSemantic: sem, index: 0)
            }
        }
        return nil
    }
    
    // MARK: - Static variables
    
    static let textureSemanticArrays: Set<ShaderTextureSemantic> = [.originalHistory, .passOutput, .passFeedback, .user]
    
    static let textureSemanticNames: [String: ShaderTextureSemantic] = [
        "Original": .original,
        "Source": .source,
        "OriginalHistory": .originalHistory,
        "PassOutput": .passOutput,
        "PassFeedback": .passFeedback,
        "User": .user,
    ]
    static let textureSemanticToName: [ShaderTextureSemantic: String] = [
        .original: "Original",
        .source: "Source",
        .originalHistory: "OriginalHistory",
        .passOutput: "PassOutput",
        .passFeedback: "PassFeedback",
        .user: "User",
    ]
    
    static let textureSemanticUniformNames: [String: ShaderTextureSemantic] = [
        "OriginalSize": .original,
        "SourceSize": .source,
        "OriginalHistorySize": .originalHistory,
        "PassOutputSize": .passOutput,
        "PassFeedbackSize": .passFeedback,
        "UserSize": .user,
    ]
    static let textureSemanticToUniformName: [ShaderTextureSemantic: String] = [
        .original: "OriginalSize",
        .source: "SourceSize",
        .originalHistory: "OriginalHistorySize",
        .passOutput: "PassOutputSize",
        .passFeedback: "PassFeedbackSize",
        .user: "UserSize",
    ]
    
    static let semanticUniformNames: [String: ShaderSemanticMap] = [
        "MVP": .init(semantic: .mvp),
        "OutputSize": .init(semantic: .outputSize),
        "FinalViewportSize": .init(semantic: .finalViewportSize),
        "FrameCount": .init(semantic: .frameCount),
        "FrameDirection": .init(semantic: .frameDirection),
    ]
    static let semanticToUniformName: [ShaderBufferSemantic: String] = [
        .mvp: "MVP",
        .outputSize: "OutputSize",
        .finalViewportSize: "FinalViewportSize",
        .frameCount: "FrameCount",
        .frameDirection: "FrameDirection",
    ]
}

extension ShaderReflection: CustomDebugStringConvertible {
    var debugDescription: String {
        var desc = ""
        desc.append("\n")
        desc.append("  → textures:\n")
        
        for sem in ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.binding != nil {
                desc.append(String(format: "      %@ (#%lu)\n",
                                   sem.description as NSString, meta.index))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Uniforms (vertex: %@, fragment %@):\n",
                           ubo?.bindingVert != nil ? "YES" : "NO",
                           ubo?.bindingFrag != nil ? "YES" : "NO"))
        
        for sem in ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], let offset = meta.uboOffset {
                desc.append(String(format: "      UBO  %@ (offset: %lu)\n",
                                   sem.description as NSString, offset))
            }
        }
        
        for sem in ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.uboOffset != nil {
                desc.append(String(format: "      UBO  %@ (#%lu) (offset: %lu)\n",
                                   Self.textureSemanticToUniformName[sem]!, meta.index, meta.uboOffset!))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Push (vertex: %@, fragment %@):\n",
                           push?.bindingVert != nil ? "YES" : "NO",
                           push?.bindingFrag != nil ? "YES" : "NO"))
        
        for sem in ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], let offset = meta.pushOffset {
                desc.append(String(format: "      PUSH %@ (offset: %lu)\n",
                                   sem.description as NSString, offset))
            }
        }
        
        for sem in ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for meta in t.values.sorted(by: { $0.index < $1.index }) where meta.pushOffset != nil {
                desc.append(String(format: "      PUSH %@ (#%lu) (offset: %lu)\n",
                                   Self.textureSemanticToUniformName[sem]!, meta.index, meta.pushOffset!))
            }
        }
        
        desc.append("\n")
        desc.append("  → Parameters:\n")
        
        for meta in floatParameters.values.sorted(by: { $0.index < $1.index }) {
            if let offset = meta.uboOffset {
                desc.append(String(format: "      UBO  #%lu (offset: %lu)\n", meta.index, offset))
            }
            if let offset = meta.pushOffset {
                desc.append(String(format: "      PUSH #%lu (offset: %lu)\n", meta.index, offset))
            }
        }
        
        desc.append("\n")
        
        return desc
    }
}
