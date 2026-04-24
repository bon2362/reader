import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

enum ImageDataTransformer {
    static func normalizedPNGData(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source),
              let uti = UTType(type as String),
              uti.conforms(to: .image),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return pngData(from: image)
    }

    #if canImport(AppKit) || canImport(UIKit)
    static func pngData(from image: PlatformImage) -> Data? {
        #if canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
        #else
        return image.pngData()
        #endif
    }
    #endif

    static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
