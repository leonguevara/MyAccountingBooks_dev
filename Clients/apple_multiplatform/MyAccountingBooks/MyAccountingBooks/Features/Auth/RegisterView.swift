//
//  Features/Auth/RegisterView.swift
//  RegisterView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import SwiftUI

/// Registration sheet for creating a new owner account.
///
/// Presented as a sheet from ``LoginView``. On success ``AuthService/register(email:password:displayName:)``
/// authenticates the user immediately and the sheet dismisses. HTTP 409 (duplicate email) surfaces
/// as a specific inline message; all other errors use their localised description.
///
/// ## Fields
/// - Email: required, valid format enforced client-side by ``canSubmit``
/// - Password: required, minimum 8 characters
/// - Confirm password: must match `password`
/// - Display name: optional
///
/// - SeeAlso: ``LoginView``, ``AuthService``
struct RegisterView: View {

    /// ``AuthService`` injected from the environment by ``LoginView``.
    @Environment(AuthService.self) private var auth
    /// Dismisses the sheet on successful registration or cancel.
    @Environment(\.dismiss) private var dismiss

    /// Email field binding.
    @State private var email        = ""
    /// Password field binding.
    @State private var password     = ""
    /// Confirm-password field binding; must equal `password` for ``canSubmit`` to be `true`.
    @State private var confirmPass  = ""
    /// Optional display name field binding.
    @State private var displayName  = ""
    /// `true` while ``submit()`` is in flight; shows a `ProgressView` and disables the Create button.
    @State private var isLoading    = false
    /// Inline error text shown when ``submit()`` throws; `nil` when no error is present.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    #endif

                    SecureField("Password (min. 8 characters)", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm password", text: $confirmPass)
                        .textContentType(.newPassword)
                }

                Section("Profile") {
                    TextField("Display name (optional)", text: $displayName)
                        .textContentType(.name)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canSubmit || isLoading)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 380)
    }

    // MARK: - Validation

    /// `true` when email is non-blank, password is at least 8 characters, and both password fields match.
    ///
    /// Gates the Create button; re-evaluated reactively as the user types.
    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && password.count >= 8
        && password == confirmPass
    }

    // MARK: - Submit

    /// Calls ``AuthService/register(email:password:displayName:)`` and handles the result.
    ///
    /// Trims whitespace from `email` and `displayName` before sending; passes `nil` for
    /// `displayName` when the trimmed value is blank. Dismisses the sheet on success;
    /// writes to ``errorMessage`` on failure.
    private func submit() async {
        guard canSubmit else { return }
        isLoading    = true
        errorMessage = nil
        do {
            try await auth.register(
                email:       email.trimmingCharacters(in: .whitespaces),
                password:    password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
                                        .isEmpty ? nil : displayName
            )
            dismiss()
        } catch APIError.conflict {
            errorMessage = "An account with this email already exists."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
