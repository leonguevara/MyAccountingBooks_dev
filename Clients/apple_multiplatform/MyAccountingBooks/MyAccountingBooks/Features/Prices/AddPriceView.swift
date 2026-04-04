//
//  Features/Prices/AddPriceView.swift
//  AddPriceView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Sheet form for recording a new exchange rate entry.
///
/// Presented by ``PriceListView``. Pre-selects the ledger's currency as the reference currency on
/// appear. The user-entered decimal rate is converted to a rational `(valueNum, valueDenom)` pair
/// before submission to ``PriceNetworkService``. A live preview row appears once all fields are valid.
///
/// - SeeAlso: ``PriceListView``, ``PriceNetworkService``, ``CreatePriceRequest``
struct AddPriceView: View {

    // MARK: - Input

    /// The owning ledger; supplies `currencyCode` and `decimalPlaces`.
    let ledger:      LedgerResponse
    /// Available commodities used to populate both pickers.
    let commodities: [CommodityResponse]
    /// Called with the newly created entry after a successful POST.
    let onCreated:   (PriceResponse) -> Void

    // MARK: - Environment

    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss)        private var dismiss

    // MARK: - Form state

    /// The commodity being priced (e.g. USD).
    @State private var selectedCommodity: CommodityResponse?
    /// The reference currency (e.g. MXN); pre-set to the ledger's currency on appear.
    @State private var selectedCurrency:  CommodityResponse?
    /// Effective date/time of the rate; defaults to now.
    @State private var date:              Date     = .now
    /// User-entered decimal rate string, converted to rational on submit.
    @State private var rateString:        String   = ""
    /// Optional source label (e.g. "Banxico", "manual").
    @State private var source:            String   = "manual"

    // MARK: - UI state

    /// `true` while the POST request is in flight.
    @State private var isSubmitting  = false
    /// Non-nil when the POST request fails.
    @State private var errorMessage: String?

    // MARK: - Derived

    /// `true` when both pickers are set, commodity ≠ currency, and `parsedRate` is non-nil.
    private var canSubmit: Bool {
        selectedCommodity != nil &&
        selectedCurrency  != nil &&
        selectedCommodity?.id != selectedCurrency?.id &&
        parsedRate != nil
    }

    /// Parses `rateString` into a `(valueNum, valueDenom)` rational pair using `ledger.decimalPlaces` as the exponent.
    private var parsedRate: (valueNum: Int, valueDenom: Int)? {
        let trimmed = rateString.trimmingCharacters(in: .whitespaces)
        guard let value = Decimal(string: trimmed), value > 0 else { return nil }
        let denom  = Int(pow(10.0, Double(ledger.decimalPlaces)))
        let scaled = value * Decimal(denom)
        guard let num = Int(exactly: (scaled as NSDecimalNumber).intValue) else { return nil }
        return (valueNum: num, valueDenom: denom)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("Add Exchange Rate")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isSubmitting)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Form ──────────────────────────────────────────────────
            Form {
                Section("Rate Details") {

                    Picker("Commodity", selection: $selectedCommodity) {
                        Text("Select commodity…")
                            .tag(CommodityResponse?.none)
                        ForEach(commodities.filter { $0.id != selectedCurrency?.id }) { c in
                            Text("\(c.mnemonic) — \(c.fullName ?? c.mnemonic)")
                                .tag(CommodityResponse?.some(c))
                        }
                    }

                    Picker("Price in", selection: $selectedCurrency) {
                        Text("Select currency…")
                            .tag(CommodityResponse?.none)
                        ForEach(commodities.filter { $0.id != selectedCommodity?.id }) { c in
                            Text("\(c.mnemonic) — \(c.fullName ?? c.mnemonic)")
                                .tag(CommodityResponse?.some(c))
                        }
                    }

                    LabeledContent("Rate") {
                        TextField(
                            "e.g. 19.50",
                            text: $rateString
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                    }

                    DatePicker(
                        "Effective date",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    LabeledContent("Source") {
                        TextField("e.g. Banxico, manual", text: $source)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Preview
                if let (num, denom) = parsedRate,
                   let commodity = selectedCommodity,
                   let currency  = selectedCurrency {
                    Section("Preview") {
                        LabeledContent("Rate") {
                            Text("1 \(commodity.mnemonic) = \(formatRate(num, denom)) \(currency.mnemonic)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Error
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 480, minHeight: 360)
        .onAppear {
            selectedCurrency = commodities.first {
                $0.mnemonic == ledger.currencyCode
            }
        }
    }

    // MARK: - Actions

    /// POSTs the new price entry; calls `onCreated` and dismisses on success, sets `errorMessage` on failure.
    private func submit() async {
        guard let token    = auth.token,
              let commodity = selectedCommodity,
              let currency  = selectedCurrency,
              let (num, denom) = parsedRate else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let created = try await PriceNetworkService.shared.createPrice(
                ledgerID:    ledger.id,
                commodityId: commodity.id,
                currencyId:  currency.id,
                date:        date,
                valueNum:    num,
                valueDenom:  denom,
                source:      source.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? nil
                                 : source.trimmingCharacters(in: .whitespaces),
                type:        "last",
                token:       token
            )
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    /// Formats a rational `valueNum / valueDenom` as a decimal string using `ledger.decimalPlaces`.
    private func formatRate(_ valueNum: Int, _ valueDenom: Int) -> String {
        guard valueDenom != 0 else { return "—" }
        let rate = Decimal(valueNum) / Decimal(valueDenom)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = ledger.decimalPlaces
        formatter.maximumFractionDigits = ledger.decimalPlaces
        return formatter.string(from: rate as NSDecimalNumber) ?? "\(rate)"
    }
}
