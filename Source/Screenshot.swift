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
import CoreImage
import CoreGraphics

public protocol ScreenshotSource {
    var drawableSize: CGSize { get }
    var outputBounds: CGRect { get }
    var sourceTexture: MTLTexture? { get }
    var sourceTextureIsFlipped: Bool { get }
    func render(withCommandBuffer commandBuffer: MTLCommandBuffer,
                renderPassDescriptor rpd: MTLRenderPassDescriptor)
    func renderSource(withCommandBuffer commandBuffer: MTLCommandBuffer) -> MTLTexture
}

public class Screenshot: NSObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    public init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
    }
    
    var screenshotTexture: MTLTexture?
    
    func screenshotTexture(_ size: CGSize) -> MTLTexture? {
        if let screenshotTexture = screenshotTexture,
           screenshotTexture.width == Int(size.width) && screenshotTexture.height == Int(size.height) {
            return screenshotTexture
        }
        
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                          width: Int(size.width),
                                                          height: Int(size.height),
                                                          mipmapped: false)
        td.storageMode = .private
        td.usage = [.shaderRead, .renderTarget]
        screenshotTexture = device.makeTexture(descriptor: td)
        return screenshotTexture
    }
    
    func fromMTLTexture(tex: MTLTexture, rect: CGRect) -> CIImage? {
        let opts: [CIImageOption: Any] = [
            .nearestSampling: true,
        ]
        
        guard var img = CIImage(mtlTexture: tex, options: opts)
        else { return nil }
        img = img.settingAlphaOne(in: img.extent)
        img = img.cropped(to: rect)
        return img.transformed(by: .identity.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: img.extent.size.height))
    }
    
    lazy var ciContext: CIContext = {
        CIContext(mtlDevice: device)
    }()
    
    func imageWithCIImage(_ img: CIImage) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = ciContext
        if let cgImgTmp = ctx.createCGImage(img, from: img.extent, format: .BGRA8, colorSpace: img.colorSpace) {
            if let cgImg = cgImgTmp.copy(colorSpace: cs) {
                return cgImg
            }
        }
        return blackImage
    }
    
    /// Returns a raw image of the last rendered source pixel buffer.
    /// 
    /// The image dimensions are equal to the source pixel
    /// buffer and therefore not aspect corrected.
    public func getCGImageFromSourceWithFilterChain(_ f: ScreenshotSource) -> CGImage {
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { return blackImage }
        
        let tex = f.renderSource(withCommandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let opts: [CIImageOption: Any] = [
            .nearestSampling: true,
        ]
        
        guard var img = CIImage(mtlTexture: tex, options: opts)
        else { return blackImage }
        img = img.settingAlphaOne(in: img.extent)
        if f.sourceTexture == nil || !f.sourceTextureIsFlipped {
            img = img.transformed(by: .identity.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: img.extent.size.height))
        }
        return imageWithCIImage(img)
    }
    
    /// Returns an image of the last source image after all shaders have been applied
    public func getCGImageFromOutputWithFilterChain(_ f: ScreenshotSource) -> CGImage {
        guard let tex = screenshotTexture(f.drawableSize)
        else { return blackImage }
        
        let rpd = MTLRenderPassDescriptor()
        if let ca = rpd.colorAttachments[0] {
            ca.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
            ca.loadAction = .clear
            ca.texture = tex
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else { return blackImage }
        
        f.render(withCommandBuffer: commandBuffer, renderPassDescriptor: rpd)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if let img = fromMTLTexture(tex: tex, rect: f.outputBounds) {
            return imageWithCIImage(img)
        }
        return blackImage
    }
    
    lazy var blackImage: CGImage = {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx: CGContext = .init(data: nil,
                                   width: 32, height: 32,
                                   bitsPerComponent: 8,
                                   bytesPerRow: 32 * 4,
                                   space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        
        ctx.setFillColor(.black)
        ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return ctx.makeImage()!
    }()
}
