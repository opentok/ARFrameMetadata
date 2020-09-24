//
//  MetalCameraCaptureDevice.swift
//  ARFrameMetadata
//
//  Created by Jerónimo Valli on 9/18/20.
//  Copyright © 2020 tokbox. All rights reserved.
//

import AVFoundation

internal class MetalCameraCaptureDevice {
    
    internal func device(for mediaType: AVMediaType, with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera]
        if #available(iOS 11.1, *) {
            deviceTypes.append(.builtInTrueDepthCamera)
        }
        if #available(iOS 13.0, *) {
            deviceTypes.append(contentsOf: [.builtInDualWideCamera, .builtInTripleCamera, .builtInUltraWideCamera])
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: mediaType, position: position)
        return discoverySession.devices.first
    }
    
    internal func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping ((Bool) -> Void)) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: handler)
    }
}
