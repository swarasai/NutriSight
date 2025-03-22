//
//  ExerciseAnalyzerView.swift
//  NutriSight
//
//  Created by Swarasai Mulagari on 3/22/25.
//

import SwiftUI
import AVFoundation
import Vision
import Speech

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ viewController: CameraViewController, didUpdateFeedbackSummary summary: String)
}
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

struct ExerciseAnalyzerView: View {
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
        @State private var isAnalyzing = false
        @State private var feedbackSummary: String = ""
        @State private var selectedExercise = ""
        @State private var showFeedback = false
        @State private var recognizedText = ""
        @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        @State private var recognitionTask: SFSpeechRecognitionTask?
        @State private var audioEngine = AVAudioEngine()
        @State private var showCameraView = false
        @State private var isListening = false
        @State private var showFeedbackView = false

    private let exercises = [
        "Squat", "Push-up", "Lunge", "Plank", "Glute Bridge", "Calf Raise",
        "Wall Sit", "Shoulder Press", "Tricep Dip", "Bicycle Crunch",
        "Superman", "Mountain Climber", "Jumping Jack", "Burpee",
        "High Knees", "Box Jump", "Kettlebell Swing", "Russian Twist", "Step-up"
    ]

    var body: some View {
            VStack {
                if showCameraView {
                    VStack(spacing: 20) {
                        Text("Recognized Text (Performing): \(recognizedText)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()

                        Text(isAnalyzing ? "Analysis in progress..." : "Analysis stopped.")
                            .font(.headline)
                            .foregroundColor(isAnalyzing ? .green : .red)
                            .padding()

                        CameraView(
                            feedbackSummary: $feedbackSummary,
                            recognizedText: $recognizedText,
                            exercise: selectedExercise,
                            isAnalyzing: $isAnalyzing,
                            speechSynthesizer: speechSynthesizer,
                            onStopAnalysis: {
                                self.showCameraView = false
                                self.showFeedbackView = true
                            }
                        )

                        Button("Stop Analysis") {
                            isAnalyzing = false
                            showCameraView = false
                            showFeedbackView = true
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else if showFeedbackView {
                    FeedbackView(
                        feedbackSummary: $feedbackSummary,
                        showFeedback: $showFeedbackView, // Change this from $showFeedback to $showFeedbackView
                        speechSynthesizer: speechSynthesizer
                    )

                }else {
                        VStack(spacing: 20) {
                            Button("Hear Exercise Options") {
                                readExercisesAloud()
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            Button("Say Exercise Name") {
                                startListeningForExercise()
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            Text("Recognized Text (Selection): \(recognizedText)") // Display recognized text during selection
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
                .onAppear(perform: onAppearWelcome)
            }

    private func onAppearWelcome() {
        speechSynthesizer.speak("Welcome to the exercise analyzer. Click the button to hear exercise options or say the exercise you want to perform.") {}
    }

    private func readExercisesAloud() {
        let introduction = "Here are the exercise options you can choose from:"
        speechSynthesizer.speak(introduction) {
            self.speakExerciseGroups()
        }
    }

    private func speakExerciseGroups(groupIndex: Int = 0) {
        let exerciseGroups = exercises.chunked(into: 5)
        guard groupIndex < exerciseGroups.count else {
            speechSynthesizer.speak("Now, click the button to say the exercise you want to perform.") {}
            return
        }

        let group = exerciseGroups[groupIndex]
        let groupText = group.joined(separator: ", ")
        speechSynthesizer.speak(groupText) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.speakExerciseGroups(groupIndex: groupIndex + 1)
            }
        }
    }
    private func setupAudioSession() {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to set up audio session: \(error.localizedDescription)")
            }
        }
    
    private func startListeningForExercise() {
        isListening = true
        recognizedText = ""
        let request = SFSpeechAudioBufferRecognitionRequest()

        setupAudioSession() // Set up the audio session

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Check if the format is valid
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("Invalid input format: \(recordingFormat)")
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            isListening = false
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            guard let result = result else {
                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                }
                self.isListening = false
                return
            }

            let recognizedText = result.bestTranscription.formattedString.lowercased()
            DispatchQueue.main.async {
                self.recognizedText = recognizedText
            }

            if let matchedExercise = self.exercises.first(where: { $0.lowercased() == recognizedText }) {
                            self.audioEngine.stop()
                            inputNode.removeTap(onBus: 0)
                            self.recognitionTask?.cancel()
                            self.isListening = false

                            DispatchQueue.main.async {
                                self.selectedExercise = matchedExercise
                                self.showCameraView = true
                                self.isAnalyzing = true  // Start analysis immediately
                                self.speechSynthesizer.speak("\(matchedExercise) selected. Analysis starting now.") {}
                            }
                        }
        }
    }

    private func startListeningForAnalysisCommand() {
        isListening = true
        let request = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("There was a problem starting the audio engine: \(error.localizedDescription)")
            isListening = false
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            guard let result = result else {
                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                }
                self.isListening = false
                return
            }

            let recognizedText = result.bestTranscription.formattedString.lowercased()
            self.recognizedText = recognizedText

            if recognizedText.contains("start analysis") {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionTask?.cancel()

                self.isListening = false
                self.startAnalysis()
            }
        }
    }


    private func startAnalysis() {
        isAnalyzing = true
        feedbackSummary = ""
        
        speechSynthesizer.speak("Starting analysis for \(selectedExercise). Perform the exercise in front of your camera. Say 'stop analysis' when you're done.") {}
    }

    private func stopAnalysis() {
        isAnalyzing = false
        showCameraView = false
        showFeedback = true

        speechSynthesizer.speak("Analysis stopped. Here's your feedback.") {}
    }
}

struct FeedbackView: View {
    @Binding var feedbackSummary: String
    @Binding var showFeedback: Bool
    let speechSynthesizer: SpeechSynthesizer

    var body: some View {
        VStack(spacing: 20) {
            Text("Exercise Feedback")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            ScrollView {
                Text(feedbackSummary)
                    .font(.title2)
                    .padding()
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(15)
            }
            .onAppear {
                speakFeedback()
            }

            Button(action: { showFeedback = false }) {
                Text("Try Another Exercise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
        }
    }

    private func speakFeedback() {
        guard !feedbackSummary.isEmpty else {
            print("No feedback to speak.")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.speechSynthesizer.speak("Here's your feedback: \(self.feedbackSummary)") {}
        }
    }

}



class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
        print("SpeechSynthesizer initialized")
    }

    func speak(_ text: String, completion: @escaping () -> Void) {
        guard !text.isEmpty else {
            print("No text provided to speak.")
            return
        }

        print("Speaking text: \(text)")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0

        synthesizer.speak(utterance)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            completion()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Started speaking")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")
    }
}



struct CameraView: UIViewControllerRepresentable {
    @Binding var feedbackSummary: String
    @Binding var recognizedText: String // Add this binding
    var exercise: String
    @Binding var isAnalyzing: Bool
    var speechSynthesizer: SpeechSynthesizer
    var onStopAnalysis: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        controller.exercise = exercise
        controller.speechSynthesizer = speechSynthesizer
        controller.onStopAnalysis = onStopAnalysis
        return controller
    }


    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
            uiViewController.isAnalyzing = isAnalyzing
        }

    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraView
        var parentRecognizedTextBinding: Binding<String>

        init(_ parent: CameraView) {
            self.parent = parent
            self.parentRecognizedTextBinding = parent.$recognizedText
        }

        func cameraViewController(_ viewController: CameraViewController, didUpdateFeedbackSummary summary: String) {
            parent.feedbackSummary = summary
            parentRecognizedTextBinding.wrappedValue = viewController.recognizedText
        }
    }
}




// MARK: - Camera View Controller Implementation
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: CameraViewControllerDelegate?
    var exercise: String = "Squat"
    var recognizedText: String = ""
    var isAnalyzing: Bool = false
    var speechSynthesizer: SpeechSynthesizer!
    var onStopAnalysis: (() -> Void)?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var poseRequest = VNDetectHumanBodyPoseRequest()
    private var lastAnalysisTime = Date()
    private var analysisInterval: TimeInterval = 1.0
    private var feedbackCounts = (good: 0, improve: 0, poor: 0)
    private var recordingSession: AVAudioSession!
    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
            startAnalysis()  // Start analysis immediately
        }
    func startAnalysis() {
            isAnalyzing = true
            speechSynthesizer.speak("Analysis started.") {
                print("Analysis started.")
            }
        }

    func stopAnalysis() {
        isAnalyzing = false
        speechSynthesizer.speak("Analysis stopped.") {
            self.speechSynthesizer.speak("Here is your feedback. \(self.delegateFeedback())") {
                self.onStopAnalysis?()
            }
        }
    }

    private func delegateFeedback() -> String {
        if let delegate = self.delegate as? CameraView.Coordinator {
            return delegate.parent.feedbackSummary
        } else {
            return "No feedback summary available."
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        
        captureSession?.addInput(input)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession?.addOutput(videoOutput)
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.frame = view.bounds
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer!)
        
        captureSession?.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastAnalysisTime) >= analysisInterval else { return }
        lastAnalysisTime = currentTime
        
        let handler = VNImageRequestHandler(ciImage: CIImage(cvPixelBuffer: pixelBuffer), orientation: .up, options: [:])
        do {
            try handler.perform([poseRequest])
            guard let observations = poseRequest.results as? [VNHumanBodyPoseObservation] else { return }
            
            DispatchQueue.main.async {
                self.analyzePose(observations: observations)
            }
        } catch {
            print("Failed to perform pose detection: \(error)")
        }
    }
    
    private func analyzePose(observations: [VNHumanBodyPoseObservation]) {
        guard let observation = observations.first else { return }
        
        let feedback: String = {
            switch exercise {
            case "Squat": return analyzeSquat(observation: observation)
            case "Push-up": return analyzePushUp(observation: observation)
            case "Lunge": return analyzeLunge(observation: observation)
            case "Plank": return analyzePlank(observation: observation)
            case "Glute Bridge": return analyzeGluteBridge(observation: observation)
            case "Calf Raise": return analyzeCalfRaise(observation: observation)
            case "Wall Sit": return analyzeWallSit(observation: observation)
            case "Shoulder Press": return analyzeShoulderPress(observation: observation)
            case "Tricep Dip": return analyzeTricepDip(observation: observation)
            case "Bicycle Crunch": return analyzeBicycleCrunch(observation: observation)
            case "Superman": return analyzeSuperman(observation: observation)
            case "Mountain Climber": return analyzeMountainClimber(observation: observation)
            case "Jumping Jack": return analyzeJumpingJack(observation: observation)
            case "Burpee": return analyzeBurpee(observation: observation)
            case "High Knees": return analyzeHighKnees(observation: observation)
            case "Box Jump": return analyzeBoxJump(observation: observation)
            case "Kettlebell Swing": return analyzeKettlebellSwing(observation: observation)
            case "Russian Twist": return analyzeRussianTwist(observation: observation)
            case "Step-up": return analyzeStepUp(observation: observation)
            default: return "Exercise not recognized"
            }
        }()
        
        updateFeedbackCounts(feedback: feedback)
        generateFeedbackSummary()
    }
    
        // MARK: - Analysis Helper Methods
    private func updateFeedbackCounts(feedback: String) {
        if feedback.contains("Good") {
            feedbackCounts.good += 1
        } else if feedback.contains("Improve") {
            feedbackCounts.improve += 1
        } else if feedback.contains("Poor") {
            feedbackCounts.poor += 1
        }
    }
    
    private func generateFeedbackSummary() {
        let total = Double(feedbackCounts.good + feedbackCounts.improve + feedbackCounts.poor)
        guard total > 0 else { return }
        
        let goodPercentage = Double(feedbackCounts.good) / total
        let improvePercentage = Double(feedbackCounts.improve) / total
        let poorPercentage = Double(feedbackCounts.poor) / total
        
        var summary = "\(exercise) analysis: "
        summary += String(format: "%.0f%% good form, ", goodPercentage * 100)
        summary += String(format: "%.0f%% needs improvement, ", improvePercentage * 100)
        summary += String(format: "%.0f%% poor form. ", poorPercentage * 100)
        summary += getImprovementSuggestion()
        
        DispatchQueue.main.async {
            self.delegate?.cameraViewController(self, didUpdateFeedbackSummary: summary)
            
            //self.speechSynthesizer?.speak("Here is your feedback. \(summary)") {}
        }
    }


    
    private func getImprovementSuggestion() -> String {
        switch exercise {
        case "Squat": return "Work on lowering your hips more and keeping your back straight."
        case "Push-up": return "Try to lower your chest closer to the ground and keep your body straight."
        case "Lunge": return "Focus on keeping your front knee at a 90-degree angle."
        case "Plank": return "Keep your body in a straight line from head to heels."
        case "Glute Bridge": return "Lift your hips higher and squeeze your glutes at the top."
        case "Calf Raise": return "Rise up onto your toes as high as possible."
        case "Wall Sit": return "Keep thighs parallel to the ground and back against the wall."
        case "Shoulder Press": return "Fully extend your arms overhead."
        case "Tricep Dip": return "Lower until your upper arms are parallel to the ground."
        case "Bicycle Crunch": return "Rotate your torso more and bring elbow to opposite knee."
        case "Superman": return "Lift your arms and legs higher off the ground."
        case "Mountain Climber": return "Bring knees closer to your chest."
        case "Jumping Jack": return "Fully extend your arms and legs with each jump."
        case "Burpee": return "Lower chest to the ground and jump higher at the end."
        case "High Knees": return "Lift knees higher and increase your pace."
        case "Box Jump": return "Land softly with knees slightly bent."
        case "Kettlebell Swing": return "Drive movement from hips and keep arms straight."
        case "Russian Twist": return "Rotate torso further and lift feet off the ground."
        case "Step-up": return "Step fully onto the platform and straighten your leg at the top."
        default: return "Focus on maintaining proper form throughout the exercise."
        }
    }
    
    // MARK: - Exercise Analysis Implementations
    private func analyzeSquat(observation: VNHumanBodyPoseObservation) -> String {
        guard let hipAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect squat pose"
        }
        return angleFeedback(angle: hipAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Good squat depth", improveMsg: "Go lower", poorMsg: "Bend knees more")
    }

    private func analyzePushUp(observation: VNHumanBodyPoseObservation) -> String {
        guard let elbowAngle = getAngle(joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist, observation: observation) else {
            return "Cannot detect push-up pose"
        }
        return angleFeedback(angle: elbowAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Full range", improveMsg: "Lower chest more", poorMsg: "Not low enough")
    }

    private func analyzeLunge(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect lunge pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 80..<100, improveRange: 100..<120, goodMsg: "Front knee bent properly", improveMsg: "Bend front knee more", poorMsg: "Adjust stance and knee bend")
    }

    private func analyzePlank(observation: VNHumanBodyPoseObservation) -> String {
        guard let bodyAngle = getAngle(joint1: .rightShoulder, joint2: .rightHip, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect plank pose"
        }
        return angleFeedback(angle: bodyAngle, goodRange: 160..<180, improveRange: 150..<160, goodMsg: "Body well-aligned", improveMsg: "Straighten body more", poorMsg: "Align body, keep straight")
    }

    private func analyzeGluteBridge(observation: VNHumanBodyPoseObservation) -> String {
        guard let hipAngle = getAngle(joint1: .rightShoulder, joint2: .rightHip, joint3: .rightKnee, observation: observation) else {
            return "Cannot detect glute bridge pose"
        }
        return angleFeedback(angle: hipAngle, goodRange: 160..<180, improveRange: 140..<160, goodMsg: "Hips raised high", improveMsg: "Raise hips higher", poorMsg: "Lift hips much higher")
    }

    private func analyzeCalfRaise(observation: VNHumanBodyPoseObservation) -> String {
        guard let anklePoint = try? observation.recognizedPoint(.rightAnkle),
              let kneePoint = try? observation.recognizedPoint(.rightKnee),
              anklePoint.confidence > 0.1 && kneePoint.confidence > 0.1 else {
            return "Cannot detect calf raise pose"
        }
        
        let verticalDistance = kneePoint.location.y - anklePoint.location.y
        let normalizedDistance = verticalDistance / (kneePoint.location.y - 0.5)
        
        if normalizedDistance < 0.1 {
            return "Good calf raise form: Heels raised high"
        } else if normalizedDistance < 0.15 {
            return "Improve calf raise form: Raise your heels higher"
        } else {
            return "Poor calf raise form: Lift your heels much higher"
        }
    }

    private func analyzeWallSit(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect wall sit pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 85..<95, improveRange: 80..<85, goodMsg: "Knees at 90 degrees", improveMsg: "Adjust to 90 degree knee bend", poorMsg: "Significantly off from 90 degree knee bend")
    }

    private func analyzeShoulderPress(observation: VNHumanBodyPoseObservation) -> String {
        guard let shoulderAngle = getAngle(joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist, observation: observation) else {
            return "Cannot detect shoulder press pose"
        }
        return angleFeedback(angle: shoulderAngle, goodRange: 160..<180, improveRange: 140..<160, goodMsg: "Arms extended", improveMsg: "Extend arms more", poorMsg: "Push weights higher")
    }

    private func analyzeTricepDip(observation: VNHumanBodyPoseObservation) -> String {
        guard let elbowAngle = getAngle(joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist, observation: observation) else {
            return "Cannot detect tricep dip pose"
        }
        return angleFeedback(angle: elbowAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Arms bent sufficiently", improveMsg: "Lower body more", poorMsg: "Bend elbows more")
    }

    private func analyzeBicycleCrunch(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation),
              let elbowAngle = getAngle(joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist, observation: observation) else {
            return "Cannot detect bicycle crunch pose"
        }
        if kneeAngle < 45 && elbowAngle < 90 {
            return "Good bicycle crunch form: Knee close to chest and elbow twisted"
        } else if kneeAngle < 60 && elbowAngle < 110 {
            return "Improve bicycle crunch form: Bring knee closer to chest and twist more"
        } else {
            return "Poor bicycle crunch form: Bring your knee much closer and twist further"
        }
    }

    private func analyzeSuperman(observation: VNHumanBodyPoseObservation) -> String {
        guard let bodyAngle = getAngle(joint1: .rightShoulder, joint2: .rightHip, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect superman pose"
        }
        return angleFeedback(angle: bodyAngle, goodRange: 160..<180, improveRange: 140..<160, goodMsg: "Body well-extended", improveMsg: "Lift limbs higher", poorMsg: "Lift arms and legs much higher")
    }

    private func analyzeMountainClimber(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect mountain climber pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Knee close to chest", improveMsg: "Bring knee closer to chest", poorMsg: "Bring knee much closer to chest")
    }

    private func analyzeJumpingJack(observation: VNHumanBodyPoseObservation) -> String {
        guard let armAngle = getAngle(joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist, observation: observation),
              let legAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect jumping jack pose"
        }
        if armAngle > 150 && legAngle > 30 {
            return "Good jumping jack form: Arms and legs extended"
        } else if armAngle > 120 && legAngle > 20 {
            return "Improve jumping jack form: Extend arms and legs more"
        } else {
            return "Poor jumping jack form: Jump higher and extend arms fully"
        }
    }

    private func analyzeBurpee(observation: VNHumanBodyPoseObservation) -> String {
        guard let hipAngle = getAngle(joint1: .rightShoulder, joint2: .rightHip, joint3: .rightKnee, observation: observation) else {
            return "Cannot detect burpee pose"
        }
        return angleFeedback(angle: hipAngle, goodRange: 0..<60, improveRange: 60..<90, goodMsg: "Low squat position", improveMsg: "Lower your squat", poorMsg: "Squat lower and jump higher")
    }

    private func analyzeHighKnees(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect high knees pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Knee raised high", improveMsg: "Raise knee higher", poorMsg: "Lift knee much higher")
    }

    private func analyzeBoxJump(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect box jump pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Deep squat before jump", improveMsg: "Lower squat before jumping", poorMsg: "Squat lower for more explosive jump")
    }

    private func analyzeKettlebellSwing(observation: VNHumanBodyPoseObservation) -> String {
        guard let hipAngle = getAngle(joint1: .rightShoulder, joint2: .rightHip, joint3: .rightKnee, observation: observation) else {
            return "Cannot detect kettlebell swing pose"
        }
        return angleFeedback(angle: hipAngle, goodRange: 160..<180, improveRange: 140..<160, goodMsg: "Hips fully extended at the top", improveMsg: "Extend hips more at the top", poorMsg: "Focus on hip hinge and full extension")
    }

    private func analyzeRussianTwist(observation: VNHumanBodyPoseObservation) -> String {
        guard let spineAngle = getAngle(joint1: .rightShoulder, joint2: .root, joint3: .rightHip, observation: observation) else {
            return "Cannot detect Russian twist pose"
        }
        return angleFeedback(angle: spineAngle, goodRange: 0..<60, improveRange: 60..<90, goodMsg: "Torso rotated sufficiently", improveMsg: "Rotate torso more", poorMsg: "Increase range of motion")
    }

    private func analyzeStepUp(observation: VNHumanBodyPoseObservation) -> String {
        guard let kneeAngle = getAngle(joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle, observation: observation) else {
            return "Cannot detect step-up pose"
        }
        return angleFeedback(angle: kneeAngle, goodRange: 0..<90, improveRange: 90..<120, goodMsg: "Leg lifted high enough", improveMsg: "Lift leg higher", poorMsg: "Step onto higher platform or lift leg higher")
    }

    // MARK: - Utility Methods
    private func angleFeedback(angle: CGFloat, goodRange: Range<CGFloat>, improveRange: Range<CGFloat>,
                             goodMsg: String, improveMsg: String, poorMsg: String) -> String {
        if goodRange.contains(angle) {
            return "Good: \(goodMsg)"
        } else if improveRange.contains(angle) {
            return "Improve: \(improveMsg)"
        } else {
            return "Poor: \(poorMsg)"
        }
    }
    
    private func getAngle(joint1: VNHumanBodyPoseObservation.JointName,
                         joint2: VNHumanBodyPoseObservation.JointName,
                         joint3: VNHumanBodyPoseObservation.JointName,
                         observation: VNHumanBodyPoseObservation) -> CGFloat? {
        guard let j1 = try? observation.recognizedPoint(joint1),
              let j2 = try? observation.recognizedPoint(joint2),
              let j3 = try? observation.recognizedPoint(joint3),
              [j1.confidence, j2.confidence, j3.confidence].allSatisfy({ $0 > 0.1 }) else {
            return nil
        }
        
        let v1 = CGVector(dx: j1.location.x - j2.location.x, dy: j1.location.y - j2.location.y)
        let v2 = CGVector(dx: j3.location.x - j2.location.x, dy: j3.location.y - j2.location.y)
        
        let angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx)
        return abs(angle * 180 / .pi)
    }
}

struct ExerciseAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseAnalyzerView()
    }
}
