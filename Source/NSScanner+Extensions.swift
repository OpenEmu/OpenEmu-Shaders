//
//  NSScanner+Extensions.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import Foundation

@objc
public extension Scanner {
    func scanQuotedString() -> String? {
        if !self.scanString("\"", into: nil) {
            return nil
        }
        var tmp: NSString?
        if !self.scanUpTo("\"", into: &tmp) {
            return nil
        }

        guard let s = tmp as String? else {
            return nil
        }
        
        if !self.scanString("\"", into: nil) {
            return nil
        }
        
        return s
    }
    
    @objc
    func scanQuotedString(_ s: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if !self.scanString("\"", into: nil) {
            return false
        }
        if !self.scanUpTo("\"", into: s) {
            return false
        }
        return self.scanString("\"", into: nil)
    }
}
