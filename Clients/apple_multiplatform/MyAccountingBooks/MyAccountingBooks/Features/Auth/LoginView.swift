//
//  Features/Auth/LoginView.swift
//  LoginView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//

import SwiftUI

/// A simple login screen that authenticates the user using `AuthService`.
///
/// Presents fields for email and password, shows a loading state while signing in,
/// and displays any error message returned by the authentication flow.
struct LoginView: View {
    /// Authentication service injected from the environment.
    @Environment(AuthService.self) private var auth
    /// The user's email input.
    @State private var email = ""
    /// The user's password input.
    @State private var password = ""
    /// Indicates whether a sign-in request is currently in progress.
    @State private var isLoading = false
    /// An optional error message to present when sign-in fails.
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("MyAccountingBooks")
                .font(.largeTitle).bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Button(isLoading ? "Signing in…" : "Sign In") {
                Task { await signIn() }
            }
            .disabled(isLoading)
            .keyboardShortcut(.return)
        }
        .padding(40)
        .frame(width: 420, height: 340)
    }

    /// Performs the sign-in flow using `AuthService` and updates UI state accordingly.
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

