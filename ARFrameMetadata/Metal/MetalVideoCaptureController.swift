//
//  MTKViewController.swift
//  MetalShaderCamera
//

import UIKit
import Metal
import MetalKit
import OpenTok
import Accelerate
import simd

#if arch(i386) || arch(x86_64)
#else
    import MetalKit
#endif

/**
 * A `UIViewController` that allows quick and easy rendering of Metal textures. Currently only supports textures from single-plane pixel buffers, e.g. it can only render a single RGB texture and won't be able to render multiple YCbCr textures. Although this functionality can be added by overriding `MTKViewController`'s `willRenderTexture` method.
 */
class MetalVideoCaptureController: NSObject, OTVideoCapture {
    
    var session: MetalCameraSession?
    
    let view: UIView
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    var videoFrame = OTVideoFrame(format: OTVideoFormat(argbWithWidth: 0, height: 0))
    var capturing = false
    var width = 0
    var height = 0
    
    // MARK: - Public interface
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view. Please note that if you set this `var` too frequently some of the textures may not being drawn, as setting a texture does not force the view controller's view to render its content.
    open var texture: MTLTexture?
    
    /**
     This method is called prior rendering view's content. Use `inout` `texture` parameter to update the texture that is about to be drawn.
     
     - parameter texture:       Texture to be drawn
     - parameter commandBuffer: Command buffer that will be used for drawing
     - parameter device:        Metal device
     */
    open func willRenderTexture(_ texture: inout MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        /**
         * Override if neccessary
         */
    }
    
    /**
     This method is called after rendering view's content.
     
     - parameter texture:       Texture that was drawn
     - parameter commandBuffer: Command buffer we used for drawing
     - parameter device:        Metal device
     */
    open func didRenderTexture(_ texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        publishTexture(texture: texture)
    }

    // MARK: - Public overrides
    
    init(view: UIView) {
        self.view = view
        
        width = Int(view.frame.width * UIScreen.main.scale)
        height = Int(view.frame.height * UIScreen.main.scale)
    }
    
    // MARK: - OTVideoCapture protocol
    func initCapture() {
        
#if arch(i386) || arch(x86_64)
        NSLog("Failed creating a default system Metal device, since Metal is not available on iOS Simulator.")
#else
        assert(device != nil, "Failed creating a default system Metal device. Please, make sure Metal is available on your hardware.")
#endif
        initializeMetalView()
        initializeRenderPipelineState()
        
        session = MetalCameraSession(delegate: self)
    }
    
    private func initializeMetalView() {
#if arch(i386) || arch(x86_64)
#else
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.contentScaleFactor = UIScreen.main.scale
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(metalView, at: 0)
#endif
    }
    
    func releaseCapture() {
        
    }
    
    func start() -> Int32 {
        capturing = true
        session?.start()
        return 0
    }
    
    func stop() -> Int32 {
        capturing = false
        session?.stop()
        return 0
    }
    
    func isCaptureStarted() -> Bool {
        return capturing
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .ARGB
        videoFormat.imageHeight = UInt32(height)
        videoFormat.imageWidth = UInt32(width)
        return 0
    }

#if arch(i386) || arch(x86_64)
#else
    /// `UIViewController`'s view
    internal var metalView: MTKView!
#endif

    internal var device = MTLCreateSystemDefaultDevice()
    lazy internal var commandQueue: MTLCommandQueue? = {
        return device?.makeCommandQueue()
    }()
    internal var renderPipelineState: MTLRenderPipelineState?
    internal var renderPipelineStateTriangle: MTLRenderPipelineState?
    private let semaphore = DispatchSemaphore(value: 1)

    private func initializeRenderPipelineState() {
        guard
            let device = device,
            let library = device.makeDefaultLibrary()
        else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            try renderPipelineStateTriangle = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
    
    func pixelBuffer(forImage image: CGImage) -> CVPixelBuffer? {
        let frameSize = CGSize(width: image.width, height: image.height)
        
        var pixelBuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func publishTexture(texture: MTLTexture) {
        if let cgImage = texture.cgImage,
           let frameBuffer = pixelBuffer(forImage: cgImage) {
            let w = CVPixelBufferGetWidth(frameBuffer)
            let h = CVPixelBufferGetHeight(frameBuffer)
            
            CVPixelBufferLockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
            
            let time = CMTime(seconds: Double(mach_absolute_time()), preferredTimescale: 1000)
            var argbBuffer = vImage_Buffer(data: CVPixelBufferGetBaseAddressOfPlane(frameBuffer, 0)!,
                                           height: vImagePixelCount(h),
                                           width: vImagePixelCount(w),
                                           rowBytes: CVPixelBufferGetBytesPerRow(frameBuffer))
            var bgraPixelBuffer: CVPixelBuffer?
            _ = CVPixelBufferCreate(kCFAllocatorDefault,
                                    CVPixelBufferGetWidth(frameBuffer),
                                    CVPixelBufferGetHeight(frameBuffer),
                                    kCVPixelFormatType_32BGRA,
                                    nil,
                                    &bgraPixelBuffer)
            CVPixelBufferLockBaseAddress(bgraPixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            var bgraBuffer = vImage_Buffer(data: CVPixelBufferGetBaseAddressOfPlane(bgraPixelBuffer!, 0)!,
                                           height: vImagePixelCount(CVPixelBufferGetHeight(bgraPixelBuffer!)),
                                           width: vImagePixelCount(CVPixelBufferGetWidth(bgraPixelBuffer!)),
                                           rowBytes: CVPixelBufferGetBytesPerRow(bgraPixelBuffer!))
                        
            let map: [UInt8] = [3, 2, 1, 0]
            vImagePermuteChannels_ARGB8888(&argbBuffer, &bgraBuffer, map, 0)
            
            videoCaptureConsumer?.consumeImageBuffer(bgraPixelBuffer!, orientation: OTVideoOrientation.down, timestamp:time, metadata: nil)
            
            CVPixelBufferUnlockBaseAddress(bgraPixelBuffer! , CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        }
    }
}

#if arch(i386) || arch(x86_64)
#else

extension MetalVideoCaptureController: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }
    
    public func draw(in: MTKView) {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        autoreleasepool {
            guard
                var texture = texture,
                let device = device,
                let commandBuffer = commandQueue?.makeCommandBuffer()
            else {
                _ = semaphore.signal()
                return
            }

            willRenderTexture(&texture, withCommandBuffer: commandBuffer, device: device)
            render(texture: texture, withCommandBuffer: commandBuffer, device: device)
        }
    }
    
    private func render(texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard
            let currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let renderPipelineState = renderPipelineState,
            let renderPipelineStateTriangle = renderPipelineStateTriangle,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        else {
            semaphore.signal()
            return
        }
        
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        
        encoder.pushDebugGroup("RenderTriangle")
        encoder.setRenderPipelineState(renderPipelineState)
        let vertices = [Vertex(color: [1, 0, 0, 1], pos: [-1, -1]),
                        Vertex(color: [0, 1, 0, 1], pos: [0, 1]),
                        Vertex(color: [0, 0, 1, 1], pos: [1, -1])]
        currentRenderPassDescriptor.colorAttachments[0].texture = texture
        currentRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        currentRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        let viewport = MTLViewport(originX: Double(view.center.y), originY: Double(view.center.x), width: Double(200), height: Double(200), znear: 0.0, zfar: 1.0)
        encoder.setViewport(viewport)
        encoder.setRenderPipelineState(renderPipelineStateTriangle)
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.popDebugGroup()
        
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            guard let unwrappedSelf = self else { return }
            
            unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
            unwrappedSelf.semaphore.signal()
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

#endif

extension MetalVideoCaptureController: MetalCameraSessionDelegate {
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
    }
    
    func metalCameraSession(_ cameraSession: MetalCameraSession, didUpdateState state: MetalCameraSessionState, error: MetalCameraSessionError?) {
        
        if error == .captureSessionRuntimeError {
            cameraSession.start()
        }
        
        NSLog("Session changed state to \(state) with error: \(error?.localizedDescription ?? "None").")
    }
}
