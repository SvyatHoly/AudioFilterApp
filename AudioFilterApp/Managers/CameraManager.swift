//
//  CameraManager.swift
//  AudioFilterApp
//
//  Created by Sviatoslav Ivanov on 2/2/23.
//

import AVFoundation

class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    enum Output {
        case recordingFinished(url: URL)
        case error(error: CameraError?)
    }
    
    static let shared = CameraManager()
    
    @Published var output: Output?
    
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.arma.SessionQ")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var status = Status.unconfigured
    private let movieOutput = AVCaptureMovieFileOutput()
    
    private override init() {
        super.init()
        configure()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("recording finished")
        self.output = .recordingFinished(url: outputFileURL)
    }
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.output = .error(error: error)
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .audio) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configureCaptureSession() {
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        
        defer {
            session.commitConfiguration()
        }
        
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front)
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        guard
            let micDeviceInput = try? AVCaptureDeviceInput(device: .default(for: .audio)!),
            session.canAddInput(micDeviceInput) else {
            return
        }
        session.addInput(micDeviceInput)
        
        guard session.canAddOutput(movieOutput) else {
            return
        }
        session.addOutput(movieOutput)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
            
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        status = .configured
    }
    
    private func configure() {
        checkPermissions()
        
        sessionQueue.async {
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
    func set(
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
    func startRecording() {
        movieOutput.connection(with: .video)?.isVideoMirrored = true
        movieOutput.startRecording(to: .temporary(fileName: "recorded.mov"), recordingDelegate: self)
    }
    
    func stopRecording() {
        movieOutput.stopRecording()
    }
}
