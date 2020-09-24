//
//  Texture+.swift
//  ARFrameMetadata
//
//  Created by Jerónimo Valli on 9/23/20.
//  Copyright © 2020 tokbox. All rights reserved.
//

import Foundation
import CoreGraphics
import MetalKit
import GLKit
import Accelerate



extension MTLTexture {

    #if os(iOS)
    typealias XImage = UIImage
    #elseif os(macOS)
    typealias XImage = NSImage
    #endif

    var cgImage: CGImage? {

        assert(self.pixelFormat == .bgra8Unorm)
    
        let rowBytes = self.width * 4
        let length = rowBytes * self.height
        let bgraBytes = [UInt8](repeating: 0, count: length)
        let region = MTLRegionMake2D(0, 0, self.width, self.height)
        self.getBytes(UnsafeMutableRawPointer(mutating: bgraBytes), bytesPerRow: rowBytes, from: region, mipmapLevel: 0)

        var bgraBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: bgraBytes),
                    height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let rgbaBytes = [UInt8](repeating: 0, count: length)
        var rgbaBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: rgbaBytes),
                    height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)

        let flippedBytes = bgraBytes // share the buffer
        var flippedBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: flippedBytes),
                    height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        vImageVerticalReflect_ARGB8888(&rgbaBuffer, &flippedBuffer, 0)

        let colorScape = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = CFDataCreate(nil, flippedBytes, length) else { return nil }
        guard let dataProvider = CGDataProvider(data: data) else { return nil }
        let cgImage = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                    space: colorScape, bitmapInfo: bitmapInfo, provider: dataProvider,
                    decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        return cgImage
    }

    var image: XImage? {
        guard let cgImage = self.cgImage else { return nil }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
}
