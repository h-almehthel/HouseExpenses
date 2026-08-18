import UIKit

final class CategoriesViewController: UITableViewController {
    private let repository: ExpenseRepository
    private var categories: [CategoryEntity] = []

    init(repository: ExpenseRepository) {
        self.repository = repository
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "التصنيفات"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCategory))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        reloadCategories()
    }

    private func reloadCategories() {
        do {
            categories = try repository.fetchCategories()
            tableView.reloadData()
        } catch { showError(error.localizedDescription) }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { categories.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = categories[indexPath.row].name
        content.secondaryText = "\((categories[indexPath.row].payments as? Set<PaymentEntity>)?.count ?? 0) مدفوعات"
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        editCategory(categories[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        do {
            try repository.deleteCategory(categories[indexPath.row])
            reloadCategories()
        } catch { showError(error.localizedDescription) }
    }

    @objc private func addCategory() {
        promptForCategory(title: "تصنيف جديد", category: nil)
    }

    private func editCategory(_ category: CategoryEntity) {
        promptForCategory(title: "تعديل التصنيف", category: category)
    }

    private func promptForCategory(title: String, category: CategoryEntity?) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "اسم التصنيف"
            field.text = category?.name
        }
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        alert.addAction(UIAlertAction(title: "حفظ", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            do {
                if let category { try self.repository.updateCategory(category, name: name) }
                else { _ = try self.repository.addCategory(name: name) }
                self.reloadCategories()
            } catch { self.showError(error.localizedDescription) }
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "حدث خطأ", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسنًا", style: .default))
        present(alert, animated: true)
    }
}
