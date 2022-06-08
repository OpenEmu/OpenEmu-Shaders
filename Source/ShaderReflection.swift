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
    var binding: Int = 0
    var uboOffset: Int = 0
    var pushOffset: Int = 0
    var stageUsage: StageUsage = []
    var textureActive: Bool = false
    var uboActive: Bool = false
    var pushActive: Bool = false
}

class ShaderSemanticMeta {
    var uboOffset: Int = 0
    var pushOffset: Int = 0
    var numberOfComponents: Int = 0
    var uboActive: Bool = false
    var pushActive: Bool = false
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
    
    init(semantic: ShaderBufferSemantic, index: Int) {
        self.semantic = semantic
        self.index    = index
    }
    
    init(semantic: ShaderBufferSemantic) {
        self.semantic = semantic
        self.index    = 0
    }
}

class ShaderReflection {
    let passNumber: Int
    var uboSize: Int = 0
    var pushSize: Int = 0
    var uboBindingVert: Int = 0
    var uboBindingFrag: Int = 0
    var pushBindingVert: Int = 0
    var pushBindingFrag: Int = 0
    var uboStageUsage: StageUsage = []
    var pushStageUsage: StageUsage = []
    
    init(passNumber: Int) {
        self.passNumber = passNumber
    }
    
    private(set) var textures: [ShaderTextureSemantic: [ShaderTextureSemanticMeta]] = [
        .original: [],
        .source: [],
        .originalHistory: [],
        .passOutput: [],
        .passFeedback: [],
        .user: [],
    ]
    
    private(set) var semantics: [ShaderBufferSemantic: ShaderSemanticMeta] = [
        .mvp: .init(),
        .outputSize: .init(),
        .finalViewportSize: .init(),
        .frameCount: .init(),
        .frameDirection: .init(),
    ]
    
    private(set) var floatParameters: [ShaderSemanticMeta] = []
    private(set) var textureSemanticMap: [String: ShaderTextureSemanticMap] = [:]
    private(set) var textureUniformSemanticMap: [String: ShaderTextureSemanticMap] = [:]
    private(set) var semanticMap: [String: ShaderSemanticMap] = [:]
    
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
    
    func addBufferSemantic(_ semantic: ShaderBufferSemantic, atIndex i: Int, name: String) -> Bool {
        if semanticMap[name] != nil {
            os_log(.error, log: .default, "pass %lu: alias %{public}@ already exists for buffer semantic %{public}@",
                   i, name, semantic.description as NSString)
            return false
        }
        
        semanticMap[name] = ShaderSemanticMap(semantic: semantic, index: i)
        
        return true
    }
    
    func name(forBufferSemantic semantic: ShaderBufferSemantic, index: Int) -> String? {
        if let name = Self.semanticToUniformName[semantic] {
            return name
        }
        
        return semanticMap.first { (_, v) in
            v.semantic == semantic && v.index == index
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
        semanticMap[name] ?? Self.semanticUniformNames[name]
    }
    
    func textureSemanticIsArray(_ semantic: ShaderTextureSemantic) -> Bool {
        Self.textureSemanticArrays[semantic] ?? false
    }
    
    func textureSemantic(forUniformName name: String) -> ShaderTextureSemanticMap? {
        textureUniformSemanticMap[name] ?? textureSemanticForUniformName(name, names: Self.textureSemanticUniformNames)
    }
    
    func textureSemantic(forName name: String) -> ShaderTextureSemanticMap? {
        textureSemanticMap[name] ?? textureSemanticForUniformName(name, names: Self.textureSemanticNames)
    }
    
    @discardableResult
    func reserve<T>(_ array: inout [T], withCapacity items: Int, new: () -> T) -> Bool {
        if array.count > items {
            return false
        }
        array.reserveCapacity(items)
        while array.count <= items {
            array.append(new())
        }
        return true
    }
    
    func setOffset(_ offset: Int, vecSize: Int, forFloatParameterAt index: Int, ubo: Bool) -> Bool {
        reserve(&floatParameters, withCapacity: index, new: ShaderSemanticMeta.init)
        let sem = floatParameters[index]
        
        if sem.numberOfComponents != vecSize && (sem.uboActive || sem.pushActive) {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same parameter #%lu (%lu / %lu)",
                   index, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if sem.uboActive && sem.uboOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, sem.uboOffset, offset)
                return false
            }
            sem.uboActive = true
            sem.uboOffset = offset
        } else {
            if sem.pushActive && sem.pushOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                       index, sem.pushOffset, offset)
                return false
            }
            sem.pushActive = true
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, vecSize: Int, forSemantic semantic: ShaderBufferSemantic, ubo: Bool) -> Bool {
        guard let sem = semantics[semantic] else { return false }
        
        if sem.numberOfComponents != vecSize && (sem.uboActive || sem.pushActive) {
            os_log(.error, log: .default, "vertex and fragment shaders have different data type sizes for same semantic %@ (%lu / %lu)",
                   semantic.rawValue, sem.numberOfComponents, vecSize)
            return false
        }
        
        if ubo {
            if sem.uboActive && sem.uboOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.rawValue, sem.uboOffset, offset)
                return false
            }
            sem.uboActive = true
            sem.uboOffset = offset
        } else {
            if sem.pushActive && sem.pushOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                       semantic.rawValue, sem.pushOffset, offset)
                return false
            }
            sem.pushActive = true
            sem.pushOffset = offset
        }
        
        sem.numberOfComponents = vecSize
        
        return true
    }
    
    func setOffset(_ offset: Int, forTextureSemantic semantic: ShaderTextureSemantic, at index: Int, ubo: Bool) -> Bool {
        guard var map = textures[semantic] else { return false }
        if reserve(&map, withCapacity: index, new: ShaderTextureSemanticMeta.init) {
            textures[semantic] = map
        }
        
        let sem = map[index]
        
        if ubo {
            if sem.uboActive && sem.uboOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.rawValue, index, sem.uboOffset, offset)
                return false
            }
            sem.uboActive = true
            sem.uboOffset = offset
        } else {
            if sem.pushActive && sem.pushOffset != offset {
                os_log(.error, log: .default, "vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                       semantic.rawValue, index, sem.pushOffset, offset)
                return false
            }
            sem.pushActive = true
            sem.pushOffset = offset
        }
        
        return true
    }
    
    @discardableResult
    func setBinding(_ binding: Int, forTextureSemantic semantic: ShaderTextureSemantic, at index: Int) -> Bool {
        guard var map = textures[semantic] else { return false }
        if reserve(&map, withCapacity: index, new: ShaderTextureSemanticMeta.init) {
            textures[semantic] = map
        }
        
        let sem = map[index]
        
        sem.binding = binding
        sem.textureActive = true
        sem.stageUsage = .fragment
        
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
    
    static let textureSemanticArrays: [ShaderTextureSemantic: Bool] = [
        .original: false,
        .source: false,
        .originalHistory: true,
        .passOutput: true,
        .passFeedback: true,
        .user: true,
    ]
    
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
            for (i, meta) in t.enumerated() where meta.textureActive {
                desc.append(String(format: "      %@ (#%lu)\n",
                                   sem.description as NSString, i))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Uniforms (vertex: %@, fragment %@):\n",
                           uboStageUsage.contains(.vertex) ? "YES" : "NO",
                           uboStageUsage.contains(.fragment) ? "YES" : "NO"))
        
        for sem in ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], meta.uboActive {
                desc.append(String(format: "      UBO  %@ (offset: %lu)\n",
                                   sem.description as NSString, meta.uboOffset))
            }
        }
        
        for sem in ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for (i, meta) in t.enumerated() where meta.uboActive {
                desc.append(String(format: "      UBO  %@ (#%lu) (offset: %lu)\n",
                                   Self.textureSemanticToUniformName[sem]!, i, meta.uboOffset))
            }
        }
        
        desc.append("\n")
        desc.append(String(format: "  → Push (vertex: %@, fragment %@):\n",
                           pushStageUsage.contains(.vertex) ? "YES" : "NO",
                           pushStageUsage.contains(.fragment) ? "YES" : "NO"))
        
        for sem in ShaderBufferSemantic.allCases {
            if let meta = semantics[sem], meta.pushActive {
                desc.append(String(format: "      PUSH %@ (offset: %lu)\n",
                                   sem.description as NSString, meta.pushOffset))
            }
        }
        
        for sem in ShaderTextureSemantic.allCases {
            guard let t = textures[sem] else { continue }
            for (i, meta) in t.enumerated() where meta.pushActive {
                desc.append(String(format: "      PUSH %@ (#%lu) (offset: %lu)\n",
                                   Self.textureSemanticToUniformName[sem]!, i, meta.pushOffset))
            }
        }
        
        desc.append("\n")
        desc.append("  → Parameters:\n")
        
        for (i, meta) in floatParameters.enumerated() {
            if meta.uboActive {
                desc.append(String(format: "      UBO  #%lu (offset: %lu)\n", i, meta.uboOffset))
            }
            if meta.pushActive {
                desc.append(String(format: "      PUSH #%lu (offset: %lu)\n", i, meta.pushOffset))
            }
        }
        
        desc.append("\n")
        
        return desc
    }
}
