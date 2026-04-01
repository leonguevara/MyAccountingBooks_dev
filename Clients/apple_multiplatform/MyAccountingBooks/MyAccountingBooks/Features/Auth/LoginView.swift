//
//  Features/Auth/LoginView.swift
//  LoginView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import SwiftUI

/// Login screen — email/password fields, sign-in button, and a "Create account" link.
///
/// Delegates authentication to ``AuthService/login(email:password:)`` via ``signIn()``.
/// On success ``AuthService/isAuthenticated`` flips to `true` and the root view swaps to
/// the authenticated content. On failure ``errorMessage`` is displayed inline.
///
/// - SeeAlso: ``AuthService``, ``RegisterView``
struct LoginView: View {
    /// ``AuthService`` injected from the environment by the app root.
    @Environment(AuthService.self) private var auth
    /// Email field binding.
    @State private var email = ""
    /// Password field binding.
    @State private var password = ""
    /// `true` while ``signIn()`` is in flight; disables the button and shows "Signing in…".
    @State private var isLoading = false
    /// Inline error text shown when ``signIn()`` throws; `nil` when no error is present.
    @State private var errorMessage: String?
    /// Controls presentation of the ``RegisterView`` sheet.
    @State private var showRegister = false

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
            
            Button("Create account") {
                showRegister = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            
        }
        .padding(40)
        .frame(width: 420, height: 340)
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environment(auth)
        }
    }

    /// Calls ``AuthService/login(email:password:)`` and writes any failure to ``errorMessage``.
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

