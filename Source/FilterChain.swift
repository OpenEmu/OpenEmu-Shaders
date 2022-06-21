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
import Metal
import MetalKit
import os.log

@objc final public class FilterChain: NSObject, ScreenshotSource {
    enum InitError: Error {
        case invalidSamplerState
    }
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let loader: MTKTextureLoader
    private let converter: MTLPixelConverter
    
    private var vertex = [
        Vertex(position: simd_float4(x: 0, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 1)),
        Vertex(position: simd_float4(x: 1, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 1)),
        Vertex(position: simd_float4(x: 0, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 0)),
        Vertex(position: simd_float4(x: 1, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 0)),
    ]
    private var vertexFlipped = [
        Vertex(position: simd_float4(x: 0, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 0)),
        Vertex(position: simd_float4(x: 0, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 0, y: 1)),
        Vertex(position: simd_float4(x: 1, y: 1, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 0)),
        Vertex(position: simd_float4(x: 1, y: 0, z: 0, w: 1), texCoord: simd_float2(x: 1, y: 1)),
    ]
    let vertexSizeBytes: Int
    
    private var pixelBuffer: PixelBuffer?
    private var samplers: SamplerFilterArray<MTLSamplerState>
    
    public var shader: SlangShader?
    
    private var frameCount: UInt = 0
    private var passCount: Int = 0
    private var lastPassIndex: Int = 0
    private var lutCount: Int = 0
    private var historyCount: Int = 0
    
    private var texture: MTLTexture? // final render texture
    private var sourceTextures = [Texture](repeating: .init(), count: Constants.maxFrameHistory + 1)
    
    private struct OutputFrame {
        var viewport: MTLViewport
        var outputSize: Float4
        
        init() {
            viewport = .init()
            outputSize = .init()
        }
    }
    private var outputFrame: OutputFrame = .init()
    
    fileprivate struct Pass {
        var buffers = [MTLBuffer?](repeating: nil, count: Constants.maxConstantBuffers)
        var vBuffers = [MTLBuffer?](repeating: nil, count: Constants.maxConstantBuffers) // array used for vertex binding
        var fBuffers = [MTLBuffer?](repeating: nil, count: Constants.maxConstantBuffers) // array used for fragment binding
        var renderTarget: Texture = .init()
        var feedbackTarget: Texture = .init()
        var frameCount: UInt32 = 0
        var frameCountMod: UInt32 = 0
        var frameDirection: UInt32 = 0
        var bindings: ShaderPassBindings?
        var viewport: MTLViewport = .init()
        var state: MTLRenderPipelineState?
        var hasFeedback: Bool = false
    }
    
    private var pass = [Pass](repeating: .init(), count: Constants.maxShaderPasses)
    private var luts = [Texture](repeating: .init(), count: Constants.maxTextures)
    private var lutsFlipped: Bool = false
    
    private var renderTargetsNeedResize = true
    private var historyNeedsInit = false
    
    @objc public private(set) var sourceRect: CGRect = .zero
    @objc public var sourceTextureIsFlipped: Bool = false
    
    private var aspectSize: CGSize = .zero
    
    @objc public private(set) var outputBounds: CGRect = .zero
    
    @objc public var frameDirection: Int = 1
    
    // render target layer state
    private let pipelineState: MTLRenderPipelineState
    
    private var _rotation: Float = 0

    private var uniforms: Uniforms = .init()
    private var uniformsNoRotate: Uniforms = .init()
    private lazy var checkers: MTLTexture = {
        // swiftlint: disable identifier_name force_try
        let T0 = UInt32(0xff000000)
        let T1 = UInt32(0xffffffff)
        var checkerboard = [
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
            T0, T1, T0, T1, T0, T1, T0, T1,
            T1, T0, T1, T0, T1, T0, T1, T0,
        ]
        
        let ctx = CGContext(data: &checkerboard,
                            width: 8,
                            height: 8,
                            bitsPerComponent: 8,
                            bytesPerRow: 32,
                            space: NSColorSpace.deviceRGB.cgColorSpace!,
                            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        let img = ctx.makeImage()!
        return try! loader.newTexture(cgImage: img)
    }()
    
    // device behaviour
    private let deviceHasUnifiedMemory: Bool
    
    // parameters state
    private var parameters = [Float](repeating: 0, count: Constants.maxParameters)
    private var parametersCount: Int = 0
    private var parametersMap: [String: Int] = [:]
    
    @objc public init(device: MTLDevice) throws {
        self.device = device
        if #available(macOS 10.15, iOS 11, *) {
            deviceHasUnifiedMemory = device.hasUnifiedMemory
        } else {
            deviceHasUnifiedMemory = false
        }
        
        library = try device.makeDefaultLibrary(bundle: Bundle(for: Self.self))
        loader = .init(device: device)
        converter = try .init(device: device)
        pipelineState = try Self.makePipelineState(device, library)
        samplers = try Self.makeSamplers(device)
        vertexSizeBytes = MemoryLayout<Vertex>.size * vertex.count
        
        super.init()
        
        self.rotation = 0
        setDefaultFilteringLinear(false)
    }
    
    // MARK: - Static helpers
    
    private static func makePipelineState(_ device: MTLDevice, _ library: MTLLibrary) throws -> MTLRenderPipelineState {
        let vd = MTLVertexDescriptor()
        if let attr = vd.attributes[VertexAttribute.position.rawValue] {
            attr.offset = MemoryLayout<Vertex>.offset(of: \Vertex.position)!
            attr.format = .float4
            attr.bufferIndex = BufferIndex.positions.rawValue
        }
        if let attr = vd.attributes[VertexAttribute.texcoord.rawValue] {
            attr.offset = MemoryLayout<Vertex>.offset(of: \Vertex.texCoord)!
            attr.format = .float2
            attr.bufferIndex = BufferIndex.positions.rawValue
        }
        if let l = vd.layouts[BufferIndex.positions.rawValue] {
            l.stride = MemoryLayout<Vertex>.stride
        }
        
        let psd = MTLRenderPipelineDescriptor()
        psd.label = "Pipeline+No Alpha"
        
        if let ca = psd.colorAttachments[0] {
            ca.pixelFormat                 = .bgra8Unorm // NOTE(sgc): expected layer format (could be taken from layer.pixelFormat)
            ca.isBlendingEnabled           = false
            ca.sourceAlphaBlendFactor      = .sourceAlpha
            ca.sourceRGBBlendFactor        = .sourceAlpha
            ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            ca.destinationRGBBlendFactor   = .oneMinusSourceAlpha
        }

        psd.sampleCount = 1
        psd.vertexDescriptor = vd
        psd.vertexFunction = library.makeFunction(name: "basic_vertex_proj_tex")
        psd.fragmentFunction = library.makeFunction(name: "basic_fragment_proj_tex")
        
        return try device.makeRenderPipelineState(descriptor: psd)
    }
    
    private static func makeSamplers(_ device: MTLDevice) throws -> SamplerFilterArray<MTLSamplerState> {
        var samplers = [[MTLSamplerState?]](repeating: [MTLSamplerState?](repeating: nil,
                                                                          count: ShaderPassWrap.allCases.count),
                                            count: ShaderPassFilter.allCases.count)
        let sd = MTLSamplerDescriptor()
        for i in ShaderPassWrap.allCases {
            var label = ""
            switch i {
            case .border:
                if #available(macOS 10.15, iOS 11, *) {
                    if device.supportsFamily(.apple1) {
                        label = "clamp_to_zero"
                        sd.sAddressMode = .clampToZero
                        break
                    }
                }
                
                label = "clamp_to_border"
                sd.sAddressMode = .clampToBorderColor
                
            case .edge:
                label = "clamp_to_edge"
                sd.sAddressMode = .clampToEdge
                
            case .repeat:
                label = "repeat"
                sd.sAddressMode = .repeat
                
            case .mirroredRepeat:
                label = "mirrored_repeat"
                sd.sAddressMode = .mirrorRepeat
            }
            
            sd.tAddressMode = sd.sAddressMode
            sd.rAddressMode = sd.sAddressMode
            sd.minFilter = .linear
            sd.magFilter = .linear
            sd.label = "\(label) (linear)"
            if let ss = device.makeSamplerState(descriptor: sd) {
                samplers[.linear][i] = ss
            } else {
                throw InitError.invalidSamplerState
            }
            
            sd.minFilter = .nearest
            sd.magFilter = .nearest
            sd.label = label
            if let ss = device.makeSamplerState(descriptor: sd) {
                samplers[.nearest][i] = ss
            } else {
                throw InitError.invalidSamplerState
            }
        }
        
        // swiftlint: disable force_cast
        return samplers.map { $0.compactMap { $0 } } as! SamplerFilterArray<MTLSamplerState>
    }
    
    var rotation: Float {
        get { _rotation }
        set {
            _rotation = newValue * 270
            
            uniformsNoRotate.projectionMatrix = .makeOrtho(left: 0, right: 1, top: 0, bottom: 1)
            
            let rot = simd_float4x4.makeRotated(z: (Float.pi * newValue) / 180.0)
            uniforms.projectionMatrix = rot * uniformsNoRotate.projectionMatrix
        }
    }
    
    /// Sets the default filtering mode when a shader pass leaves the value unspecified.
    ///
    /// When a shader does not spcify a filtering mode, the default will be
    /// determined from this method.
    ///
    /// - parameters:
    ///     - linear: `true` to use linear filtering
    @objc public func setDefaultFilteringLinear(_ linear: Bool) {
        if linear {
            samplers[.unspecified] = samplers[.linear]
        } else {
            samplers[.unspecified] = samplers[.nearest]
        }
    }
    
    @objc public var sourceTexture: MTLTexture? {
        didSet {
            pixelBuffer = nil
            texture = nil
        }
    }
    
    private func updateHistory() -> [MTLTexture]? {
        if shader != nil {
            if historyCount > 0 {
                if historyNeedsInit {
                    return initHistory()
                } else {
                    let tmp = sourceTextures[historyCount]
                    for k in (1...historyCount).reversed() {
                        sourceTextures[k] = sourceTextures[k - 1]
                    }
                    sourceTextures[0] = tmp
                }
            }
        }
        
        if let sourceTexture = sourceTexture, historyCount == 0 {
            initTexture(&sourceTextures[0], withTexture: sourceTexture)
            return nil
        }
        
        // either no history, or we moved a texture of a different size in the front slot
        if sourceTextures[0].size.x != Float(sourceRect.width) || sourceTextures[0].size.y != Float(sourceRect.height) {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                              width: Int(sourceRect.width),
                                                              height: Int(sourceRect.height),
                                                              mipmapped: false)
            td.storageMode = .private
            td.usage = [.shaderRead, .shaderWrite]
            initTexture(&sourceTextures[0], withDescriptor: td)
            // Ensure the history texture is cleared before first use
            return [sourceTextures[0].view!]
        }
        
        return nil
    }
    
    private func resize() {
        let bounds = fitAspectRectIntoRect(aspectSize: aspectSize, size: drawableSize)
        if outputBounds.origin == bounds.origin && outputBounds.size == bounds.size {
            return
        }
        
        outputBounds = bounds
        let size = outputBounds.size
        
        outputFrame.viewport = MTLViewport(originX: Double(outputBounds.origin.x),
                                           originY: Double(outputBounds.origin.y),
                                           width: Double(size.width),
                                           height: Double(size.height),
                                           znear: 0,
                                           zfar: 1)
        outputFrame.outputSize = .init(width: size.width, height: size.height)
        
        if shader != nil {
            renderTargetsNeedResize = true
        }
    }
    
    @objc public func setSourceRect(_ rect: CGRect, aspect: CGSize) {
        if sourceRect == rect && aspectSize == aspect {
            return
        }
        
        sourceRect = rect
        if let pixelBuffer = pixelBuffer {
            pixelBuffer.outputRect = rect
        }
        aspectSize = aspect
        resize()
    }
    
    @objc public var drawableSize: CGSize = .zero {
        didSet {
            resize()
        }
    }
    
    @objc public func newBuffer(withFormat format: OEMTLPixelFormat, height: UInt, bytesPerRow: UInt) -> PixelBuffer {
        let pb = PixelBuffer.makeBuffer(withDevice: device, converter: converter, format: format, height: Int(height), bytesPerRow: Int(bytesPerRow))
        pb.outputRect = sourceRect
        pixelBuffer = pb
        return pb
    }
    
    @objc public func newBuffer(withFormat format: OEMTLPixelFormat, height: UInt, bytesPerRow: UInt, bytes pointer: UnsafeMutableRawPointer) -> PixelBuffer {
        let pb = PixelBuffer.makeBuffer(withDevice: device, converter: converter, format: format, height: Int(height), bytesPerRow: Int(bytesPerRow), bytes: pointer)
        pb.outputRect = sourceRect
        pixelBuffer = pb
        return pb
    }
    
    private func clearTextures(_ textures: [MTLTexture], withCommandBuffer commandBuffer: MTLCommandBuffer) {
        if #available(macOS 10.15, *) {
            /**
              Find the size of the largest texture, in order to allocate a buffer with at least enough space for all textures.
             */
            var sizeMax = 0
            for t in textures {
                let bytesPerPixel = t.pixelFormat.bytesPerPixel
                precondition(bytesPerPixel > 0, "Unable to determine bytes per pixel for pixel format \(t.pixelFormat)")
                
                let bytesPerRow   = t.width  * bytesPerPixel
                let bytesPerImage = t.height * bytesPerRow
                if bytesPerImage > sizeMax {
                    sizeMax = bytesPerImage
                }
            }
            
            /**
             Allocate a buffer over the entire heap and fill it with zeros
             */
            if let bce = commandBuffer.makeBlitCommandEncoder(),
                let buf = device.makeBuffer(length: sizeMax, options: [.storageModePrivate]) {
                bce.fill(buffer: buf, range: 0..<sizeMax, value: 0)
                
                /**
                 Use the cleared buffer to clear the destination texture.
                 */
                for t in textures {
                    let bytesPerPixel = t.pixelFormat.bytesPerPixel
                    let bytesPerRow   = t.width  * bytesPerPixel
                    let bytesPerImage = t.height * bytesPerRow
                    let sourceSize    = MTLSize(width: t.width, height: t.height, depth: 1)
                    bce.copy(from: buf, sourceOffset: 0, sourceBytesPerRow: bytesPerRow, sourceBytesPerImage: bytesPerImage, sourceSize: sourceSize,
                             to: t, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .init())
                }
                bce.endEncoding()
            }
        }
    }
    
    private func prepareNextFrameWithCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        frameCount += 1
        
        let clear0 = resizeRenderTargets()
        let clear1 = updateHistory()
        
        if clear0 != nil || clear1 != nil {
            var textures = [MTLTexture]()
            if let clear0 = clear0 {
                textures.append(contentsOf: clear0)
            }
            if let clear1 = clear1 {
                textures.append(contentsOf: clear1)
            }
            clearTextures(textures, withCommandBuffer: commandBuffer)
        }
        
        texture = sourceTextures[0].view
        guard let texture = texture else { return }
        
        if let pixelBuffer = pixelBuffer {
            pixelBuffer.prepare(withCommandBuffer: commandBuffer, texture: texture)
            return
        }
        
        if let sourceTexture = sourceTexture {
            if historyCount == 0 {
                // sourceTextures[0].view == sourceTexture
                return
            }
            
            let orig: MTLOrigin = .init(x: Int(sourceRect.origin.x), y: Int(sourceRect.origin.y), z: 0)
            let size: MTLSize = .init(width: Int(sourceRect.width), height: Int(sourceRect.height), depth: 1)
            let zero: MTLOrigin = .init()
            
            if let bce = commandBuffer.makeBlitCommandEncoder() {
                bce.copy(from: sourceTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: orig, sourceSize: size,
                         to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: zero)
                bce.endEncoding()
            }
        }
    }
    
    private func initTexture(_ t: inout Texture, withDescriptor td: MTLTextureDescriptor) {
        t.view = device.makeTexture(descriptor: td)
        t.size = .init(width: td.width, height: td.height)
    }
    
    private func initTexture(_ t: inout Texture, withTexture tex: MTLTexture) {
        t.view = tex
        t.size = .init(width: tex.width, height: tex.height)
    }
    
    private func initHistory() -> [MTLTexture] {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                          width: Int(sourceRect.width),
                                                          height: Int(sourceRect.height),
                                                          mipmapped: false)
        td.storageMode = .private
        td.usage = [.shaderRead, .shaderWrite]

        var texs = [MTLTexture]()
        for i in 0...historyCount {
            initTexture(&sourceTextures[i], withDescriptor: td)
            texs.append(sourceTextures[i].view!)
        }
        historyNeedsInit = false
        return texs
    }
    
    private func renderTexture(_ texture: MTLTexture, renderCommandEncoder rce: MTLRenderCommandEncoder) {
        rce.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: BufferIndex.uniforms.rawValue)
        rce.setRenderPipelineState(pipelineState)
        rce.setFragmentSamplerState(samplers[.nearest][.edge], index: SamplerIndex.draw.rawValue)
        rce.setViewport(outputFrame.viewport)
        rce.setFragmentTexture(texture, index: TextureIndex.color.rawValue)
        rce.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    @objc public func renderSource(withCommandBuffer commandBuffer: MTLCommandBuffer) -> MTLTexture {
        prepareNextFrameWithCommandBuffer(commandBuffer)
        return texture!
    }
    
    @objc public func render(withCommandBuffer commandBuffer: MTLCommandBuffer,
                             renderPassDescriptor rpd: MTLRenderPassDescriptor) {
        renderOffscreenPassesWithCommandBuffer(commandBuffer)
        if let rce = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
            renderFinalPass(withCommandEncoder: rce)
            rce.endEncoding()
        }
    }
    
    @objc public func renderOffscreenPassesWithCommandBuffer(_ commandBuffer: MTLCommandBuffer) {
        prepareNextFrameWithCommandBuffer(commandBuffer)
        updateBuffersForPasses()
        
        guard shader != nil && passCount > 0 else { return }
        
        // flip feedback render targets
        for i in 0..<passCount where pass[i].hasFeedback {
            (pass[i].renderTarget, pass[i].feedbackTarget) = (pass[i].feedbackTarget, pass[i].renderTarget)
        }
        
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let lassPassIsDirect = pass[lastPassIndex].renderTarget.view == nil
        let count = lassPassIsDirect ? passCount - 1 : passCount
        
        for i in 0..<count {
            rpd.colorAttachments[0].texture = pass[i].renderTarget.view
            guard let rce = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { continue }
            rce.setVertexBytes(&vertex, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
            rce.setViewport(pass[i].viewport)
            renderPassIndex(i, renderCommandEncoder: rce)
            rce.endEncoding()
        }
    }
    
    private func updateBuffersForPasses() {
        for i in 0..<passCount {
            pass[i].frameDirection = UInt32(frameDirection)
            pass[i].frameCount     = UInt32(frameCount)
            if pass[i].frameCountMod != 0 {
                pass[i].frameCount %= pass[i].frameCountMod
            }
            
            for j in 0..<Constants.maxConstantBuffers {
                let sem = pass[i].bindings!.buffers[j]
                
                guard
                    (sem.bindingVert != nil || sem.bindingFrag != nil) &&
                        !sem.uniforms.isEmpty else { continue }
                
                if let buffer = pass[i].buffers[j] {
                    let data = buffer.contents()
                    for uniform in sem.uniforms {
                        data.advanced(by: uniform.offset).copyMemory(from: uniform.data, byteCount: uniform.size)
                    }
                    
                    if !deviceHasUnifiedMemory {
                        buffer.didModifyRange(0..<buffer.length)
                    }
                }
            }
        }
    }
    
    // these fields are used for per-pass state
    private var _renderTextures: [MTLTexture?] = .init(repeating: nil, count: Constants.maxShaderBindings)
    private var _renderSamplers: [MTLSamplerState?] = .init(repeating: nil, count: Constants.maxShaderBindings)
    private var _renderbOffsets: [Int] = .init(repeating: 0, count: Constants.maxConstantBuffers)
    
    private func renderPassIndex(_ i: Int, renderCommandEncoder rce: MTLRenderCommandEncoder) {
        defer {
            // clear references from temporary buffers
            for i in 0..<Constants.maxShaderBindings {
                _renderTextures[i] = nil
                _renderSamplers[i] = nil
            }
        }
        
        for bind in pass[i].bindings!.textures {
            let binding = Int(bind.binding)
            _renderTextures[binding] = bind.texture.load(as: MTLTexture?.self)
            _renderSamplers[binding] = samplers[bind.filter][bind.wrap]
        }
        
        // enqueue commands
        rce.setRenderPipelineState(pass[i].state!)
        rce.label = pass[i].state!.label
        
        rce.setVertexBuffers(pass[i].vBuffers, offsets: _renderbOffsets, range: 0..<Constants.maxConstantBuffers)
        rce.setFragmentBuffers(pass[i].fBuffers, offsets: _renderbOffsets, range: 0..<Constants.maxConstantBuffers)
        rce.setFragmentTextures(_renderTextures, range: 0..<Constants.maxShaderBindings)
        rce.setFragmentSamplerStates(_renderSamplers, range: 0..<Constants.maxShaderBindings)
        rce.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    @objc public func renderFinalPass(withCommandEncoder rce: MTLRenderCommandEncoder) {
        rce.setViewport(outputFrame.viewport)
        if sourceTexture != nil && sourceTextureIsFlipped {
            rce.setVertexBytes(&vertexFlipped, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
        } else {
            rce.setVertexBytes(&vertex, length: vertexSizeBytes, index: BufferIndex.positions.rawValue)
        }
        
        if shader == nil || passCount == 0 {
            guard let texture = texture else { return }
            return renderTexture(texture, renderCommandEncoder: rce)
        }
        
        if let view = pass[lastPassIndex].renderTarget.view {
            return renderTexture(view, renderCommandEncoder: rce)
        } else {
            // last pass renders directly to the final render target
            return renderPassIndex(lastPassIndex, renderCommandEncoder: rce)
        }
    }
    
    private func resizeRenderTargets() -> [MTLTexture]? {
        guard renderTargetsNeedResize else { return nil }
        guard let shader = shader else { return nil }

        for i in 0..<passCount {
            pass[i].renderTarget = .init()
            pass[i].feedbackTarget = .init()
        }
        
        var textures: [MTLTexture]?
        
        // width and height represent the size of the Source image to the current
        // pass
        var (width, height) = (sourceRect.width, sourceRect.height)
        
        let viewportSize = CGSize(width: outputFrame.viewport.width, height: outputFrame.viewport.height)
        
        for i in 0..<passCount {
            let pass = shader.passes[i]
            
            if pass.isScaled {
                switch pass.scaleX {
                case .source:
                    width *= pass.scale.width
                case .viewport:
                    width = viewportSize.width * pass.scale.width
                case .absolute:
                    width = pass.size.width
                default:
                    break
                }
                
                if width == 0 {
                    width = viewportSize.width
                }
                
                switch pass.scaleY {
                case .source:
                    height *= pass.scale.height
                case .viewport:
                    height = viewportSize.height * pass.scale.height
                case .absolute:
                    height = pass.size.height
                default:
                    break
                }
                
                if height == 0 {
                    height = viewportSize.height
                }
            } else if i == lastPassIndex {
                (width, height) = (viewportSize.width, viewportSize.height)
            }
            
            os_log("pass %d, render target size %0.0f x %0.0f", log: .default, type: .debug, i, width, height)
            
            let fmt = self.pass[i].bindings!.format
            if i != lastPassIndex ||
                width != viewportSize.width || height != viewportSize.height ||
                fmt != .bgra8Unorm {
                
                let (width, height) = (Int(width), Int(height))
                self.pass[i].viewport = .init(originX: 0, originY: 0,
                                              width: Double(width), height: Double(height),
                                              znear: 0, zfar: 1)
                
                let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: fmt,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
                td.storageMode = .private
                td.usage = [.shaderRead, .renderTarget]
                initTexture(&self.pass[i].renderTarget, withDescriptor: td)
                let label = String(format: "Pass %02d Output", i)
                self.pass[i].renderTarget.view?.label = label
                if self.pass[i].hasFeedback {
                    initTexture(&self.pass[i].feedbackTarget, withDescriptor: td)
                    self.pass[i].feedbackTarget.view?.label = label
                    if textures == nil {
                        textures = []
                    }
                    // textures should be cleared before first use
                    textures?.append(self.pass[i].renderTarget.view!)
                    textures?.append(self.pass[i].feedbackTarget.view!)
                }
            } else {
                // last pass can render directly to the output render target
                self.pass[i].renderTarget.size = .init(width: width, height: height)
            }
        }
        
        renderTargetsNeedResize = false
        
        return textures
    }
    
    private func freeShaderResources() {
        pass = .init(repeating: .init(), count: Constants.maxShaderPasses)
        luts = .init(repeating: .init(), count: Constants.maxTextures)
        sourceTextures = .init(repeating: .init(), count: Constants.maxFrameHistory + 1)
        
        parameters = .init(repeating: 0, count: Constants.maxParameters)
        parametersMap = [:]
        parametersCount = 0
        
        historyCount = 0
        passCount = 0
        lastPassIndex = 0
        lutCount = 0
    }
    
    @objc public func setShader(fromURL url: URL, options shaderOptions: ShaderCompilerOptions) throws {
        os_log("Loading shader from '%{public}@'", log: .default, type: .debug, url.absoluteString)
        
        freeShaderResources()
        
        let start = CACurrentMediaTime()
        
        let ss = try SlangShader(fromURL: url)
        
        passCount     = ss.passes.count
        lastPassIndex = passCount - 1
        lutCount      = ss.luts.count
        
        parametersCount = ss.parameters.count
        parametersMap   = .init(uniqueKeysWithValues: ss.parameters.enumerated().map({ index, param in (param.name, index) }))
        parameters      = .init(ss.parameters.map(\.initial))
        
        let compiler = ShaderPassCompiler(shaderModel: ss)
        
        let options = MTLCompileOptions()
        options.fastMathEnabled = true
        options.languageVersion = shaderOptions.languageVersion

        let texStride = MemoryLayout<Texture>.stride
        let texViewOffset = MemoryLayout<Texture>.offset(of: \Texture.view)!
        let texSizeOffset = MemoryLayout<Texture>.offset(of: \Texture.size)!
        
        for passNumber in 0..<passCount {
            let sem = ShaderPassSemantics()
            
            withUnsafePointer(to: &sourceTextures[0]) {
                let p = UnsafeRawPointer($0)
                sem.addTexture(p.advanced(by: texViewOffset),
                               size: p.advanced(by: texSizeOffset),
                               semantic: .original)
                
                sem.addTexture(p.advanced(by: texViewOffset), stride: texStride,
                               size: p.advanced(by: texSizeOffset), stride: texStride,
                               semantic: .originalHistory)
                
                if passNumber == 0 {
                    // The source texture for first pass is the original input
                    sem.addTexture(p.advanced(by: texViewOffset),
                                   size: p.advanced(by: texSizeOffset),
                                   semantic: .source)
                }
            }
            
            if passNumber > 0 {
                // The source texture for passes 1..<n is the output of the previous pass
                withUnsafePointer(to: &pass[passNumber-1].renderTarget) {
                    let p = UnsafeRawPointer($0)
                    sem.addTexture(p.advanced(by: texViewOffset),
                                   size: p.advanced(by: texSizeOffset),
                                   semantic: .source)
                }
            }
            
            withUnsafePointer(to: &pass[0]) {
                let p = UnsafeRawPointer($0)
                
                let rt = p.advanced(by: MemoryLayout<Pass>.offset(of: \Pass.renderTarget)!)
                sem.addTexture(rt.advanced(by: texViewOffset), stride: MemoryLayout<Pass>.stride,
                               size: rt.advanced(by: texSizeOffset), stride: MemoryLayout<Pass>.stride,
                               semantic: .passOutput)
                
                let ft = p.advanced(by: MemoryLayout<Pass>.offset(of: \Pass.feedbackTarget)!)
                sem.addTexture(ft.advanced(by: texViewOffset), stride: MemoryLayout<Pass>.stride,
                               size: ft.advanced(by: texSizeOffset), stride: MemoryLayout<Pass>.stride,
                               semantic: .passFeedback)
            }
            
            withUnsafePointer(to: &luts[0]) {
                let p = UnsafeRawPointer($0)
                sem.addTexture(p.advanced(by: texViewOffset), stride: texStride,
                               size: p.advanced(by: texSizeOffset), stride: texStride,
                               semantic: .user)
            }
            
            if passNumber == lastPassIndex {
                sem.addUniformData(&uniforms.projectionMatrix, semantic: .mvp)
            } else {
                sem.addUniformData(&uniformsNoRotate.projectionMatrix, semantic: .mvp)
            }
            
            withUnsafePointer(to: &pass[passNumber]) {
                let p = UnsafeRawPointer($0)
                sem.addUniformData(p.advanced(by: MemoryLayout<Pass>.offset(of: \Pass.renderTarget.size)!), semantic: .outputSize)
                sem.addUniformData(p.advanced(by: MemoryLayout<Pass>.offset(of: \Pass.frameCount)!), semantic: .frameCount)
                sem.addUniformData(p.advanced(by: MemoryLayout<Pass>.offset(of: \Pass.frameDirection)!), semantic: .frameDirection)
            }
            
            withUnsafePointer(to: &outputFrame.outputSize) {
                sem.addUniformData(UnsafeRawPointer($0), semantic: .finalViewportSize)
            }

            for i in 0..<parametersCount {
                withUnsafePointer(to: &parameters[i]) {
                    sem.addUniformData(UnsafeRawPointer($0), forParameterAt: i)
                }
            }
            
            pass[passNumber].bindings = compiler.bindings[passNumber]
            let (vsSrc, fsSrc) = try compiler.buildPass(passNumber, options: shaderOptions, passSemantics: sem)
            
            let pass = ss.passes[passNumber]
            self.pass[passNumber].frameCountMod = UInt32(pass.frameCountMod)
            
            let vd = MTLVertexDescriptor()
            if let attr = vd.attributes[VertexAttribute.position.rawValue] {
                attr.offset = MemoryLayout<Vertex>.offset(of: \Vertex.position)!
                attr.format = .float4
                attr.bufferIndex = BufferIndex.positions.rawValue
            }
            if let attr = vd.attributes[VertexAttribute.texcoord.rawValue] {
                attr.offset = MemoryLayout<Vertex>.offset(of: \Vertex.texCoord)!
                attr.format = .float2
                attr.bufferIndex = BufferIndex.positions.rawValue
            }
            if let l = vd.layouts[BufferIndex.positions.rawValue] {
                l.stride = MemoryLayout<Vertex>.stride
            }
            
            let psd = MTLRenderPipelineDescriptor()
            if let alias = pass.alias {
                psd.label = "pass \(passNumber) (\(alias))"
            } else {
                psd.label = "pass \(passNumber)"
            }
            
            if let ca = psd.colorAttachments[0] {
                ca.pixelFormat                 = self.pass[passNumber].bindings!.format
                ca.isBlendingEnabled           = false
                ca.sourceAlphaBlendFactor      = .sourceAlpha
                ca.sourceRGBBlendFactor        = .sourceAlpha
                ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                ca.destinationRGBBlendFactor   = .oneMinusSourceAlpha
            }

            psd.sampleCount = 1
            psd.vertexDescriptor = vd
            
            do {
                let lib = try device.makeLibrary(source: vsSrc, options: options)
                psd.vertexFunction = lib.makeFunction(name: "main0")
            }
            
            do {
                let lib = try device.makeLibrary(source: fsSrc, options: options)
                psd.fragmentFunction = lib.makeFunction(name: "main0")
            }
            
            self.pass[passNumber].state = try device.makeRenderPipelineState(descriptor: psd)
            
            for j in 0..<Constants.maxConstantBuffers {
                let sem = self.pass[passNumber].bindings!.buffers[j]
                
                let size = sem.size
                guard size > 0 else { continue }
                let opts: MTLResourceOptions = deviceHasUnifiedMemory ? .storageModeShared : .storageModeManaged
                let buf = device.makeBuffer(length: size, options: opts)
                self.pass[passNumber].buffers[j] = buf
                
                if let binding = sem.bindingVert {
                    self.pass[passNumber].vBuffers[binding] = buf
                }
                if let binding = sem.bindingFrag {
                    self.pass[passNumber].fBuffers[binding] = buf
                }
            }
        }
        
        // finalise remaining state
        historyCount = compiler.historyCount
        for binding in compiler.bindings {
            self.pass[binding.index].hasFeedback = binding.isFeedback
        }
        
        let end = CACurrentMediaTime() - start
        os_log("Shader compilation completed in %{xcode:interval}f seconds", log: .default, type: .debug, end)
        
        shader = ss
        loadLuts()
        renderTargetsNeedResize = true
        historyNeedsInit = true
    }
    
    private func loadLuts() {
        var opts: [MTKTextureLoader.Option: Any] = [
            .generateMipmaps: true,
            .allocateMipmaps: true,
            .SRGB: false,
            .textureStorageMode: MTLStorageMode.private.rawValue,
        ]
        
        // if the source texture exists and is flipped
        if sourceTexture != nil && sourceTextureIsFlipped {
            opts[.origin] = MTKTextureLoader.Origin.flippedVertically.rawValue
        }
        
        var i: Int = 0
        for lut in shader!.luts {
            let t: MTLTexture
            do {
                t = try loader.newTexture(URL: lut.url, options: opts)
            } catch {
                os_log("Unable to load LUT texture, using default. Path '%{public}@: %{public}@", log: .default, type: .error,
                       lut.url.absoluteString, error.localizedDescription)
                t = checkers
            }
            initTexture(&luts[i], withTexture: t)
            i+=1
        }
    }
    
    @objc public func setValue(_ value: CGFloat, forParameterName name: String) {
        if let index = parametersMap[name] {
            parameters[index] = Float(value)
        }
    }
    
    @objc public func setValue(_ value: CGFloat, forParameterIndex index: Int) {
        if case 0..<parametersCount = index {
            parameters[index] = Float(value)
        }
    }
    
    typealias SamplerWrapArray<Element> = [Element]
    typealias SamplerFilterArray<Element> = [SamplerWrapArray<Element>]
}

/*
 * Take the raw visible game rect and turn it into a smaller rect
 * which is centered inside 'bounds' and has aspect ratio 'aspectSize'.
 * ATM we try to fill the window, but maybe someday we'll support fixed zooms.
 */
func fitAspectRectIntoRect(aspectSize: CGSize, size: CGSize) -> CGRect {
    let wantAspect = aspectSize.width / aspectSize.height
    let viewAspect = size.width / size.height
    
    var minFactor: CGFloat
    var outRectSize: CGSize
    
    if viewAspect >= wantAspect {
        // Raw image is too wide (normal case), squish inwards
        minFactor   = wantAspect / viewAspect
        outRectSize = .init(width: size.width * minFactor, height: size.height)
    } else {
        // Raw image is too tall, squish upwards
        minFactor   = viewAspect / wantAspect
        outRectSize = .init(width: size.width, height: size.height * minFactor)
    }
    
    let outRect = CGRect(origin: .init(x: (size.width - outRectSize.width) / 2,
                                       y: (size.height - outRectSize.height) / 2),
                         size: outRectSize)
    
    // This is going into a Nearest Neighbor, so the edges should be on pixels!
    return NSIntegralRectWithOptions(outRect, .alignAllEdgesNearest)
}

extension FilterChain.SamplerWrapArray {
    subscript(x: ShaderPassWrap) -> Element {
        get { self[x.rawValue] }
        set { self[x.rawValue] = newValue }
    }
}

extension FilterChain.SamplerFilterArray {
    subscript(x: ShaderPassFilter) -> Element {
        get { self[x.rawValue] }
        set { self[x.rawValue] = newValue }
    }
}

extension FilterChain {
    fileprivate struct Float4 {
        static let zero: Self = .init()
        
        let x: Float
        let y: Float
        let z: Float
        let w: Float
        
        init() {
            x = 0
            y = 0
            z = 0
            w = 0
        }
        
        init(width w: Int, height h: Int) {
            self.init(width: CGFloat(w), height: CGFloat(h))
        }
        
        init(width w: CGFloat, height h: CGFloat) {
            let width = Float(w)
            let height = Float(h)
            self.x = width
            self.y = height
            self.z = 1 / width
            self.w = 1 / height
        }
    }
    
    fileprivate struct Texture {
        var view: MTLTexture?
        var size: Float4 = .zero
    }
}
