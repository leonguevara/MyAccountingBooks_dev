//
//  Core/Models/CoaTemplate.swift
//  CoaTemplate.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-29.
//  Developed with AI assistance.
//

import Foundation

/// A chart-of-accounts template entry from the global catalog.
///
/// `CoaTemplateItem` maps the JSON response of `GET /coa-templates` to a Swift value.
/// Templates are shared across all tenants — they are not scoped to any owner or ledger —
/// and are used to pre-populate a new ledger's chart of accounts at creation time.
///
/// ## Key Fields
///
/// | Field | Required | Purpose |
/// |---|---|---|
/// | `code` | Yes | Stable identifier passed to the ledger-creation API |
/// | `version` | Yes | Template version; multiple versions of the same `code` may exist |
/// | `country` / `locale` | Optional | Filter hint for surfacing region-appropriate templates |
/// | `industry` | Optional | Sector hint (e.g., `"retail"`, `"professional_services"`) |
///
/// ## Usage
///
/// ```swift
/// // Display in a picker
/// Picker("Template", selection: $selectedTemplate) {
///     ForEach(templates) { template in
///         Text(template.displayName).tag(template)
///     }
/// }
///
/// // Pass to ledger creation
/// let request = CreateLedgerRequest(
///     coaTemplateCode:    selectedTemplate.code,
///     coaTemplateVersion: selectedTemplate.version,
///     ...
/// )
/// ```
///
/// - SeeAlso: ``CoaTemplateService``, ``CreateLedgerRequest``
struct CoaTemplateItem: Codable, Identifiable, Hashable {

    /// Unique identifier of the template record.
    let id: UUID

    /// Stable, short identifier used when referencing the template in API requests
    /// (e.g., `"general"`, `"retail_us"`).
    let code: String

    /// Human-readable template name (e.g., `"General Purpose - US"`).
    let name: String

    /// Optional long-form description of the template's intended use case.
    let description: String?

    /// Optional ISO 3166-1 alpha-2 country code the template is designed for
    /// (e.g., `"US"`, `"MX"`). `nil` indicates a country-neutral template.
    let country: String?

    /// Optional IETF BCP 47 locale tag (e.g., `"en-US"`, `"es-MX"`).
    /// Used to surface region-appropriate templates in pickers.
    let locale: String?

    /// Optional industry sector hint (e.g., `"retail"`, `"professional_services"`).
    /// `nil` indicates a general-purpose template suitable for any sector.
    let industry: String?

    /// Template version string (e.g., `"1.0"`, `"2024"`).
    ///
    /// Multiple versions of the same `code` may exist in the catalog. Both `code`
    /// and `version` must be passed to the ledger-creation API.
    let version: String

    /// Human-readable label combining name and version for display in pickers.
    ///
    /// Format: `"<name> (<version>)"`, e.g., `"General Purpose - US (1.0)"`.
    var displayName: String {
        "\(name) (\(version))"
    }
}
