//
//  AnalysisResultView.swift
//  NutriSight
//
//  Created by Swarasai Mulagari on 3/22/25.
//

import SwiftUI

struct AnalysisResultView: View {
    let resultText: String
    let capturedImage: UIImage
    let healthScore: Int
    let details: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Nutrition Analysis")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(10)
                    .padding(.bottom, 5)

                Text("Detailed Analysis:")
                    .font(.headline)
                    .foregroundColor(.black)

                ForEach(details, id: \.self) { detail in
                    Text("• \(detail)")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Overall Assessment:")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.top, 5)

                Text(resultText)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 5)

                HStack {
                    Text("Health Score:")
                    Spacer()
                    Text("\(healthScore)/6")
                }
                .font(.headline)
                .foregroundColor(.black)

                HealthScoreBar(score: healthScore)
            }
            .padding()
            .background(Color.white.opacity(0.7))
            .cornerRadius(15)
            .padding()
        }
    }
}
