//
//  AssetExporter.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import AVKit

final class AssetExporter {
    enum ErrorKind: Error {
        case failedToRemoveExisitingFile
        case failedToCreateExportSession
        case failedToExportFile
        case cancelled
        case unknown
    }
    
    struct Configuration {
        let url: URL
        let fileType: AVFileType
        let preset: String
    }
    
    func export(asset: AVAsset, with configuration: Configuration, completion: @escaping (Result<URL, Error>) -> Void) {
        if FileManager.default.fileExists(atPath: configuration.url.path) {
            do {
                try FileManager.default.removeItem(at: configuration.url)
            } catch {
                completion(.failure(ErrorKind.failedToRemoveExisitingFile))
                return
            }
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: configuration.preset) else {
            completion(.failure(ErrorKind.failedToCreateExportSession))
            return
        }
        
        exportSession.outputURL = configuration.url
        exportSession.outputFileType = configuration.fileType
        exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(configuration.url))
            case .cancelled:
                completion(.failure(ErrorKind.cancelled))
            case .failed:
                completion(.failure(ErrorKind.failedToExportFile))
            default:
                completion(.failure(ErrorKind.unknown))
            }
        }
    }
}
