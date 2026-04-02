//
//  Features/Transactions/PayeePickerButton.swift
//  PayeePickerButton.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-02.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//

import SwiftUI

struct PayeePickerButton: View {

    @Binding var selectedPayee: PayeeResponse?
    let payees: [PayeeResponse]
    let onCreate: (String) -> Void

    @State private var isExpanded = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.toggle()
                if isExpanded { searchText = "" }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedPayee?.name ?? "Select payee…")
                        .foregroundStyle(selectedPayee == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            if isExpanded {
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search payees…", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Existing payees
                            ForEach(filteredPayees) { payee in
                                Text(payee.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedPayee = payee
                                        isExpanded    = false
                                        searchText    = ""
                                    }
                                Divider().padding(.leading, 12)
                            }
                            // New Payee option
                            let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(trimmed.isEmpty ? Color.secondary : Color.accentColor)
                                Text(trimmed.isEmpty
                                     ? "Type a name to create a payee…"   // ← clearer hint
                                     : "New Payee \"\(trimmed)\"…")
                                    .foregroundStyle(trimmed.isEmpty ? Color.secondary : Color.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !trimmed.isEmpty else { return }
                                isExpanded = false
                                onCreate(trimmed)
                                searchText = ""
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .shadow(radius: 4, y: 2)
                .zIndex(100)
            }
        }
    }

    private var filteredPayees: [PayeeResponse] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return payees }
        return payees.filter { $0.name.lowercased().contains(q) }
    }
}
