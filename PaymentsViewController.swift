import UIKit

final class PaymentsViewController: UIViewController {
    private let repository: ExpenseRepository
    private let viewModel = PaymentListViewModel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let summaryLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private let sortButton = UIButton(type: .system)
    private let emptyLabel = UILabel()

    init(repository: ExpenseRepository = ExpenseRepository()) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "مدفوعات البناء"
        view.backgroundColor = .systemGroupedBackground
        configureNavigation()
        configureViews()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addPayment)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "التصنيفات",
            style: .plain,
            target: self,
            action: #selector(showCategories)
        )
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func configureViews() {
        summaryLabel.font = .preferredFont(forTextStyle: .headline)
        summaryLabel.textColor = .label
        summaryLabel.numberOfLines = 2

        sortButton.configuration = .tinted()
        sortButton.configuration?.title = "فرز: \(viewModel.sortOption.title)"
        sortButton.addTarget(self, action: #selector(changeSort), for: .touchUpInside)

        emptyLabel.text = "لا توجد مدفوعات مطابقة"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.isHidden = true

        tableView.register(PaymentCell.self, forCellReuseIdentifier: PaymentCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "ابحث في المدفوعات"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        let stack = UIStackView(arrangedSubviews: [summaryLabel, sortButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    private func reloadData() {
        do {
            viewModel.replacePayments(try repository.fetchPayments())
            tableView.reloadData()
            summaryLabel.text = "\(viewModel.visibleCount) عملية\nالمجموع: \(viewModel.visibleTotal.sarFormatted)"
            emptyLabel.isHidden = !viewModel.visiblePayments.isEmpty
        } catch {
            presentError(error)
        }
    }

    @objc private func addPayment() {
        let controller = PaymentFormViewController(repository: repository)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func showCategories() {
        navigationController?.pushViewController(CategoriesViewController(repository: repository), animated: true)
    }

    @objc private func changeSort() {
        let alert = UIAlertController(title: "فرز المدفوعات", message: nil, preferredStyle: .actionSheet)
        for option in PaymentListViewModel.SortOption.allCases {
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self] _ in
                self?.viewModel.sortOption = option
                self?.sortButton.configuration?.title = "فرز: \(option.title)"
                self?.tableView.reloadData()
                self?.summaryLabel.text = "\(self?.viewModel.visibleCount ?? 0) عملية\nالمجموع: \(self?.viewModel.visibleTotal.sarFormatted ?? "")"
            })
        }
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "حدث خطأ", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "حسنًا", style: .default))
        present(alert, animated: true)
    }
}

extension PaymentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.visiblePayments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PaymentCell.reuseIdentifier, for: indexPath) as! PaymentCell
        cell.configure(with: viewModel.visiblePayments[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // سيتم ربط هذه الخطوة بشاشة التعديل بعد إضافة fetch-by-ID إلى المستودع.
    }
}

extension PaymentsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
        tableView.reloadData()
        summaryLabel.text = "\(viewModel.visibleCount) عملية\nالمجموع: \(viewModel.visibleTotal.sarFormatted)"
        emptyLabel.isHidden = !viewModel.visiblePayments.isEmpty
    }
}

final class PaymentCell: UITableViewCell {
    static let reuseIdentifier = "PaymentCell"
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()
    private let dateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let details = UIStackView(arrangedSubviews: [titleLabel, categoryLabel, dateLabel])
        details.axis = .vertical
        details.spacing = 3
        let row = UIStackView(arrangedSubviews: [details, amountLabel])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        amountLabel.font = .preferredFont(forTextStyle: .headline)
        amountLabel.textColor = .systemGreen
        categoryLabel.font = .preferredFont(forTextStyle: .subheadline)
        categoryLabel.textColor = .secondaryLabel
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .tertiaryLabel
        titleLabel.font = .preferredFont(forTextStyle: .body)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with payment: PaymentItem) {
        titleLabel.text = payment.title
        categoryLabel.text = payment.categoryName
        amountLabel.text = payment.amount.sarFormatted
        dateLabel.text = payment.createdAt.formatted(date: .abbreviated, time: .shortened)
        accessoryType = payment.attachmentCount > 0 ? .detailButton : .none
    }
}
