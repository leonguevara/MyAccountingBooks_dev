//
//  Features/Auth/RegisterView.swift
//  RegisterView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-31.
//  Developed with AI assistance.
//

import SwiftUI

/// Registration form for creating a new MyAccountingBooks account.
///
/// Presented as a sheet from `LoginView`. On successful registration
/// the user is immediately authenticated and the sheet dismisses,
/// revealing the main app content.
///
/// ## Fields
/// - **Email**: Required. Must be a valid email format.
/// - **Password**: Required. Minimum 8 characters.
/// - **Confirm password**: Must match password.
/// - **Display name**: Optional. Shown in the UI.
///
/// ## Error handling
/// - HTTP 409 surfaces as "An account with this email already exists."
/// - All other errors surface as their localised description.
struct RegisterView: View {

    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email        = ""
    @State private var password     = ""
    @State private var confirmPass  = ""
    @State private var displayName  = ""
    @State private var isLoading    = false
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

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && password.count >= 8
        && password == confirmPass
    }

    // MARK: - Submit

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
