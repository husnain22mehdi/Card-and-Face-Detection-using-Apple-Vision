// LiveFaceDetectionView.swift
// Drop into your SwiftUI app

import SwiftUI
import AVFoundation
import Vision

// MARK: - SwiftUI View
struct LiveFaceDetectionView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack{
            VStack(spacing: 0){
                VStack{}
                    .frame(maxWidth: .infinity, maxHeight: 15)
                    .background(Color(.systemBackground))
                ZStack {
                    CameraPreviewView(session: camera.session, cameraController: camera)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        HStack {
                            Text("Faces: \(camera.faceCount)")
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            Spacer()
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .navigationTitle("Detecting Faces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel"){
                        dismiss()
                    }
                }
            }
        }
        
    }
}

// MARK: - CameraController (ObservableObject)
final class CameraController: NSObject, ObservableObject {
    // Public
    @Published fileprivate(set) var faceCount: Int = 0
    let session = AVCaptureSession()

    // Private
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var sequenceHandler = VNSequenceRequestHandler()
    fileprivate weak var previewView: CameraPreviewUIView?
    
    private var currentCameraPosition : AVCaptureDevice.Position?

    override init() {
        super.init()
        configureSession()
    }

    // MARK: Session lifecycle
    func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: Setup session
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        currentCameraPosition = .front

        // Camera device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }

            // Video output: for Vision processing
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.buffer.queue"))
            videoOutput.alwaysDiscardsLateVideoFrames = true

            // Use BGRA for faster conversions
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

            // Make sure video orientation is set on the connection
            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        } catch {
            print("Camera input error: \(error)")
        }

        session.commitConfiguration()
    }

    // Called by preview view to give a reference for drawing overlays
    fileprivate func setPreviewView(_ view: CameraPreviewUIView) {
        previewView = view
    }

    // Handle Vision results (normalized bounding boxes)
    private func handleFaces(_ observations: [VNFaceObservation]) {
        DispatchQueue.main.async {
            self.faceCount = observations.count
            let boxes = observations.map { $0.boundingBox } // normalized rects (origin = bottom-left)
            self.previewView?.showFaceRects(normalizedRects: boxes)
        }
    }
    
    //handling device orientation
    func exifOrientationForCurrentDevice(position: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
        let deviceOrientation = UIDevice.current.orientation

        switch deviceOrientation {
        case .portrait:
            return position == .front ? .leftMirrored : .right
        case .portraitUpsideDown:
            return position == .front ? .rightMirrored : .left
        case .landscapeLeft: // phone tilted left
            return position == .front ? .downMirrored : .up
        case .landscapeRight: // phone tilted right
            return position == .front ? .upMirrored : .down
        default:
            return .right // fallback
        }
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Convert sampleBuffer to CVPixelBuffer and run Vision
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Decide orientation for Vision based on device orientation and camera position:
        // Use .leftMirrored for front camera portrait for better alignment if you mirror the preview
        let exifOrientation = exifOrientationForCurrentDevice(position: currentCameraPosition ?? .front) // .right = portrait (AVFoundation default)
        // You can adapt orientation logic for device orientation if you want.

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let err = error {
                print("Vision error: \(err.localizedDescription)")
                return
            }
            guard let faceObs = request.results as? [VNFaceObservation] else {
                self?.handleFaces([])
                return
            }
            self?.handleFaces(faceObs)
        }

        // Perform request
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: exifOrientation)
        } catch {
            print("Vision perform error: \(error)")
        }
    }
}

// MARK: - CameraPreviewView (SwiftUI wrapper for UIView)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraController: CameraController

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        cameraController.setPreviewView(view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // nothing to update
    }
}

// MARK: - CameraPreviewUIView
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    // Keep drawn face layers so we can remove them between frames
    private var faceLayers = [CAShapeLayer]()

    // Called by CameraController on main thread
    func showFaceRects(normalizedRects: [CGRect]) {
        // Remove old layers
        faceLayers.forEach { $0.removeFromSuperlayer() }
        faceLayers.removeAll()

        guard !normalizedRects.isEmpty else { return }

        // For each normalized rect from Vision (origin at bottom-left), convert to layer rect
        for norm in normalizedRects {
            // Vision's normalized coordinates have origin bottom-left (0,0).
            // AVCaptureVideoPreviewLayer expects metadata output rects (origin top-left), but there's a helper to convert.
            // NOTE: layerRectConverted(fromMetadataOutputRect:) expects rects in metadata coordinates (origin top-left).
            // Convert Vision's bottom-left normalized rect to metadata (top-left) normalized rect:
            let metadataRect = CGRect(x: norm.origin.x,
                                      y: 1 - norm.origin.y - norm.height,
                                      width: norm.width,
                                      height: norm.height)

            // Convert to layer coordinates
            let converted = videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: metadataRect)

            // Create a CAShapeLayer
            let shape = CAShapeLayer()
            shape.frame = converted
            shape.borderWidth = 2.0
            shape.cornerRadius = 4.0
            shape.borderColor = UIColor.systemYellow.cgColor
            shape.backgroundColor = UIColor.clear.cgColor

            // Optionally add a label layer inside the box
            let textLayer = CATextLayer()
            textLayer.string = "Face"
            textLayer.fontSize = 12
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.contentsScale = UIScreen.main.scale
            let txtHeight: CGFloat = 16
            textLayer.frame = CGRect(x: 0, y: -txtHeight - 2, width: converted.width, height: txtHeight)
            shape.addSublayer(textLayer)

            self.layer.addSublayer(shape)
            faceLayers.append(shape)
        }
    }

    // Clean up when view goes away
    deinit {
        faceLayers.forEach { $0.removeFromSuperlayer() }
        faceLayers.removeAll()
    }
}
