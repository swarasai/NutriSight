//
//  MainMenuView.swift
//  NutriSight
//
//  Created by Swarasai Mulagari on 3/22/25.
//

import SwiftUI
import AVFoundation


struct MainMenuView: View {
    @State private var showNutritionAnalyzer = false
    @State private var showExerciseAnalyzer = false
    @StateObject private var speechSynthesizer = SpeechSynthesizer()

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Text("NutriSight")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Button(action: { showNutritionAnalyzer = true }) {
                    Text("Nutrition Analyzer")
                        .font(.title)
                        .padding(20)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }

                Button(action: { showExerciseAnalyzer = true }) {
                    Text("Fitness Analyzer")
                        .font(.title)
                        .padding(20)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showNutritionAnalyzer) {
            NutritionAnalyzerView()
        }
        .sheet(isPresented: $showExerciseAnalyzer) {
            ExerciseAnalyzerView()
        }
        .onAppear {
            speechSynthesizer.speak("Welcome to NutriSight. Please select the Nutrition Analyzer or Fitness Analyzer.") {}
        }
    }
}
