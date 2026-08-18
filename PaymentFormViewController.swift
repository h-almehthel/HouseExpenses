import UIKit
import UniformTypeIdentifiers
import PhotosUI

final class PaymentFormViewController: UIViewController {
    private let repository: ExpenseRepository
    private let existingPayment: PaymentEntity?
    private let amountField = UITextField()
    private let titleField = UITextField()
    private let notesField = UITextView()
    private let categoryButton = UIButton(type: .system)
    private let dateLabel = UILabel()
    private let attachmentsLabel = UILabel()
    private var categories: [CategoryEntity] = []
    private var selectedCategory: CategoryEntity?
    private var pendingAttachments: [SavedAttachment] = []

    init(repository: ExpenseRepository, payment: PaymentEntity? = nil) {
        self.repository = repository
        self.existingPayment = payment
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingPayment == nil ? "إضافة دفعة" : "تعديل الدفعة"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "حفظ", style: .done, target: self, action: #selector(save))
        configureForm()
        loadValues()
    }

    private func configureForm() {
        amountField.placeholder = "المبلغ بالريال السعودي"
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect
        titleField.placeholder = "وصف الدفعة"
        titleField.borderStyle = .roundedRect
        notesField.layer.borderWidth = 1
        notesField.layer.borderColor = UIColor.separator.cgColor
        notesField.layer.cornerRadius = 8
        notesField.font = .preferredFont(forTextStyle: .body)
        notesField.text = "ملاحظات اختيارية"
        notesField.textColor = .secondaryLabel
        categoryButton.configuration = .tinted()
        categoryButton.configuration?.title = "اختيار التصنيف"
        categoryButton.addTarget(self, action: #selector(selectCategory), for: .touchUpInside)
        dateLabel.textColor = .secondaryLabel
        attachmentsLabel.text = "المرفقات: يمكن إضافة صور أو ملفات PDF"
        attachmentsLabel.textColor = .secondaryLabel
        attachmentsLabel.numberOfLines = 0

        let addAttachment = UIButton(type: .system)
        addAttachment.configuration = .tinted()
        addAttachment.configuration?.title = "إضافة مرفق"
        addAttachment.addTarget(self, action: #selector(addAttachment), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [amountField, titleField, categoryButton, dateLabel, notesField, attachmentsLabel, addAttachment])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            notesField.heightAnchor.constraint(equalToConstant: 110)
        ])
    }

    private func loadValues() {
        do { categories = try repository.fetchCategories() } catch { presentError(error) }
        if let payment = existingPayment {
            amountField.text = NSDecimalNumber(decimal: payment.amount).stringValue
            titleField.text = payment.title
            notesField.text = payment.notes ?? ""
            notesField.textColor = .label
            selectedCategory = payment.category
            categoryButton.configuration?.title = payment.category?.name ?? "بدون تصنيف"
            dateLabel.text = "تاريخ الإضافة: \(payment.createdAt.formatted(date: .long, time: .shortened))"
        } else {
            dateLabel.text = "سيُحفظ التاريخ تلقائيًا عند الإضافة"
        }
    }

    @objc private func selectCategory() {
        let alert = UIAlertController(title: "التصنيف", message: nil, preferredStyle: .actionSheet)
        for category in categories {
            alert.addAction(UIAlertAction(title: category.name, style: .default) { [weak self] _ in
                self?.selectedCategory = category
                self?.categoryButton.configuration?.title = category.name
            })
        }
        alert.addAction(UIAlertAction(title: "بدون تصنيف", style: .default) { [weak self] _ in
            self?.selectedCategory = nil
            self?.categoryButton.configuration?.title = "بدون تصنيف"
        })
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func addAttachment() {
        let alert = UIAlertController(title: "مصدر المرفق", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "الكاميرا", style: .default) { [weak self] _ in self?.openCamera() })
        }
        alert.addAction(UIAlertAction(title: "مكتبة الصور", style: .default) { [weak self] _ in self?.openPhotoLibrary() })
        alert.addAction(UIAlertAction(title: "ملف PDF", style: .default) { [weak self] _ in self?.openPDFPicker() })
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        present(alert, animated: true)
    }

    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openPhotoLibrary() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openPDFPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func save() {
        guard let amountText = amountField.text, let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            presentErrorMessage("أدخل مبلغًا صحيحًا أكبر من صفر.")
            return
        }
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            presentErrorMessage("أدخل وصف الدفعة.")
            return
        }
        do {
            let notes = notesField.text == "ملاحظات اختيارية" ? nil : notesField.text
            let payment: PaymentEntity
            if let existingPayment {
                try repository.updatePayment(existingPayment, amount: amount, title: title, notes: notes, category: selectedCategory)
                payment = existingPayment
            } else {
                payment = try repository.addPayment(amount: amount, title: title, notes: notes, category: selectedCategory)
            }
            for attachment in pendingAttachments {
                try repository.addAttachment(attachment, to: payment)
            }
            navigationController?.popViewController(animated: true)
        } catch { presentError(error) }
    }

    private func presentError(_ error: Error) { presentErrorMessage(error.localizedDescription) }
    private func presentErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "تعذر الحفظ", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسنًا", style: .default))
        present(alert, animated: true)
    }
}

extension PaymentFormViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            do {
                pendingAttachments.append(try AttachmentManager.shared.saveImage(image))
                attachmentsLabel.text = "تمت إضافة \(pendingAttachments.count) مرفق"
            } catch { presentError(error) }
        }
    }
}

extension PaymentFormViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let error { self?.presentError(error); return }
                guard let image = object as? UIImage else { return }
                do {
                    self?.pendingAttachments.append(try AttachmentManager.shared.saveImage(image))
                    self?.attachmentsLabel.text = "تمت إضافة \(self?.pendingAttachments.count ?? 0) مرفق"
                } catch { self?.presentError(error) }
            }
        }
    }
}

extension PaymentFormViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            pendingAttachments.append(try AttachmentManager.shared.savePDF(from: url))
            attachmentsLabel.text = "تمت إضافة \(pendingAttachments.count) مرفق"
        } catch { presentError(error) }
    }
}
