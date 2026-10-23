import SwiftUI

struct ServerWelcomeView: View {
    let onContinue: () -> Void
    @Bindable private var account = ServerAccountStore.shared
    @State private var showingUniversitySetup = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("Your campus, together")
                            .font(.largeTitle.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Explore courses and campus life. Sign in to keep your subscriptions, calendar and tasks together.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                    Button("Sign In") {
                        Task {
                            await account.login()
                            if account.user != nil { onContinue() }
                        }
                    }
                    .disabled(account.isLoading)
                    .accessibilityIdentifier("welcome_sign_in")
                    Button("Browse without signing in", action: onContinue)
                        .accessibilityIdentifier("welcome_browse")
                    if account.isLoading { ProgressView() }
                    if let error = account.error {
                        Text(error).foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Connect university services") {
                        showingUniversitySetup = true
                    }
                    .accessibilityIdentifier("welcome_university")
                } footer: {
                    Text("University access is optional and provides grades and Blackboard assignments.")
                }
            }
            .navigationTitle("Welcome")
            .sheet(isPresented: $showingUniversitySetup) {
                USTCOnboardingView {
                    showingUniversitySetup = false
                    onContinue()
                }
            }
        }
    }
}
