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

@objc(OEShaderParameter)
@objcMembers
public class ShaderParameter: NSObject {
    public var name:    String
    public var desc:    String
    public var group:   String = ""
    public var value:   Float = 0.0
    public var initial: Float = 0.0
    public var minimum: Float = 0.0
    public var maximum: Float = 1.0
    public var step:    Float = 0.01
    
    public var valuePtr: UnsafeMutablePointer<Float> {
        return UnsafeMutablePointer<Float>(&value)
    }
    
    public init(name: String, desc: String) {
        self.name = name
        self.desc = desc
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ShaderParameter else {
            return false
        }
        return self == other
    }
    
    public override var description: String {
        return "\(desc) (\(value))"
    }
}

extension ShaderParameter {
    static func ==(lhs: ShaderParameter, rhs: ShaderParameter) -> Bool {
        return lhs.name == rhs.name &&
                lhs.desc == rhs.desc &&
                lhs.initial == rhs.initial &&
                lhs.minimum == rhs.minimum &&
                lhs.maximum == rhs.maximum &&
                lhs.step == rhs.step;
    }
}
