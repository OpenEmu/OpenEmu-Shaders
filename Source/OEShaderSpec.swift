//
//  ConfigEncoder.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/11/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import Foundation

extension OEShaderTextureSemantic: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        switch s {
        case OEShaderTextureSemantic.original.rawValue,
             OEShaderTextureSemantic.originalHistory.rawValue,
             OEShaderTextureSemantic.originalHistory.rawValue:
            self.init(rawValue: s)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "\(s) is not a valid value for OEShaderTextureSemantic"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
    }
}

@objc
public class OEShaderSpec : NSObject, Codable {
    @objc
    public var passes: [OEShaderPass]
    
    @objc
    public class OEShaderPass : NSObject, Codable {
        var shader: String
        var alias: String?
    }
    
    public override init() {
        passes = []
    }
}
