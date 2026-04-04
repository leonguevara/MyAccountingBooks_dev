//
//  Features/Prices/PriceListView.swift
//  PriceListView.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import SwiftUI

/// Sheet listing exchange rate entries for a ledger, with add and delete actions.
///
/// On appear, fetches prices and the CURRENCY commodity catalog in parallel via
/// ``PriceNetworkService`` and ``APIClient``. Tapping "Add Rate" presents ``AddPriceView``;
/// tapping the trash icon soft-deletes the entry.
///
/// - SeeAlso: ``AddPriceView``, ``PriceNetworkService``, ``PriceResponse``
struct PriceListView: View {

    // MARK: - Input

    /// The ledger whose prices are displayed.
    let ledger: LedgerResponse

    // MARK: - Environment

    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss)        private var dismiss

    // MARK: - State

    /// Loaded price entries, ordered by date descending.
    @State private var prices:      [PriceResponse]    = []
    /// CURRENCY commodity catalog used to resolve mnemonic labels.
    @State private var commodities: [CommodityResponse] = []
    /// `true` while the initial parallel fetch is in flight.
    @State private var isLoading    = false
    /// Non-nil when the initial fetch fails.
    @State private var errorMessage: String?
    /// Controls presentation of the ``AddPriceView`` sheet.
    @State private var showAddPrice = false
    /// Non-nil when a delete operation fails.
    @State private var deleteError:  String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("Exchange Rates — \(ledger.name)")
                    .font(.headline)
                Spacer()
                Button {
                    showAddPrice = true
                } label: {
                    Label("Add Rate", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Content ───────────────────────────────────────────────
            if isLoading {
                Spacer()
                ProgressView("Loading prices…")
                Spacer()

            } else if prices.isEmpty {
                emptyState

            } else {
                priceTable
            }

            // ── Error banner ──────────────────────────────────────────
            if let err = deleteError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 620, minHeight: 400)
        .task { await loadAll() }
        .sheet(isPresented: $showAddPrice) {
            AddPriceView(
                ledger:      ledger,
                commodities: commodities,
                onCreated:   { newPrice in
                    prices.insert(newPrice, at: 0)
                }
            )
            .environment(auth)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Price table

    /// Scrollable table of price rows with a sticky column-header row.
    private var priceTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("Date")
                    .frame(width: 140, alignment: .leading)
                Text("Commodity")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Currency")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Rate")
                    .frame(width: 120, alignment: .trailing)
                Text("Source")
                    .frame(width: 80, alignment: .leading)
                // Delete column spacer
                Spacer().frame(width: 36)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(prices) { price in
                        priceRow(price)
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }

    /// Single price row showing date, commodity, currency, rate, source, and a delete button.
    private func priceRow(_ price: PriceResponse) -> some View {
        HStack {
            Text(AmountFormatter.shortDate(price.date))
                .frame(width: 140, alignment: .leading)
                .font(.caption.monospacedDigit())

            Text(commodityName(price.commodityId))
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .lineLimit(1)

            Text(commodityName(price.currencyId))
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .lineLimit(1)

            Text(formattedRate(price))
                .frame(width: 120, alignment: .trailing)
                .font(.caption.monospacedDigit().weight(.semibold))

            Text(price.source ?? "—")
                .frame(width: 80, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                Task { await deletePrice(price) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
            .help("Delete this price entry")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Empty state

    /// Centered empty-state placeholder shown when `prices` is empty.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Exchange Rates")
                .font(.headline)
            Text("Tap \"Add Rate\" to record your first exchange rate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    /// Fetches prices and the CURRENCY commodity catalog in parallel; sets `errorMessage` on failure.
    private func loadAll() async {
        guard let token = auth.token else { return }
        isLoading = true
        async let priceFetch  = PriceNetworkService.shared.fetchPrices(ledgerID: ledger.id, token: token)
        async let commodFetch: [CommodityResponse] = APIClient.shared.request(
            .commodities(namespace: "CURRENCY"), method: "GET", token: token
        )
        do {
            prices      = try await priceFetch
            commodities = try await commodFetch
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Soft-deletes `price` and removes it from `prices`; sets `deleteError` on failure.
    private func deletePrice(_ price: PriceResponse) async {
        guard let token = auth.token else { return }
        deleteError = nil
        do {
            try await PriceNetworkService.shared.deletePrice(priceID: price.id, token: token)
            prices.removeAll { $0.id == price.id }
        } catch {
            deleteError = "Delete failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// Returns the mnemonic for `id`, or a truncated UUID suffix if not found.
    private func commodityName(_ id: UUID) -> String {
        commodities.first { $0.id == id }?.mnemonic ?? id.uuidString.prefix(8).description + "…"
    }

    /// Formats `price.rate` as a currency string using `ledger.currencyCode` and `ledger.decimalPlaces`.
    private func formattedRate(_ price: PriceResponse) -> String {
        guard price.valueDenom != 0 else { return "—" }
        let rate = Decimal(price.valueNum) / Decimal(price.valueDenom)
        var fmt  = Decimal.FormatStyle.Currency(code: ledger.currencyCode)
        fmt      = fmt.precision(.fractionLength(ledger.decimalPlaces))
        return rate.formatted(fmt)
    }
}
