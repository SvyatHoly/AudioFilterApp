//
//  ContentViewModel.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import PhotosUI
import CoreTransferable
import SwiftUI
import Combine

class ContentViewModel: NSObject, ObservableObject {

    @Published var error: Error?
    @Published var frame: CGImage?
    @Published var isShareSheetPresented = false
    
    var player = AVPlayer()

    private let cameraManager = CameraManager.shared
    private let frameManager = FrameManager.shared
    private let audioManager = AudioManager.shared
    private var export: AVAssetExportSession? = nil
    private var assetExporter = AssetExporter()
    private var mediaAsset: AVAsset?
    private var filteredMedia: AVMutableComposition?
    private var bag: Set<AnyCancellable> = .init()

    var filterPresets: [FilterPreset] = DefaultFilterPresets.allCases.map { $0.rawValue }
    var currentPreset: FilterPreset = DefaultFilterPresets.clear.rawValue {
        didSet {
            audioManager.apply(preset: currentPreset)
        }
    }
    
    var isRecording = false {
        didSet {
            switch isRecording {
            case true: startRecording()
            case false: stopRecording()
            }
        }
    }
    var videoURL: URL? {
        didSet {
            mediaAsset = AVAsset(url: videoURL!)
            try? process()
            
        }
    }
    
    enum ViewState: Equatable {
        case waitingForRecording
        case recording
        case video
        case loading
        case share(url: URL)
        case error(description: String)
    }
    
    @Published var viewState: ViewState = .waitingForRecording {
        didSet {
            if viewState == .waitingForRecording {
                player.replaceCurrentItem(with: nil)
                audioManager.stop()
                currentPreset = DefaultFilterPresets.clear.rawValue
            }
        }
    }
    
    @Published var imageSelection: PhotosPickerItem? = nil
    
    func loadVideo(imageSelection: PhotosPickerItem?) async {
        if let imageSelection {
            DispatchQueue.main.async { [weak self] in
                self?.viewState = .loading
            }
            videoURL = try? await imageSelection.loadPhoto() as? URL
            DispatchQueue.main.async { [weak self] in
                self?.viewState = .video
            }
        } else {
            viewState = .waitingForRecording
        }
    }
    
    override init() {
        super.init()
        setupSubscriptions()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [weak self] _ in
            if self?.viewState == .video {
                self?.player.seek(to: CMTime.zero)
                self?.player.play()
                self?.audioManager.repeatLoop()
            }
        }
    }
    
    func setupSubscriptions() {
        $imageSelection
            .asyncMap {item in
                await self.loadVideo(imageSelection: item)}
            .sink { _ in
            }
            .store(in: &bag)
        
        cameraManager.$output
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                switch value {
                case .recordingFinished(url: let url):
                    self?.videoURL = url
                    self?.viewState = .video
                case .error(let error): self?.error = error
                case .none:
                    return
                }
            }
            .store(in: &bag)
        
        frameManager.$current
            .receive(on: RunLoop.main)
            .compactMap { buffer in
                guard let image = CGImage.create(from: buffer) else {
                    return nil
                }
                return image
            }
            .assign(to: &$frame)
    }
    
    private func process() throws {
        guard let mediaAsset = mediaAsset else { return }
        let videoComposition = try mediaAsset.videoComposition
        let audioComposition = try mediaAsset.audioComposition
        
        self.assetExporter.export(
            asset: audioComposition,
            with: .init(
                url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audioTrack.m4a"),
                fileType: .m4a,
                preset: AVAssetExportPresetAppleM4A
            )
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let url = try result.get()
                    try self.play(video: videoComposition, audio: url)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    // MARK: - Playback
    
    private func play(video: AVMutableComposition, audio: URL) throws {
        try playVideo(asset: video)
        audioManager.stop()
        audioManager.play(url: audio)
    }
    
    private func playVideo(asset: AVAsset) throws {
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }
    
    func renderVideo() async {
        await MainActor.run {
            viewState = .loading
        }
        guard let audioURL = await audioManager.renderManually(),
              let url = await exportVideo(url: audioURL) else { return }
        await MainActor.run {
            viewState = .share(url: url)
            isShareSheetPresented = true
        }
    }
    
    func exportVideo(url: URL) async -> URL? {
        let asset = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        guard
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let videoAssetTrack = try? await player.currentItem?.asset.loadTracks(withMediaType: .video).first,
            let audioAssetTrack = try? await asset.loadTracks(withMediaType: .audio).first
                
        else {
            print("Something is wrong with the asset.")
            return nil
        }
        
        do {
            let timeRange = CMTimeRange(start: .zero, duration: player.currentItem?.asset.duration ?? .zero)
            try compositionTrack.insertTimeRange(timeRange, of: videoAssetTrack, at: .zero)
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: .zero)
        } catch {
            print(error)
            return nil
        }
        
        let videoSize = CGSize(
            width: 1080,
            height: 1920)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: composition.duration)
        videoComposition.instructions = [instruction]
        let layerInstruction = getInstruction(
            for: compositionTrack,
            assetTrack: videoAssetTrack)
        instruction.layerInstructions = [layerInstruction]
        
        export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1920x1080)
        
        
        let videoName = UUID().uuidString
        let exportURL = URL.documentsDirectory
            .appendingPathComponent(videoName)
            .appendingPathExtension("mov")
        
        export!.videoComposition = videoComposition
        export!.outputFileType = .mov
        export!.outputURL = exportURL
        
        await requestAuthorization()
        /// got permissions
        await export!.export()
        return export!.outputURL!
    }

    private func requestAuthorization() async {
        if #available(iOS 15, *) { /// works, so use `addOnly`
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { (status) in
                if status == .authorized || status == .limited {
                    return
                }
            }
        } else if #available(iOS 14, *) { /// use `readWrite` directly instead. This will ask for both read and write access, but at least it doesn't crash...
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { (status) in
                if status == .authorized || status == .limited {
                    return
                }
            }
        } else { /// for older iOS just do `requestAuthorization`
            PHPhotoLibrary.requestAuthorization { (status) in
                if status == .authorized {
                    return
                }
            }
        }
    }
    
    private func getInstruction(for track: AVCompositionTrack, assetTrack: AVAssetTrack) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        var transform = assetTrack.preferredTransform
        instruction.setTransform(transform, at: .zero)
        return instruction
    }
    
    func startRecording() {
        cameraManager.startRecording()
    }
    
    func stopRecording() {
        cameraManager.stopRecording()
    }
}
