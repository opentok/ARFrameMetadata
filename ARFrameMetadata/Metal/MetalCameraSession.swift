//
//  MetalCameraSession.swift
//  MetalShaderCamera
//

import AVFoundation
import Metal

public protocol MetalCameraSessionDelegate {
    /**
     Camera session did receive a new frame and converted it to an array of Metal textures. For instance, if the RGB pixel format was selected, the array will have a single texture, whereas if YCbCr was selected, then there will be two textures: the Y texture at index 0, and CbCr texture at index 1 (following the order in a sample buffer).
     
     - parameter session:                   Session that triggered the update
     - parameter didReceiveFrameAsTextures: Frame converted to an array of Metal textures
     - parameter withTimestamp:             Frame timestamp in seconds
     */
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures: [MTLTexture], withTimestamp: Double)
    
    /**
     Camera session did update capture state
     
     - parameter session:        Session that triggered the update
     - parameter didUpdateState: Capture session state
     - parameter error:          Capture session error or `nil`
     */
    func metalCameraSession(_ session: MetalCameraSession, didUpdateState: MetalCameraSessionState, error: MetalCameraSessionError?)
}

public final class MetalCameraSession: NSObject {
    
    public var frameOrientation: AVCaptureVideoOrientation? {
        didSet {
            guard
                let frameOrientation = frameOrientation,
                let outputData = outputData,
                let videoConnection = outputData.connection(with: .video),
                videoConnection.isVideoOrientationSupported
            else { return }

            videoConnection.videoOrientation = frameOrientation
        }
    }
    
    public let captureDevicePosition: AVCaptureDevice.Position
    public var delegate: MetalCameraSessionDelegate?
    public let pixelFormat: MetalCameraPixelFormat
    
    public init(pixelFormat: MetalCameraPixelFormat = .rgb, captureDevicePosition: AVCaptureDevice.Position = .back, delegate: MetalCameraSessionDelegate? = nil) {
        self.pixelFormat = pixelFormat
        self.captureDevicePosition = captureDevicePosition
        self.delegate = delegate
        super.init();

        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil)
    }
    
    public func start() {
        requestCameraAccess()

        captureSessionQueue.async(execute: {
            do {
                self.captureSession.beginConfiguration()
                try self.initializeInputDevice()
                try self.initializeOutputData()
                self.captureSession.commitConfiguration()
                try self.initializeTextureCache()
                self.captureSession.startRunning()
                self.state = .streaming
            }
            catch let error as MetalCameraSessionError {
                self.handleError(error)
            }
            catch {
                /**
                 * We only throw `MetalCameraSessionError` errors.
                 */
            }
        })
    }
    
    public func stop() {
        captureSessionQueue.async(execute: {
            self.captureSession.stopRunning()
            self.state = .stopped
        })
    }
    
    private var state: MetalCameraSessionState = .waiting {
        didSet {
            guard state != .error else { return }
            
            delegate?.metalCameraSession(self, didUpdateState: state, error: nil)
        }
    }

    private var captureSession = AVCaptureSession()
    internal var captureDevice = MetalCameraCaptureDevice()
    private var captureSessionQueue = DispatchQueue(label: "MetalCameraSessionQueue", attributes: [])

#if arch(i386) || arch(x86_64)
#else
    internal var textureCache: CVMetalTextureCache?
#endif

    private var metalDevice = MTLCreateSystemDefaultDevice()
    internal var inputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeInput(oldValue)
            }

            guard let inputDevice = inputDevice else { return }

            captureSession.addInput(inputDevice)
        }
    }
    
    internal var outputData: AVCaptureVideoDataOutput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeOutput(oldValue)
            }

            guard let outputData = outputData else { return }
            
            captureSession.addOutput(outputData)
        }
    }

    private func requestCameraAccess() {
        captureDevice.requestAccess(for: .video) {
            (granted: Bool) -> Void in
            guard granted else {
                self.handleError(.noHardwareAccess)
                return
            }
            
            if self.state != .streaming && self.state != .error {
                self.state = .ready
            }
        }
    }
    
    private func handleError(_ error: MetalCameraSessionError) {
        if error.isStreamingError() {
            state = .error
        }

        delegate?.metalCameraSession(self, didUpdateState: state, error: error)
    }

    private func initializeTextureCache() throws {
#if arch(i386) || arch(x86_64)
        throw MetalCameraSessionError.failedToCreateTextureCache
#else
        guard
            let metalDevice = metalDevice,
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
#endif
    }

    private func initializeInputDevice() throws {
        var captureInput: AVCaptureDeviceInput!

        guard let inputDevice = captureDevice.device(for: .video, with: captureDevicePosition) else {
            throw MetalCameraSessionError.requestedHardwareNotFound
        }

        do {
            captureInput = try AVCaptureDeviceInput(device: inputDevice)
        }
        catch {
            throw MetalCameraSessionError.inputDeviceNotAvailable
        }
        
        guard captureSession.canAddInput(captureInput) else {
            throw MetalCameraSessionError.failedToAddCaptureInputDevice
        }
        
        self.inputDevice = captureInput
    }
    
    private func initializeOutputData() throws {
        let outputData = AVCaptureVideoDataOutput()

        outputData.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat.coreVideoType)
        ]
        outputData.alwaysDiscardsLateVideoFrames = true
        outputData.setSampleBufferDelegate(self, queue: captureSessionQueue)
        
        guard captureSession.canAddOutput(outputData) else {
            throw MetalCameraSessionError.failedToAddCaptureOutput
        }
        
        self.outputData = outputData
    }
    
    @objc private func captureSessionRuntimeError() {
        if state == .streaming {
            handleError(.captureSessionRuntimeError)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MetalCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

#if arch(i386) || arch(x86_64)
#else

    private func texture(sampleBuffer: CMSampleBuffer?, textureCache: CVMetalTextureCache?, planeIndex: Int = 0, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> MTLTexture {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.missingSampleBuffer
        }
        guard let textureCache = textureCache else {
            throw MetalCameraSessionError.failedToCreateTextureCache
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw MetalCameraSessionError.failedToGetImageBuffer
        }
        
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetWidth(imageBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetHeight(imageBuffer)
        
        var imageTexture: CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, pixelFormat, width, height, planeIndex, &imageTexture)
        
        guard
            let unwrappedImageTexture = imageTexture,
            let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
            result == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.failedToCreateTextureFromImage
        }

        return texture
    }
    
    private func timestamp(sampleBuffer: CMSampleBuffer?) throws -> Double {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.missingSampleBuffer
        }
        
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        guard time != kCMTimeInvalid else {
            throw MetalCameraSessionError.failedToRetrieveTimestamp
        }
        
        return (Double)(time.value) / (Double)(time.timescale);
    }
    
    public func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        do {
            var textures: [MTLTexture]!
            
            switch pixelFormat {
            case .rgb:
                let textureRGB = try texture(sampleBuffer: sampleBuffer, textureCache: textureCache)
                textures = [textureRGB]
            case .yCbCr:
                let textureY = try texture(sampleBuffer: sampleBuffer, textureCache: textureCache, planeIndex: 0, pixelFormat: .r8Unorm)
                let textureCbCr = try texture(sampleBuffer: sampleBuffer, textureCache: textureCache, planeIndex: 1, pixelFormat: .rg8Unorm)
                textures = [textureY, textureCbCr]
            }
            
            let timestamp = try self.timestamp(sampleBuffer: sampleBuffer)
            
            delegate?.metalCameraSession(self, didReceiveFrameAsTextures: textures, withTimestamp: timestamp)
        }
        catch let error as MetalCameraSessionError {
            self.handleError(error)
        }
        catch {
            
        }
    }

#endif
    
}
