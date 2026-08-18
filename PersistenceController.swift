import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "HouseExpenses", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { [weak self] _, error in
            if let error { fatalError("Core Data store failed: \\(error)") }
            self?.seedDefaultCategoriesIfNeeded()
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
    }

    private func seedDefaultCategoriesIfNeeded() {
        let request = NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
        request.fetchLimit = 1
        guard (try? container.viewContext.count(for: request)) == 0 else { return }
        let names = ["مواد بناء", "عمالة", "كهرباء", "سباكة", "أثاث", "أخرى"]
        names.forEach { name in
            let category = CategoryEntity(context: container.viewContext)
            category.id = UUID()
            category.name = name
            category.createdAt = Date()
        }
        try? save()
    }

    func save() throws {
        let context = container.viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let payment = NSEntityDescription()
        payment.name = "PaymentEntity"
        payment.managedObjectClassName = "PaymentEntity"
        payment.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("amount", .decimalAttributeType, optional: false),
            attribute("title", .stringAttributeType, optional: false),
            attribute("notes", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType, optional: false)
        ]

        let category = NSEntityDescription()
        category.name = "CategoryEntity"
        category.managedObjectClassName = "CategoryEntity"
        category.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("name", .stringAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false)
        ]

        let attachment = NSEntityDescription()
        attachment.name = "AttachmentEntity"
        attachment.managedObjectClassName = "AttachmentEntity"
        attachment.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("fileName", .stringAttributeType, optional: false),
            attribute("fileType", .stringAttributeType, optional: false),
            attribute("relativePath", .stringAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false)
        ]

        let paymentCategory = NSRelationshipDescription()
        paymentCategory.name = "category"
        paymentCategory.destinationEntity = category
        paymentCategory.minCount = 0
        paymentCategory.maxCount = 1
        paymentCategory.deleteRule = .nullifyDeleteRule

        let categoryPayments = NSRelationshipDescription()
        categoryPayments.name = "payments"
        categoryPayments.destinationEntity = payment
        categoryPayments.minCount = 0
        categoryPayments.maxCount = 0
        categoryPayments.deleteRule = .nullifyDeleteRule
        paymentCategory.inverseRelationship = categoryPayments
        categoryPayments.inverseRelationship = paymentCategory
        payment.properties.append(paymentCategory)
        category.properties.append(categoryPayments)

        let attachmentPayment = NSRelationshipDescription()
        attachmentPayment.name = "payment"
        attachmentPayment.destinationEntity = payment
        attachmentPayment.minCount = 0
        attachmentPayment.maxCount = 1
        attachmentPayment.deleteRule = .cascadeDeleteRule
        let paymentAttachments = NSRelationshipDescription()
        paymentAttachments.name = "attachments"
        paymentAttachments.destinationEntity = attachment
        paymentAttachments.minCount = 0
        paymentAttachments.maxCount = 0
        paymentAttachments.deleteRule = .cascadeDeleteRule
        attachmentPayment.inverseRelationship = paymentAttachments
        paymentAttachments.inverseRelationship = attachmentPayment
        payment.properties.append(paymentAttachments)
        attachment.properties.append(attachmentPayment)

        model.entities = [payment, category, attachment]
        return model
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let item = NSAttributeDescription()
        item.name = name
        item.attributeType = type
        item.isOptional = optional
        return item
    }
}

@objc(PaymentEntity)
final class PaymentEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var amount: Decimal
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var createdAt: Date
    @NSManaged var category: CategoryEntity?
    @NSManaged var attachments: NSSet?
}

@objc(CategoryEntity)
final class CategoryEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var payments: NSSet?
}

@objc(AttachmentEntity)
final class AttachmentEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var fileName: String
    @NSManaged var fileType: String
    @NSManaged var relativePath: String
    @NSManaged var createdAt: Date
    @NSManaged var payment: PaymentEntity?
}
