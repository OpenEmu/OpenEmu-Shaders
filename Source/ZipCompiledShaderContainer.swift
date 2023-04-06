//
//  CompiledShaderContainer+Zip.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 19/10/2022.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation
@_implementationOnly import ZIPFoundation

public enum ZipCompiledShaderContainer {
    enum Error: Swift.Error {
        /// The specified path does not exist.
        case pathNotExists
        
        /// The specified path is not a valid archive.
        case invalidArchive
        
        /// The specified path is missing shader.json.
        case missingCompiledShader
    }
    
    /// Encode a ``Compiled.Shader`` to a ZIP archive that may be distributed.
    public static func encode(shader: Compiled.Shader, to path: URL) throws {
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        
        guard let ar = Archive(url: path, accessMode: .create)
        else {
            return
        }
        
        try shader.luts.forEach { lut in
            // Duplicate names are not permitted during compilation, so there should never
            // be conflicts.
            // Compression is probably not necessary here, as most images are already compressed.
            try ar.addEntry(with: "\(lut.name)__\(lut.url.lastPathComponent)", fileURL: lut.url, compressionMethod: .deflate)
        }
        
        let je = JSONEncoder()
        je.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try je.encode(shader)
        
        try ar.addEntry(with: "shader.json", type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
    }

    public final class Decoder: CompiledShaderContainer {
        public let shader: Compiled.Shader
        private let archive: Archive
        
        public convenience init(url: URL) throws {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw Error.pathNotExists
            }
            if let archive = Archive(url: url, accessMode: .read) {
                try self.init(archive: archive)
            } else {
                throw Error.invalidArchive
            }
        }
        
        public convenience init(data: Data) throws {
            if let archive = Archive(data: data, accessMode: .read) {
                try self.init(archive: archive)
            } else {
                throw Error.invalidArchive
            }
        }
        
        private init(archive: Archive) throws {
            self.archive = archive
            if let entry = archive["shader.json"] {
                var data = Data(capacity: Int(entry.uncompressedSize))
                let crc = try archive.extract(entry, consumer: { block in
                    data.append(block)
                })
                if crc != entry.checksum {
                    throw Error.invalidArchive
                }
                
                let jd = JSONDecoder()
                shader = try jd.decode(Compiled.Shader.self, from: data)
            } else {
                throw Error.missingCompiledShader
            }
        }
        
        public func getLUTByName(_ name: String) throws -> Data {
            let prefix = name + "__"
            guard let entry = archive.first(where: { $0.path.hasPrefix(prefix) }) else {
                throw CompiledShaderContainerError.invalidLUTName
            }
            var data = Data(capacity: Int(entry.uncompressedSize))
            let crc = try archive.extract(entry, consumer: { block in
                data.append(block)
            })
            if crc != entry.checksum {
                throw Error.invalidArchive
            }
            return data
        }
    }
}
