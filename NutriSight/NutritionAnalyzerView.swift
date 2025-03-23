//
//  NutritionAnalyzerView.swift
//  NutriSight
//
//  Created by Swarasai Mulagari on 3/22/25.
//

import SwiftUI
import Vision
import VisionKit
import AVFoundation

struct NutritionAnalyzerView: View {
    @State private var showScanner = false
    @State private var analysisResult: NutritionAnalysis?
    @State private var isLoading = false
    @State private var capturedImage: UIImage?
    @StateObject private var speechSynthesizer = SpeechSynthesizer()

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("Nutrition Analyzer")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else if let analysis = analysisResult {
                    AnalysisResultView(
                        resultText: analysis.overallAssessment,
                        capturedImage: capturedImage ?? UIImage(),
                        healthScore: analysis.healthScore,
                        details: analysis.details
                    )
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.black)
                        .padding()
                    
                    Text("Scan a nutrition label to get started")
                        .font(.headline)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Button(action: {
                    showScanner = true
                }) {
                    Text("Scan Nutrition Label")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(20)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView(analysisResult: $analysisResult, isLoading: $isLoading, capturedImage: $capturedImage)
        }
        .onAppear {
            speechSynthesizer.speak("Welcome to the nutritional analyzer. Click the button below to scan a nutrition label.") {}

        }
    }
}



struct HealthScoreBar: View {
    let score: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 20)
                    .cornerRadius(10)

                Rectangle()
                    .fill(scoreColor)
                    .frame(width: CGFloat(score) / 5 * geometry.size.width, height: 20)
                    .cornerRadius(10)
            }
        }
        .frame(height: 20)
    }

    var scoreColor: Color {
        switch score {
        case 0...2: return .red
        case 3...4: return .yellow
        default: return .green
        }
    }
}

struct NutritionAnalysis {
    let details: [String]
    let overallAssessment: String
    let healthScore: Int
}

struct ScannerView: UIViewControllerRepresentable {
    @Binding var analysisResult: NutritionAnalysis?
    @Binding var isLoading: Bool
    @Binding var capturedImage: UIImage?

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: ScannerView
        private let speechSynthesizer = SpeechSynthesizer() // Retain the SpeechSynthesizer instance

        init(_ parent: ScannerView) {
                self.parent = parent
            }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
                guard scan.pageCount >= 1 else {
                    controller.dismiss(animated: true)
                    return
                }

                let image = scan.imageOfPage(at: 0)
                let textRecognizer = TextRecognizer()
                textRecognizer.recognizeText(from: image) { result in
                    DispatchQueue.main.async {
                        let analysis = self.analyzeNutrition(text: result)
                        self.parent.analysisResult = analysis

                        // Speak the results aloud
                        self.speechSynthesizer.speak("Analysis complete. " + analysis.overallAssessment) {
                            print("Speech finished")
                        }

                        controller.dismiss(animated: true)
                    }
                }
            }


        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
                controller.dismiss(animated: true)
            }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
                print("Failed to scan document: \(error.localizedDescription)")
                controller.dismiss(animated: true)
            }


        func analyzeNutrition(text: String) -> NutritionAnalysis {
            let lines = text.lowercased().components(separatedBy: .newlines)
            var fat = 0
            var cholesterol = 0
            var sodium = 0
            var carbs = 0
            var protein = 0

            for line in lines {
                if line.contains("fat") {
                    fat = extractNumber(from: line)
                } else if line.contains("cholesterol") {
                    cholesterol = extractNumber(from: line)
                } else if line.contains("sodium") {
                    sodium = extractNumber(from: line)
                } else if line.contains("carbohydrate") {
                    carbs = extractNumber(from: line)
                } else if line.contains("protein") {
                    protein = extractNumber(from: line)
                }
            }

            return generateAnalysis(fat: fat, cholesterol: cholesterol, sodium: sodium, carbs: carbs, protein: protein)
        }

        func extractNumber(from string: String) -> Int {
            let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Int(numbers) ?? 0
        }

        func generateAnalysis (fat: Int = 8, cholesterol: Int = 0, sodium: Int = 170, carbs: Int = 17, protein: Int = 2) -> NutritionAnalysis {
            var details: [String] = []
            var healthScore = 0

            if fat <= 5 {
                details.append("The fat content (\(fat)g) is within a reasonable range, which is beneficial for heart health.")
                healthScore += 1
            } else {
                details.append("The fat content (\(fat)g) is high. Be mindful of your daily fat intake for better heart health.")
            }

            if cholesterol <= 50 {
                details.append("Cholesterol levels (\(cholesterol)mg) are moderate to low, which is good for cardiovascular health.")
                healthScore += 1
            } else {
                details.append("Cholesterol levels (\(cholesterol)mg) are high. This may not be suitable for those watching their cholesterol intake.")
            }

            if sodium <= 500 {
                details.append("Sodium levels (\(sodium)mg) are within an acceptable range, which is good for blood pressure management.")
                healthScore += 1
            } else {
                details.append("This food is high in sodium (\(sodium)mg). Be cautious if you're on a low-sodium diet for blood pressure control.")
            }

            if carbs <= 15 {
                details.append("Carbohydrate content (\(carbs)g) is moderate to low, which can be beneficial for blood sugar control.")
                healthScore += 1
            } else {
                details.append("Carbohydrate content (\(carbs)g) is high. Consider this if you're watching your carb intake for blood sugar management.")
            }

            if protein > 15 {
                details.append("This food is a good source of protein (\(protein)g), which is important for muscle maintenance and growth.")
                healthScore += 1
            } else {
                details.append("Protein content (\(protein)g) is moderate to low. Consider additional protein sources in your diet.")
            }

            let overallAssessment: String
            if healthScore >= 4 {
                overallAssessment = "Overall, this food item appears to be relatively healthy due to its balanced nutritional profile. It's particularly good in terms of [list top 2-3 positive aspects]. However, always consider your individual dietary needs and consult with a nutritionist if needed."
            } else {
                overallAssessment = "Overall, this food item may not be the healthiest choice. Consider it as an occasional treat rather than a regular part of your diet. For a healthier diet, look for foods with lower carbohydrates and higher protein."
            }

            return NutritionAnalysis(details: details, overallAssessment: overallAssessment, healthScore: healthScore)
        }
    }
}

class TextRecognizer {
    func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion("")
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            let result = recognizedStrings.joined(separator: "\n")
            completion(result)
        }

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
            completion("")
        }
    }
}
