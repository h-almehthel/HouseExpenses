import CoreData

final class ExpenseRepository {
    private let persistence: PersistenceController
    private var context: NSManagedObjectContext { persistence.container.viewContext }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchPayments() throws -> [PaymentItem] {
        let request = NSFetchRequest<PaymentEntity>(entityName: "PaymentEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try context.fetch(request).map { payment in
            PaymentItem(
                id: payment.id,
                amount: payment.amount,
                title: payment.title,
                notes: payment.notes ?? "",
                categoryID: payment.category?.id,
                categoryName: payment.category?.name ?? "بدون تصنيف",
                createdAt: payment.createdAt,
                attachmentCount: (payment.attachments as? Set<AttachmentEntity>)?.count ?? 0
            )
        }
    }

    @discardableResult
    func addPayment(amount: Decimal, title: String, notes: String?, category: CategoryEntity?) throws -> PaymentEntity {
        let payment = PaymentEntity(context: context)
        payment.id = UUID()
        payment.amount = amount
        payment.title = title
        payment.notes = notes
        payment.createdAt = Date()
        payment.category = category
        try persistence.save()
        return payment
    }

    func updatePayment(_ payment: PaymentEntity, amount: Decimal, title: String, notes: String?, category: CategoryEntity?) throws {
        payment.amount = amount
        payment.title = title
        payment.notes = notes
        payment.category = category
        try persistence.save()
    }

    func deletePayment(_ payment: PaymentEntity) throws {
        if let attachments = payment.attachments as? Set<AttachmentEntity> {
            attachments.forEach { AttachmentManager.shared.delete(relativePath: $0.relativePath) }
        }
        context.delete(payment)
        try persistence.save()
    }

    func addAttachment(_ saved: SavedAttachment, to payment: PaymentEntity) throws {
        let attachment = AttachmentEntity(context: context)
        attachment.id = UUID()
        attachment.fileName = saved.fileName
        attachment.fileType = saved.fileType
        attachment.relativePath = saved.relativePath
        attachment.createdAt = Date()
        attachment.payment = payment
        try persistence.save()
    }

    func fetchCategories() throws -> [CategoryEntity] {
        let request = NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(request)
    }

    @discardableResult
    func addCategory(name: String) throws -> CategoryEntity {
        let category = CategoryEntity(context: context)
        category.id = UUID()
        category.name = name
        category.createdAt = Date()
        try persistence.save()
        return category
    }

    func updateCategory(_ category: CategoryEntity, name: String) throws {
        category.name = name
        try persistence.save()
    }

    func deleteCategory(_ category: CategoryEntity) throws {
        guard (category.payments as? Set<PaymentEntity>)?.isEmpty ?? true else {
            throw RepositoryError.categoryHasPayments
        }
        context.delete(category)
        try persistence.save()
    }

    func category(with id: UUID?) throws -> CategoryEntity? {
        guard let id else { return nil }
        let request = NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

enum RepositoryError: LocalizedError {
    case categoryHasPayments

    var errorDescription: String? {
        switch self {
        case .categoryHasPayments:
            return "لا يمكن حذف تصنيف مرتبط بمدفوعات. انقل المدفوعات إلى تصنيف آخر أولًا."
        }
    }
}
