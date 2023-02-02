//
//  Extensions.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import CoreGraphics
import VideoToolbox

extension AVAsset {
    enum ErrorKind: Error {
        case trackTypeNotFound
    }
    
    func firstTrack(with type: AVMediaType) throws -> AVAssetTrack {
        guard let track = self.tracks(withMediaType: type).first else {
            throw ErrorKind.trackTypeNotFound
        }
        
        return track
    }
    
    var audioComposition: AVMutableComposition {
        get throws {
            let composition = AVMutableComposition()
            let firstAudioTrack = try self.firstTrack(with: .audio)
            try composition.apply(assetTrack: firstAudioTrack, with: .audio, in: range)
            return composition
        }
    }
    
    var videoComposition: AVMutableComposition {
        get throws {
            let composition = AVMutableComposition()
            let firstVideoTrack = try self.firstTrack(with: .video)
            try composition.apply(assetTrack: firstVideoTrack, with: .video, in: range)
            return composition
        }
    }
    
    var range: CMTimeRange {
        CMTimeRange(start: .zero, duration: self.duration)
    }
}

extension AVMutableComposition {
    func apply(assetTrack: AVAssetTrack, with type: AVMediaType, in range: CMTimeRange) throws {
        let track = self.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)
        try track?.insertTimeRange(range, of: assetTrack, at: .zero)
        track?.preferredTransform = assetTrack.preferredTransform
    }
}

extension PhotosPickerItem {
    func loadPhoto() async throws -> Any {
        if let livePhoto = try await self.loadTransferable(type: PHLivePhoto.self) {
            return livePhoto
        } else if let movie = try await self.loadTransferable(type: Movie.self) {
            return movie.url
        } else {
            fatalError()
        }
    }
}

extension Publisher {
    func asyncMap<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    let output = await transform(value)
                    promise(.success(output))
                }
            }
        }
    }
}

extension URL {
    static func temporary(fileName: String) -> URL {
        Self(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }
}

extension CGImage {
    static func create(from cvPixelBuffer: CVPixelBuffer?) -> CGImage? {
        guard let pixelBuffer = cvPixelBuffer else {
            return nil
        }
        
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(
            pixelBuffer,
            options: nil,
            imageOut: &image)
        return image
    }
}

struct Movie: Transferable {
  let url: URL
  
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { movie in
      SentTransferredFile(movie.url)
    } importing: { receivedData in
      let fileName = receivedData.file.lastPathComponent
      let copy: URL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
      
      if FileManager.default.fileExists(atPath: copy.path) {
        try FileManager.default.removeItem(at: copy)
      }
      
      try FileManager.default.copyItem(at: receivedData.file, to: copy)
      return .init(url: copy)
    }
  }
}
