//
//  AROpentokVideoCapturer.swift
//  ARFrameMetadata
//
//  Created by Roberto Perez Cubero on 24/05/2018.
//  Copyright © 2018 tokbox. All rights reserved.
//

import Foundation
import OpenTok
import ARKit

class AROpentokVideoCapturer : NSObject, OTVideoCapture, ARSessionDelegate {
    var captureStarted = false
    var videoCaptureConsumer: OTVideoCaptureConsumer?
    fileprivate let videoFrame: OTVideoFrame
    var frameW: UInt32 = 0
    var frameH: UInt32 = 0
    
    override init() {
        videoFrame = OTVideoFrame(format: OTVideoFormat(nv12WithWidth: frameW, height: frameH))
    }
    
    func initCapture() {
    }
    
    func releaseCapture() {
    }
    
    func start() -> Int32 {
        captureStarted = true
        return 0
    }
    
    func stop() -> Int32 {
        captureStarted = false
        return 0
    }
    
    func isCaptureStarted() -> Bool {
        return captureStarted
    }
    
    func captureSettings(_ videoFormat: OTVideoFormat) -> Int32 {
        videoFormat.pixelFormat = .NV12
        videoFormat.imageHeight = frameH
        videoFormat.imageWidth = frameW
        
        return 0
    }
    
    fileprivate func updateCaptureFormat(width w: UInt32, height h: UInt32) {
        frameW = w
        frameH = h
        videoFrame.format = OTVideoFormat.init(nv12WithWidth: w, height: h)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !captureStarted {
            return
        }
        
        let frameBuffer = frame.capturedImage
        let w = UInt32(CVPixelBufferGetWidth(frameBuffer))
        let h = UInt32(CVPixelBufferGetHeight(frameBuffer))
        
        if w != frameW || h != frameH {
            updateCaptureFormat(width: w, height: h)
        }
        
        CVPixelBufferLockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        
        videoFrame.orientation = UIApplication.shared
            .currentDeviceOrientation(cameraPosition: .back)
        videoFrame.clearPlanes()
        if !CVPixelBufferIsPlanar(frameBuffer) {
            videoFrame.planes?.addPointer(CVPixelBufferGetBaseAddress(frameBuffer))
        } else {
            for idx in 0..<CVPixelBufferGetPlaneCount(frameBuffer) {
                videoFrame.planes?.addPointer(CVPixelBufferGetBaseAddressOfPlane(frameBuffer, idx))
            }
        }
        
        let data = Data(fromArray: [
            frame.camera.transform.position().x,
            frame.camera.transform.position().y,
            frame.camera.transform.position().z,
            frame.camera.eulerAngles.x,
            frame.camera.eulerAngles.y,
            frame.camera.eulerAngles.z
        ])
        
        var err: OTError?
        videoFrame.setMetadata(data, error: &err)
        if let e = err {
            print("Error adding frame metadata: \(e.localizedDescription)")
        }
    
        videoCaptureConsumer!.consumeFrame(videoFrame)
        
        CVPixelBufferUnlockBaseAddress(frameBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
    }
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension UIApplication {
    func currentDeviceOrientation(cameraPosition pos: AVCaptureDevice.Position) -> OTVideoOrientation {
        let orientation = statusBarOrientation
        if pos == .front {
            switch orientation {
            case .landscapeLeft: return .up
            case .landscapeRight: return .down
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            }
        } else {
            switch orientation {
            case .landscapeLeft: return .down
            case .landscapeRight: return .up
            case .portrait: return .left
            case .portraitUpsideDown: return .right
            case .unknown: return .up
            }
        }
    }
}
