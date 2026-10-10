import AVFoundation
import Cocoa
import ImageIO
import UniformTypeIdentifiers

/// Media conversion for imported scenery, using the system's own codecs.
final class SceneryBridge: SceneryApi {
  func convertToJpeg(inputPath: String, outputPath: String) throws {
    guard
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw PigeonError(code: "unreadable", message: "Can't read this image", details: nil) }
    try writeJpeg(image, to: outputPath)
  }

  func videoPoster(inputPath: String, outputPath: String) async throws {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: inputPath)))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1920, height: 1920)
    let (image, _) = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600))
    try writeJpeg(image, to: outputPath)
  }

  private func writeJpeg(_ image: CGImage, to path: String) throws {
    guard
      let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw PigeonError(code: "write", message: "Can't write \(path)", details: nil) }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
      throw PigeonError(code: "write", message: "Can't write \(path)", details: nil)
    }
  }
}
