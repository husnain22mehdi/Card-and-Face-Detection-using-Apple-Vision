import SwiftUI
import Vision
import VisionKit

struct CardScannerView: UIViewControllerRepresentable {
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: CardScannerView
        
        init(parent: CardScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            
            // Take first page (or iterate through all if needed)
            let image = scan.imageOfPage(at: 0)
            
            controller.dismiss(animated: true)
//            parent.detectCard(in: image)
//            parent.onSuccess(image, image)
            
            // Validate card
            parent.validateCard(image: image) { isValid in
                    if isValid {
                        self.parent.onSuccess(image, "Card Found") // cropped == original
                    } else {
                        // show error UI later
                        self.parent.onSuccess(UIImage(systemName: "person")!, "Invalid Card") // return original but no card result
                    }
                }
        }
    }
    
//    var onSuccess: (_ croppedImg : UIImage, _ originalImg: UIImage) -> Void
    var onSuccess: (_ image: UIImage, _ title: String) -> Void
    var onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<CardScannerView>) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController,
                                context: UIViewControllerRepresentableContext<CardScannerView>) {}
    
    
    //Implementation for VNDocumentCameraViewControoler
    
    func validateCard(image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(false)
            return
        }

        // 1. Check Aspect Ratio (ID-1 standard: 85.60 × 53.98 mm)
        let aspect = image.size.width / image.size.height
        print(aspect)
        if !(aspect > 1.4 && aspect < 1.8) {
            print("failing here @ 1")
            completion(false)
            return
        }

        // 2. Check for text presence using Vision
        let request = VNRecognizeTextRequest { request, error in
            if let results = request.results as? [VNRecognizedTextObservation],
               results.count > 0 { // you may tune this threshold
                completion(true) // text detected → likely a real card
                print(results.count)
            } else {
                completion(false)
            }
        }
        request.recognitionLevel = .fast

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    
    
    
    //Implementaion for DataScannerViewController (>ios16)
    
    /*
    // MARK: Card Detection
    func detectCard(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let card = results.first else {
                onSuccess(image, image) // Fall back to original
                return
            }
            
            let debugImage = drawBoundingBox(on: image, using: card)
            
            print(results)
            print(card)
            let cropped = self.crop(rectangle: card, from: cgImage)
            onSuccess(cropped ?? image, debugImage)
        }
        
        // Tune these for card-like shapes
        request.minimumAspectRatio = 1.4
        request.maximumAspectRatio = 1.7
        request.minimumConfidence = 0.5
        request.quadratureTolerance = 30.0
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    // MARK: Crop Using Rectangle
    func crop(rectangle: VNRectangleObservation, from image: CGImage) -> UIImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        // Vision coordinates are normalized (0→1). Convert to image space.
        let boundingBox = rectangle.boundingBox
        let cropRect = CGRect(x: boundingBox.origin.x * width,
                              y: (1 - boundingBox.origin.y - boundingBox.height) * height,
                              width: boundingBox.width * width,
                              height: boundingBox.height * height)

        guard let croppedCGImage = image.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCGImage)
    }
    
    func drawBoundingBox(on image: UIImage, using observation: VNRectangleObservation) -> UIImage {
        let imageSize = CGSize(width: image.size.width, height: image.size.height)

        // Convert normalized Vision rect to UIKit coordinates
        let boundingBox = observation.boundingBox
        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        // Start graphics context
        UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Draw original image
        image.draw(in: CGRect(origin: .zero, size: imageSize))

        // Draw bounding box (red border)
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(10)
        context.stroke(rect)

        // Get composited image
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result ?? image
    }
     */
}


