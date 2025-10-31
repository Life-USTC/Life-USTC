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

    enum OnboardingStep: CaseIterable {
        case casLogin
        case additionalCourses
        case widgets
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Group {
                        switch step {
                        case .casLogin:
                            USTCCASLoginView(
                                title: nil,
                                onSuccess: {
                                    withAnimation {
                                        casLoginCompleted = true
                                        currentStep = .additionalCourses
                                    }
                                }
                            )
                        case .additionalCourses:
                            USTCAdditionalCoursesWelcomeView(
                                onNext: {
                                    withAnimation {
                                        currentStep = .widgets
                                    }
                                },
                                onSkip: {
                                    withAnimation {
                                        isPresented = false
                                    }
                                }
                            )
                        case .widgets:
                            USTCWidgetsWelcomeView(
                                onDone: {
                                    withAnimation {
                                        isPresented = false
                                    }
                                }
                            )
                        }
                    }
                    .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("onboarding_close_button")
                }
            }
        }
    }
}

struct USTCAdditionalCoursesWelcomeView: View {
    var onNext: () -> Void
    var onSkip: () -> Void
    @State var showingAddCourseSheet = false

    var body: some View {
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
            }

            Spacer()

            HStack(spacing: 15) {
                Button {
                    showingAddCourseSheet = true
                } label: {
                    Text("Add")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.accentColor)
                        }
                }
                .accessibilityIdentifier("onboarding_add_button")

                Button {
                    onNext()
                } label: {
                    Label("Skip", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 50, height: 50)
                        .background {
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                        }
                }
            }
        }
        .padding(.horizontal, 30)
        .sheet(isPresented: $showingAddCourseSheet) {
            NavigationStack {
                USTCAdditionalCourseView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showingAddCourseSheet = false
                            } label: {
                                Label("Close", systemImage: "xmark")
                            }
                            .accessibilityIdentifier("additional_course_close")
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingAddCourseSheet = false
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .accessibilityIdentifier("additional_course_done")
                        }
                    }
            }
        }
        .onChange(of: showingAddCourseSheet) { newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onNext()
                }
            }
        }
    }
}

struct USTCWidgetsWelcomeView: View {
    var onDone: () -> Void

    var body: some View {
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
            }

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.accentColor)
                    }
            }
            .accessibilityIdentifier("onboarding_done_button")
        }
        .padding(.horizontal, 30)
    }
}
