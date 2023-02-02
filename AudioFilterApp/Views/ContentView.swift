//
//  ContentView.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import SwiftUI
import PhotosUI
import AVKit

struct ContentView: View {
    @StateObject private var model = ContentViewModel()
    @State private var isShareSheetPresented = false
    
    var body: some View {
        GeometryReader { gr in
            ZStack(alignment: .top) {
                switch model.viewState {
                case .waitingForRecording:
                    FrameView(image: model.frame)
                        .edgesIgnoringSafeArea(.all)
                case .video:
                    PlayerView(avPlayer: model.player)
                        .frame(width: gr.size.width, height: gr.size.width * (1920 / 1080))
                        .ignoresSafeArea()
                    HStack {
                        Button(action: {
                            model.viewState = .waitingForRecording
                        }, label: {
                            Image(systemName: "multiply")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                        })
                        .padding()
                        Spacer()
                        Button(action: {
                            Task {
                                await model.renderVideo()
                            }
                        }, label: {
                            Image(systemName: "square.and.arrow.up")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                        })
                        .padding()
                        
                    }
                case .loading:
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                case .error: ErrorView(error: model.error)
                default: EmptyView()
                }
                
                VStack(alignment: .customCenter) {
                    Spacer()
                        .frame(maxWidth: .infinity)
                    switch model.viewState {
                    case .video: effects()
                    case .waitingForRecording: recording()
                    default: EmptyView()
                    }
                }
            }
        }
        .sheet(isPresented: $isShareSheetPresented, onDismiss: {
            model.viewState = .waitingForRecording
        }) {
            ShareSheetView(activityItems: [{ () -> URL? in
                if case .share(let url) = model.viewState {
                    return url
                }
                return nil
            }() as Any])
        }
        .onReceive(model.$viewState) { state in
            switch state {
            case .share: isShareSheetPresented = true
            default: return
            }
        }
    }
    
    @ViewBuilder func recording() -> some View {
        HStack() {
            Button(action: {
                model.isRecording.toggle()
            }, label: {
                Circle()
                    .foregroundColor(.red)
                    .frame(width: 100)
            })
            .alignmentGuide(.customCenter) {
                $0[HorizontalAlignment.center]
            }
            PhotosPicker(selection: $model.imageSelection,
                         matching: .videos,
                         photoLibrary: .shared()) {
                Image(systemName: "plus.square.on.square")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
            }
                         .padding(.leading, 50)
        }
    }
    
    @ViewBuilder func effects() -> some View {
        LazyVGrid(columns: Array(repeating: .init(.fixed(80)), count: 3)) {
            ForEach(model.filterPresets) { item in
                Button(action: {
                    model.currentPreset = item
                }, label: {
                    Text(item.name)
                })
                .frame(width: 80, height: 50)
                .background(RoundedRectangle(cornerSize: .init(width: 20, height: 20), style: .continuous)
                    .fill(Color(uiColor: model.currentPreset == item
                                ? .green
                                : .lightGray
                               ).opacity(20)))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CustomCenter: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[HorizontalAlignment.center]
    }
}
extension HorizontalAlignment {
    static let customCenter: HorizontalAlignment = .init(CustomCenter.self)
}

struct ShareSheetView: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
}
