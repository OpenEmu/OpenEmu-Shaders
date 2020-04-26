// Copyright (c) 2019, OpenEmu Team
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
import CommonCrypto
import CryptoKit

enum SourceParserError: LocalizedError {
    case missingVersion
    case multipleFormatPragma
    case multipleNamePragma
    case duplicateParameterPragma
    case includeNotFound
    case includeFileNotFound(String)
    case invalidParameterPragma
    case invalidFormatPragma
    
    var errorDescription: String? {
        switch self {
        case .missingVersion:
            return NSLocalizedString("Root slang shader missing #version", comment: "The slang file is missing the required #version directive")
        case .multipleFormatPragma:
            return NSLocalizedString("#pragma format declared multiple times", comment: "The slang file contains multiple declarations of the #pragma format directive")
        case .multipleNamePragma:
            return NSLocalizedString("#pragma name declared multiple times", comment: "The slang file contains multiple declarations of the #pragma name directive")
        case .duplicateParameterPragma:
            return NSLocalizedString("duplicate #pragma parameter", comment: "The slang file contains duplicate #pragma parameter directives")
        case .includeNotFound:
            return NSLocalizedString("#include not found", comment: "The slang file has an invalid #include directive")
        case .includeFileNotFound(let filename):
            return String(format: NSLocalizedString("#include file not found: %@", comment: "The slang file has an invalid #include directive"), filename)
        case .invalidParameterPragma:
            return NSLocalizedString("invalid #pragma parameter declaration", comment: "The slang file contains an invalid parameter directive")
        case .invalidFormatPragma:
            return NSLocalizedString("invalid #pragma format", comment: "The slang file contains an invalid #pragma format directive")
        }
    }
}

extension String {
    mutating func replaceOccurrences(of target: String, with replacement: String, options: String.CompareOptions = [], locale: Locale? = nil) {
        var range: Range<String.Index>?
        repeat {
            range = self.range(of: target, options: options, range: range.map { $0.lowerBound..<self.endIndex }, locale: locale)
            if let range = range {
                self.replaceSubrange(range, with: replacement)
            }
        } while range != nil
    }
}

extension Sequence where Self.Element == UInt8 {
    var base64: String {
        var res = Data(self).base64EncodedString()
        res.replaceOccurrences(of: "+", with: "-")
        res.replaceOccurrences(of: "/", with: "_")
        res.replaceOccurrences(of: "=", with: "")
        return res
    }
}

/**
 * OESourceParser is responsible for parsing the .slang source file from the provided url.
 *
 * Valid `#pragma` directives include `name`, `format` and `parameter`.
 */
@objc(OESourceParser)
class SourceParser: NSObject {
    
    private var buffer: [String]
    var parametersMap: [String: ShaderParameter]
    var included: Set<String> = Set()
    
    @objc private(set) var name: String?
    
    @objc let basename: String
    
    @objc var parameters: [ShaderParameter]
    
    @objc var format: MTLPixelFormat
    
    @objc lazy var sha256: String = {
        let data = Array(buffer.joined().utf8)
        if #available(OSX 10.15, *) {
            let digest = SHA256.hash(data: data)
            return digest.base64
        }
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.base64
    }()
    
    /**
     Returns the vertex shader portion of the slang file
     */
    @objc lazy var vertexSource: String = {
        return self.findSource(forStage: "vertex")
    }()
    
    /**
     Returns the fragment shader portion of the slang file
     */
    @objc lazy var fragmentSource: String = {
        return self.findSource(forStage: "fragment")
    }()
    
    @objc
    init(fromURL url: URL) throws {
        buffer = []
        parametersMap = [:]
        parameters = []
        format = .invalid
        basename = (url.lastPathComponent as NSString).deletingPathExtension
        super.init()
        
        try autoreleasepool {
            try self.load(url, isRoot: true)
        }
    }
    
    fileprivate func findSource(forStage: String) -> String {
        var src: [String] = []
        var keep          = true
        for line in buffer {
            if line.hasPrefix(Prefixes.pragmaStage) {
                let s = Scanner(string: line)
                s.scanString(Prefixes.pragmaStage, into: nil)
                var tmp: NSString?
                s.scanCharacters(from: .alphanumerics, into: &tmp)
                guard let stage = tmp as String? else {
                    continue
                }
                keep = stage == forStage
            } else if line.hasPrefix(Prefixes.pragmaName) || line.hasPrefix(Prefixes.pragmaFormat) {
                // skip
            } else if keep {
                src.append(line)
            }
        }
        
        return src.joined(separator: "\n")
    }
    
    struct Prefixes {
        static let version          = "#version "
        static let include          = "#include "
        static let endif            = "#endif"
        static let pragma           = "#pragma "
        static let pragmaName       = "#pragma name "
        static let pragmaParam      = "#pragma parameter "
        static let pragmaParamGroup = "#pragma parameter_group "
        static let pragmaFormat     = "#pragma format "
        static let pragmaStage      = "#pragma stage "
    }
    
    
    fileprivate func load(_ url: URL, isRoot: Bool) throws {
        let f        = try String(contentsOf: url)
        let filename = url.lastPathComponent
        var lines    = [String]()
        f.enumerateLines { line, _ in lines.append(line) }

        var lno = 1
        
        var oe = lines.makeIterator()
        if isRoot {
            let line = oe.next()
            switch line?.hasPrefix(Prefixes.version) {
            case .some(false), .none:
                throw SourceParserError.missingVersion
            default:
                buffer.append(line!)
                buffer.append("#extension GL_GOOGLE_cpp_style_line_directive : require")
                lno += 1;
            }
        }
        
        buffer.append("#line \(lno) \"\(filename)\"")
        
        for line in oe {
            if line.hasPrefix(Prefixes.include) {
                let s = Scanner(string: line)
                s.scanString(Prefixes.include, into: nil)
                guard let filepath = s.scanQuotedString() else {
                    throw SourceParserError.includeNotFound
                }
                let file = URL(string: filepath, relativeTo: url.deletingLastPathComponent())!
                if file.isFileURL && !FileManager.default.fileExists(atPath: file.path) {
                    throw SourceParserError.includeFileNotFound(file.path)
                }
                if !included.contains(file.absoluteString) {
                    try self.load(file, isRoot: false)
                    buffer.append("#line \(lno) \"\(filename)\"")
                    included.insert(file.absoluteString)
                }
            } else {
                buffer.append(line)
                
                var hasPreprocessor = false;
                if line.hasPrefix(Prefixes.pragma) {
                    hasPreprocessor = true;
                    try self.processPragma(line: line)
                } else if line.hasPrefix(Prefixes.endif) {
                    hasPreprocessor = true;
                }
                
                if hasPreprocessor {
                    buffer.append("#line \(lno + 1) \"\(filename)\"")
                }
            }
            lno += 1;
        }
    }
    
    static let identifierCharacters = { () -> CharacterSet in
        var set = CharacterSet.alphanumerics
        set.formUnion(CharacterSet(charactersIn: "_"))
        return set as CharacterSet
    }
    
    fileprivate func processPragma(line: String) throws {
        if line.hasPrefix(Prefixes.pragmaName) {
            if name != nil {
                throw SourceParserError.multipleNamePragma
            }
            
            name = String(line.dropFirst(Prefixes.pragmaName.count))
        } else if line.hasPrefix(Prefixes.pragmaParam) {
            let s = Scanner(string: line)
            s.scanString(Prefixes.pragmaParam, into: nil)
            
            var count = 0;
            var tmp: NSString?
            count += s.scanCharacters(from: .identifierCharacters, into: &tmp) ? 1 : 0
            
            guard let name = tmp as String? else {
                throw SourceParserError.invalidParameterPragma
            }
            
            guard let desc = s.scanQuotedString() else {
                throw SourceParserError.invalidParameterPragma
            }
            count += 1
            var initial: Float = 0, minimum: Float = 0, maximum: Float = 0, step: Float = 0
            count += s.scanFloat(&initial) ? 1 : 0
            count += s.scanFloat(&minimum) ? 1 : 0
            count += s.scanFloat(&maximum) ? 1 : 0
            count += s.scanFloat(&step) ? 1 : 0
            
            if count == 5 {
                step = 0.1 * (maximum - minimum);
                count += 1;
            }
            
            if count == 6 {
                let param = ShaderParameter(name: name, desc: desc)
                param.initial = initial;
                param.value = initial;
                param.minimum = minimum;
                param.maximum = maximum;
                param.step = step;
                
                if let existing = parametersMap[name], param != existing {
                    throw SourceParserError.duplicateParameterPragma
                }
                
                parametersMap[name] = param
                parameters.append(param)
            } else {
                throw SourceParserError.invalidParameterPragma
            }
        } else if line.hasPrefix(Prefixes.pragmaFormat) {
            if format != .invalid {
                throw SourceParserError.invalidParameterPragma
            }
            
            let s = Scanner(string: line)
            s.scanString(Prefixes.pragmaFormat, into: nil)
            var tmp: NSString?
            s.scanCharacters(from: .identifierCharacters, into: &tmp)
            if let fmt = tmp as String? {
                format = MTLPixelFormatFromGLSlangNSString(fmt);
            }
            if format == .invalid {
                throw SourceParserError.invalidFormatPragma
            }
        }
    }
}

extension CharacterSet {
    static var identifierCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.formUnion(CharacterSet(charactersIn: "_"))
        return set
    }()
    
    static var doubleQuotes: CharacterSet = {
        return CharacterSet(charactersIn: "\"")
    }()
    
    static var whitespacesAndComment: CharacterSet = {
        var set = CharacterSet.whitespaces
        set.formUnion(CharacterSet(charactersIn: "#"))
        return set
    }()
}
