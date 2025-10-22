//
//  USTC+OnboardingView.swift
//  Life@USTC
//
//  Created by Copilot on 2025/10/22.
//

import SwiftUI

struct USTCOnboardingCoordinator: View {
    @Binding var isPresented: Bool
    @State var currentStep: OnboardingStep = .casLogin
    @State var casLoginCompleted = false
    
    enum OnboardingStep {
        case casLogin
        case additionalCourses
        case widgets
    }
    
    var body: some View {
        Group {
            switch currentStep {
            case .casLogin:
                USTCCASLoginView.sheet(
                    isPresented: $isPresented,
                    onSuccess: {
                        currentStep = .additionalCourses
                    }
                )
            case .additionalCourses:
                USTCAdditionalCoursesWelcomeView(
                    onNext: {
                        currentStep = .widgets
                    },
                    onSkip: {
                        isPresented = false
                    }
                )
            case .widgets:
                USTCWidgetsWelcomeView(
                    onDone: {
                        isPresented = false
                    }
                )
            }
        }
    }
}

struct USTCAdditionalCoursesWelcomeView: View {
    var onNext: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 15) {
                    Text("additionalCoursesWelcomeTitle")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("additionalCoursesWelcomeDescription")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                VStack(spacing: 15) {
                    Button {
                        onNext()
                    } label: {
                        Text("Next")
                            .foregroundColor(.white)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.accentColor)
                            }
                    }
                    
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip for now")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct USTCWidgetsWelcomeView: View {
    var onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "rectangle.stack.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 15) {
                    Text("widgetsWelcomeTitle")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("widgetsWelcomeDescription")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .foregroundColor(.white)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.accentColor)
                        }
                }
                .padding(.horizontal, 30)
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
