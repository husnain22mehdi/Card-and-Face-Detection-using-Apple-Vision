import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var faceLayers = [CAShapeLayer]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    // Called for each camera frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }
            DispatchQueue.main.async {
                self?.drawFaceBoxes(faces: results)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
    
    private func drawFaceBoxes(faces: [VNFaceObservation]) {
        // Remove previous boxes
        faceLayers.forEach { $0.removeFromSuperlayer() }
        faceLayers.removeAll()
        
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        
        for face in faces {
            let boundingBox = face.boundingBox
            let x = boundingBox.origin.x * viewWidth
            let y = (1 - boundingBox.origin.y - boundingBox.height) * viewHeight
            let width = boundingBox.width * viewWidth
            let height = boundingBox.height * viewHeight
            
            let faceRect = CGRect(x: x, y: y, width: width, height: height)
            
            let boxLayer = CAShapeLayer()
            boxLayer.frame = faceRect
            boxLayer.borderColor = UIColor.red.cgColor
            boxLayer.borderWidth = 2
            view.layer.addSublayer(boxLayer)
            
            faceLayers.append(boxLayer)
        }
    }
}
