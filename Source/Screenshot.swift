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

import CoreGraphics
import CoreImage
import Foundation

public class Screenshot {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    public init(device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
    }
    
    /// Apples the filter chain to the source texture and returns the result of the operation.
    /// - Parameters:
    ///   - f: The source filter chain.
    ///   - sourceTexture: The texture to apply the filter effects to.
    ///   - flip: `true` to flip the final output image.
    /// - Returns: A transformed version of `sourceTexture`.
    public func applyFilterChain(_ f: FilterChain, to sourceTexture: MTLTexture, flip: Bool = false, commandBuffer: MTLCommandBuffer? = nil) -> CGImage? {
        guard let tex = outputTexture(f.drawableSize) else { return nil }
        
        let rpd = MTLRenderPassDescriptor()
        if let ca = rpd.colorAttachments[0] {
            ca.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
            ca.loadAction = .clear
            ca.texture = tex
        }
        
        guard let commandBuffer = commandBuffer ?? commandQueue.makeCommandBuffer() else { return nil }
        
        f.render(sourceTexture: sourceTexture,
                 commandBuffer: commandBuffer,
                 renderPassDescriptor: rpd,
                 flipVertically: flip)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let img = ciImagefromTexture(tex: tex, crop: f.outputBounds) else {
            return nil
        }
        return cgImageFromCIImage(img)
    }
    
    // MARK: - Image helper functions
    
    public func ciImagefromTexture(tex: MTLTexture, crop: CGRect = .zero, flip: Bool = true) -> CIImage? {
        let opts: [CIImageOption: Any] = [
            .nearestSampling: true,
        ]
        
        guard var img = CIImage(mtlTexture: tex, options: opts) else { return nil }
        img = img.settingAlphaOne(in: img.extent)
        
        if !crop.isEmpty {
            img = img.cropped(to: crop)
        }
        
        if flip {
            img = img.transformed(by: .identity.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: img.extent.size.height))
        }
        
        return img
    }
    
    public func cgImageFromCIImage(_ img: CIImage) -> CGImage? {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cgImgTmp = ciContext.createCGImage(img, from: img.extent, format: .BGRA8, colorSpace: img.colorSpace) else {
            return nil
        }
        return cgImgTmp.copy(colorSpace: cs)
    }

    // MARK: - Implemenation
    
    private var outputTexture: MTLTexture?
    
    private func outputTexture(_ size: CGSize) -> MTLTexture? {
        if let outputTexture,
           outputTexture.width == Int(size.width), outputTexture.height == Int(size.height)
        {
            return outputTexture
        }
        
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                          width: Int(size.width),
                                                          height: Int(size.height),
                                                          mipmapped: false)
        td.storageMode = .private
        td.usage = [.shaderRead, .renderTarget]
        outputTexture = device.makeTexture(descriptor: td)
        return outputTexture
    }
    
    private lazy var ciContext: CIContext = .init(mtlDevice: device)
}
