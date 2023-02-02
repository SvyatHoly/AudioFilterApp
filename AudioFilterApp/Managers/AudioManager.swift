//
//  AudioManager.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import Foundation
import AVKit

final class AudioManager {
    
    static let shared = AudioManager()
    private let engine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let speedControl = AVAudioUnitVarispeed()
    private let pitchControl = AVAudioUnitTimePitch()
    private let distortionControl = AVAudioUnitDistortion()
    private let reverbControl = AVAudioUnitReverb()
    
    private var nodes: [AVAudioNode] { [audioPlayer, speedControl, pitchControl, distortionControl, reverbControl] }
    
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!

    private var audioFile: AVAudioFile?
    
    init() {
        self.nodes.forEach(self.engine.attach)
        var previousNode = self.nodes.first!
        var engineNodes = self.nodes
        engineNodes.append(self.engine.mainMixerNode)
        engineNodes.removeFirst()
        var iterator = engineNodes.makeIterator()
        while let next = iterator.next() {
            self.engine.connect(previousNode, to: next, format: self.format)
            previousNode = next
        }
    }
    
    func play(url: URL) {
        audioFile = try? AVAudioFile(forReading: url)
        
        self.audioPlayer.scheduleFile(self.audioFile!, at: nil)
        
        self.engine.prepare()
        try? self.engine.start()
        self.audioPlayer.play()
        
    }
    
    func repeatLoop() {
        guard let audioFile = audioFile else { return }
        self.audioPlayer.scheduleFile(audioFile, at: nil)
        self.audioPlayer.play()
    }
    
    func renderManually() async -> URL? {
        guard
            let audioFile = self.audioFile,
            let resultFile: AVAudioFile = try? AVAudioFile(
                forWriting: URL.temporary(fileName: "audio.m4a"),
                settings: format.settings
            )
        else {
            return nil
        }
        self.audioPlayer.stop()
        self.engine.stop()
        
        let result = Task.detached(priority: .userInitiated) { () -> URL? in
            do {
                
                self.audioPlayer.scheduleFile(self.audioFile!, at: nil)
                
                try self.engine.enableManualRenderingMode(.offline, format: self.format, maximumFrameCount: 4096)
                
                self.engine.prepare()
                try self.engine.start()
                self.audioPlayer.play()
                
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: self.engine.manualRenderingFormat,
                    frameCapacity: self.engine.manualRenderingMaximumFrameCount
                )!
                
                while self.engine.manualRenderingSampleTime < audioFile.length {
                    let framesToRender = min(AVAudioFrameCount(audioFile.length - self.engine.manualRenderingSampleTime), buffer.frameCapacity)
                    
                    switch try self.engine.renderOffline(framesToRender, to: buffer) {
                    case .success:
                        try resultFile.write(from: buffer)
                    default:
                        break
                    }
                }
                
                self.audioPlayer.stop()
                self.engine.stop()
                self.engine.disableManualRenderingMode()
                return resultFile.url
            } catch {
                print(error)
            }
            return nil
        }
        return await result.value
    }
    
    func stop() {
        self.engine.mainMixerNode.removeTap(onBus: 0)
        self.engine.stop()
        self.audioPlayer.stop()
    }
    
    func apply(preset: FilterPreset) {
        self.pitchControl.pitch = preset.pitch
        self.speedControl.rate = preset.speed
        self.reverbControl.wetDryMix = preset.reverberation
        self.distortionControl.preGain = preset.distortion.value
        self.distortionControl.wetDryMix = preset.distortion.mix
    }
}
