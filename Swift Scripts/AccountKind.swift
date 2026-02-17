/// AccountKind defines the high-level financial statement category of an account.
/// Persist as Int16 in the database and CoreData.
public enum AccountKind: Int16, Codable, CaseIterable, Sendable {
    /// Not a real posting account (root container, grouping nodes).
    case system = 0

    /// Balance Sheet
    case asset = 1
    case liability = 2
    case equity = 3

    /// Income Statement
    case income = 4
    case costOfSales = 5   // “Costos” (SAT 500s)
    case expense = 6       // “Gastos” (SAT 600s)

    /// Off-balance / memorandum accounts
    /// SAT: 700s (deudoras) and 800s (acreedoras).
    case memorandum = 7

    /// Optional: statistical/non-monetary tracking accounts (KPIs, units, etc.)
    case statistical = 8
}
