//
//  FrameView.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    
    private let label = Text("Video feed")
    
    var body: some View {
        if let image = image {
            GeometryReader { geometry in
                Image(image, scale: 1.0, orientation: .upMirrored, label: label)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .top)
                    .clipped()
            }
        } else {
            GeometryReader { geometry in
                Color.black
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.width * (1920 / 1080),
                        alignment: .top)
            }
            .ignoresSafeArea()
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        FrameView(image: nil)
    }
}
