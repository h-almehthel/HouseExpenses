import Foundation

final class PaymentListViewModel {
    enum SortOption: CaseIterable {
        case newest, oldest, highestAmount, lowestAmount, category

        var title: String {
            switch self {
            case .newest: return "الأحدث أولًا"
            case .oldest: return "الأقدم أولًا"
            case .highestAmount: return "الأعلى مبلغًا"
            case .lowestAmount: return "الأقل مبلغًا"
            case .category: return "حسب التصنيف"
            }
        }
    }

    private(set) var allPayments: [PaymentItem] = []
    private(set) var visiblePayments: [PaymentItem] = []
    var searchText: String = "" { didSet { applyFilters() } }
    var selectedCategoryID: UUID? { didSet { applyFilters() } }
    var sortOption: SortOption = .newest { didSet { applyFilters() } }

    var visibleCount: Int { visiblePayments.count }
    var visibleTotal: Decimal { visiblePayments.reduce(0) { $0 + $1.amount } }

    func replacePayments(_ payments: [PaymentItem]) {
        allPayments = payments
        applyFilters()
    }

    func applyFilters() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = allPayments.filter { payment in
            let matchesCategory = selectedCategoryID == nil || payment.categoryID == selectedCategoryID
            guard matchesCategory else { return false }
            guard !query.isEmpty else { return true }
            return payment.title.lowercased().contains(query)
                || payment.notes.lowercased().contains(query)
                || payment.categoryName.lowercased().contains(query)
        }

        result.sort { lhs, rhs in
            switch sortOption {
            case .newest: return lhs.createdAt > rhs.createdAt
            case .oldest: return lhs.createdAt < rhs.createdAt
            case .highestAmount: return lhs.amount > rhs.amount
            case .lowestAmount: return lhs.amount < rhs.amount
            case .category:
                return lhs.categoryName.localizedCaseInsensitiveCompare(rhs.categoryName) == .orderedAscending
            }
        }
        visiblePayments = result
    }
}

struct PaymentItem {
    let id: UUID
    let amount: Decimal
    let title: String
    let notes: String
    let categoryID: UUID?
    let categoryName: String
    let createdAt: Date
    let attachmentCount: Int
}

extension Decimal {
    var sarFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SAR"
        formatter.locale = Locale(identifier: "ar_SA")
        return formatter.string(from: self as NSDecimalNumber) ?? "٠٫٠٠ ر.س"
    }
}
