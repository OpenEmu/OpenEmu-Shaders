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

@objc
public class MTLPixelConverter: NSObject {
    enum Error: LocalizedError {
        case missingFunction(String)
    }
    
    struct Filter {
        let kernel:        MTLComputePipelineState
        let bytesPerPixel: UInt
    
        func convert(buffer src: MTLBuffer, bytesPerRow: UInt, out dst: MTLTexture, commandBuffer: MTLCommandBuffer) {
            let ce = commandBuffer.makeComputeCommandEncoder()!
            ce.label = "filter encoder"
            ce.setComputePipelineState(kernel)
            
            var stride = bytesPerRow / bytesPerPixel
            ce.setBuffer(src, offset: 0, index: 0)
            ce.setBytes(&stride, length: MemoryLayout.size(ofValue: stride), index: 1)
            ce.setTexture(dst, index: 0)
            
            let size  = MTLSizeMake(16, 16, 1)
            let count = MTLSizeMake(
                    (dst.width + size.width + 1) / size.width,
                    (dst.height + size.height + 1) / size.height,
                    1)
            ce.dispatchThreadgroups(count, threadsPerThreadgroup: size)
            ce.endEncoding()
        }
        
        func convert(texture src: MTLTexture, out dst: MTLTexture, commandBuffer: MTLCommandBuffer) {
            let ce = commandBuffer.makeComputeCommandEncoder()!
            ce.label = "filter encoder"
            ce.setComputePipelineState(kernel)
            
            ce.setTexture(src, index: 0)
            ce.setTexture(dst, index: 1)
            
            let size  = MTLSizeMake(16, 16, 1)
            let count = MTLSizeMake(
                    (src.width + size.width + 1) / size.width,
                    (src.height + size.height + 1) / size.height,
                    1)
            ce.dispatchThreadgroups(count, threadsPerThreadgroup: size)
            ce.endEncoding()
        }
    }
    
    static func makeFilter(function: String, device: MTLDevice, library: MTLLibrary, format: OEMTLPixelFormat) throws -> Filter {
        guard let fn = library.makeFunction(name: function) else {
            throw Error.missingFunction(function)
        }
        return Filter(kernel: try device.makeComputePipelineState(function: fn), bytesPerPixel: format.bpp)
    }
    
    let device:   MTLDevice
    let library:  MTLLibrary
    let texToTex: Filters
    let bufToTex: Filters
    
    typealias Filters = [Filter?]
    
    @objc
    public init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        let bundle = Bundle(for: type(of: self))
        self.library = try device.makeDefaultLibrary(bundle: bundle)
        
        var texToTex = Filters(repeating: nil, count: Int(OEMTLPixelFormat.count.rawValue))
        texToTex[.bgra4Unorm] = try MTLPixelConverter.makeFilter(
                function: "convert_bgra4444_to_bgra8888",
                device: device,
                library: self.library,
                format: .bgra4Unorm)
        texToTex[.b5g6r5Unorm] = try MTLPixelConverter.makeFilter(
                function: "convert_rgb565_to_bgra8888",
                device: device,
                library: self.library,
                format: .b5g6r5Unorm)
        self.texToTex = texToTex
        
        var bufToTex = Filters(repeating: nil, count: Int(OEMTLPixelFormat.count.rawValue))
        bufToTex[.bgra4Unorm] = try MTLPixelConverter.makeFilter(
                function: "convert_bgra4444_to_bgra8888_buf",
                device: device,
                library: self.library,
                format: .bgra4Unorm)
        bufToTex[.b5g6r5Unorm] = try MTLPixelConverter.makeFilter(
                function: "convert_rgb565_to_bgra8888_buf",
                device: device,
                library: self.library,
                format: .b5g6r5Unorm)
        bufToTex[.rgba8Unorm] = try MTLPixelConverter.makeFilter(
                function: "convert_rgba8888_to_bgra8888_buf",
                device: device,
                library: self.library,
                format: .rgba8Unorm)
        self.bufToTex = bufToTex
    }
    
    @objc
    public func convert(buffer src: MTLBuffer, bytesPerRow: UInt, fromFormat: OEMTLPixelFormat, to dst: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let filter = bufToTex[fromFormat] else {
            return
        }
        
        filter.convert(buffer: src, bytesPerRow: bytesPerRow, out: dst, commandBuffer: commandBuffer)
    }
    
    @objc
    public func convert(texture src: MTLTexture, fromFormat: OEMTLPixelFormat, to dst: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let filter = texToTex[fromFormat] else {
            return
        }
        
        filter.convert(texture: src, out: dst, commandBuffer: commandBuffer)
    }
}

extension MTLPixelConverter.Filters {
    subscript(index: OEMTLPixelFormat) -> MTLPixelConverter.Filter? {
        get {
            let idx = Int(index.rawValue)
            assert(idx < self.count)
            return self[idx]
        }
        set {
            let idx = Int(index.rawValue)
            self[idx] = newValue
        }
    }
}

extension OEMTLPixelFormat {
    var bpp: UInt {
        return OEMTLPixelFormatToBPP(self)
    }
}
