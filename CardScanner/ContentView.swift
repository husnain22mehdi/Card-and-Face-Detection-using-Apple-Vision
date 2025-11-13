//
//  ContentView.swift
//  CardScanner
//
//  Created by Husnain on 10/11/2025.
//

import SwiftUI
import Vision
import ImageIO

enum userSelection {
    case scanCard
    case scanFaceFromImg
    case scanFaceLive
}

struct ContentView: View {
    
    @State private var showingCardScanner = false
    @State private var showingFaceDetector = false
    @State private var showingFaceDetectionFromImg = false
    @State private var showingImagePicker = false
    @State private var showingLiveFaceDetection = false
    @State private var inputFaceImage : UIImage?
    @State private var detectedFaces : [VNFaceObservation] = []
    @State private var cardImgaqe : UIImage?
    @State private var navigationTitle = "Find Card"
//    @State private var originalImage : UIImage?
    
    @State private var userSelection : userSelection?
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 20) {
                
                
                if let img = cardImgaqe ?? UIImage(systemName: "photo")
                //               let originalImg = originalImage
                {
                    //                Image(uiImage: originalImg)
                    //                    .resizable()
                    //                    .scaledToFit()
                    //                    .frame(maxHeight: 300)
                    //                    .background(Color(.systemGray2))
                    //                    .border(Color.white)
                    
                    GeometryReader{ geometry in
                        ZStack{
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
//                                .frame(maxHeight: 300)
                                .background(Color(.systemGray2))
                                .border(Color.white)
                            
                            if userSelection == .scanFaceFromImg{
                                ForEach(detectedFaces, id: \.uuid) { face in
                                    let boundingBox = face.boundingBox
                                    let x = boundingBox.origin.x * geometry.size.width
                                    let y = (1 - boundingBox.origin.y - boundingBox.height) * geometry.size.height
                                    let width = boundingBox.width * geometry.size.width
                                    let height = boundingBox.height * geometry.size.height
                                    
                                    Rectangle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .frame(width: width, height: height)
                                        .position(x: x + width/2, y: y + height/2)
                                }
                            }
                        }
                    }
                    .frame(height: 400)
                }
                Button("Scan Card"){
                    showingCardScanner = true
                }
                 
                Button("Scan Face"){
                    showingFaceDetector = true
                }
                .actionSheet(isPresented: $showingFaceDetector){
                    let sheetButtons : [ActionSheet.Button] = [
                        .default(Text("From Image")) {showingImagePicker = true
                            userSelection = .scanFaceFromImg
                        },
                        .default(Text("Live Face Detection")) {showingLiveFaceDetection = true},
                        .cancel()
                    ]
                    return ActionSheet(title: Text(""), message: nil, buttons: sheetButtons)
                }
            }
            
            //showing card scanner view
            .sheet(isPresented: $showingCardScanner){
                //            CardScannerView(onSuccess: { croppedImg, originalImg in
                //                self.cardImgaqe = croppedImg
                //                self.originalImage = originalImg
                //            }, onCancel: {})
                CardScannerView(onSuccess: { img, title in
                    self.cardImgaqe = img
                    self.navigationTitle = title
                }, onCancel: {})
            }
            
            //showing image picker
            .sheet(isPresented: $showingImagePicker){
//                ImagePicker(image: $inputFaceImage) { selectedImg in
//                    self.inputFaceImage = selectedImg
//                    self.showingImagePicker = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
//                        self.showingFaceDetectionFromImg = true
//                    }
//                }
                
                ImagePicker(image: $cardImgaqe, completion: detectFaces)
            }
            
            //showing face detector view
            .sheet(isPresented: $showingLiveFaceDetection){
                LiveFaceDetectionView()
            }
            
            .navigationTitle(navigationTitle)
        }
    }
    
    // 3️⃣ Vision face detection
    func detectFaces(_ image: UIImage) {
        let fixedImage = image.fixedOrientation()
        guard let cgImage = fixedImage.cgImage else { return }
        
        let request = VNDetectFaceRectanglesRequest { request, error in
            if let results = request.results as? [VNFaceObservation] {
                DispatchQueue.main.async {
                    self.detectedFaces = results
                }
            }
        }
        
        //passing correct orientation of image
        let orientation = CGImagePropertyOrientation(fixedImage.imageOrientation)
        
        let handler = VNImageRequestHandler(cgImage: cgImage,orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform face detection: \(error)")
            }
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {return self}
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up : self = .up
        case .down : self = .down
        case .left : self = .left
        case .right : self = .right
        case .upMirrored : self = .upMirrored
        case .downMirrored : self = .downMirrored
        case .leftMirrored : self = .leftMirrored
        case .rightMirrored : self =  .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
