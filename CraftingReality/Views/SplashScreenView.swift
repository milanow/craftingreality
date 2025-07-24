//
//  SplashScreenView.swift
//  CraftingReality
//
//  Created by Tianhe on 7/20/25.
//

import SwiftUI

import SwiftUI
import RealityKit

struct SplashScreenView: View {
    @State private var showSquare = false
    @State private var showCircle = false
    @State private var showTriangle = false
    @State private var showText1 = false
    @State private var showText2 = false
    @State private var showButton = false
    @Binding var beginPressed: Bool
    
    var body: some View {
        ZStack {
            // Red Square
            Rectangle()
                .fill(Color.red)
                .frame(width: 400, height: 400)
                .offset(x: -130, y: -160)
                .scaleEffect(showSquare ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.1), value: showSquare)
                .padding3D(.front, 100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSquare = true
                    }
                }
            
            // Blue Circle
            Circle()
                .fill(Color.blue)
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -60)
                .scaleEffect(showCircle ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.1), value: showCircle)
                .padding3D(.front, 100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showCircle = true
                    }
                }
            
            // Yellow Triangle
            Triangle()
                .fill(Color.yellow)
                .frame(width: 400, height: 346)
                .offset(x: -43, y: 90)
                .scaleEffect(showTriangle ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.1), value: showTriangle)
                .padding3D(.front, 100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showTriangle = true
                    }
                }
            
            // text here
            Text("C r a f t i n g")
                .font(.extraLargeTitle)
                .offset(x: -29, y: -92)
                .scaleEffect(showText1 ? 1 : 0)
                .opacity(showText1 ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: showText1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showText1 = true
                    }
                }
            
            Text("R e a l i t y")
                .font(.extraLargeTitle)
                .offset(x: 145, y: 20)
                .scaleEffect(showText2 ? 1 : 0)
                .opacity(showText2 ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: showText2)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showText2 = true
                    }
                }
            
            Button("Begin", systemImage: "play.circle.fill") {
                beginPressed = true
            }
                .offset(x: 0, y: 165)
                .foregroundStyle(.white)
                .scaleEffect(showButton ? 1 : 0)
                .opacity(showButton ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showButton)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showButton = true
                    }
                }
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .buttonBorderShape(.roundedRectangle)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start from the bottom left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Add line to the top middle
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        // Add line to the bottom right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Close the path to create the third side of the triangle
        path.closeSubpath()

        return path
    }
}

#Preview(windowStyle: .plain) {
    @Previewable @State var beginPressed = false
    SplashScreenView(beginPressed: $beginPressed)
}
