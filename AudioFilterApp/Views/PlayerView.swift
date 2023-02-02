//
//  PlayerView.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import Foundation
import SwiftUI
import AVFoundation

struct PlayerView: UIViewRepresentable {
    
    private let player: PlayerUIView
    
    init(avPlayer: AVPlayer) {
        player = PlayerUIView(frame: .zero, avPlayer: avPlayer)
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
    }
    
    func makeUIView(context: Context) -> UIView {
        return player
    }
}

class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    init(frame: CGRect, avPlayer: AVPlayer) {
        super.init(frame: frame)
        playerLayer.player = avPlayer
        layer.addSublayer(playerLayer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
