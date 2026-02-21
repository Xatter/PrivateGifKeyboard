import UIKit
import UniformTypeIdentifiers

class KeyboardViewController: UIInputViewController {

    private var entries: [GifEntry] = []
    private var filteredEntries: [GifEntry] = []
    private var containerURL: URL!

    private var collectionView: UICollectionView!
    private var searchBar: UITextField!
    private var inlineKeyboardView: UIView!

    private let keyRows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M","⌫"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.extroverteddeveloper.GifKeyboard.shared"
        ) ?? FileManager.default.temporaryDirectory

        loadIndex()
        setupUI()
    }

    // MARK: - Data

    private func loadIndex() {
        let store = GifIndexStore(containerURL: containerURL)
        entries = ((try? store.load()) ?? [])
            .sorted { $0.dateAdded > $1.dateAdded }
        filteredEntries = entries
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let view = view else { return }
        view.backgroundColor = .systemBackground

        // Globe button
        let globeButton = UIButton(type: .system)
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)),
                              for: .allTouchEvents)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(globeButton)

        // Search bar — inputView = UIView() suppresses the system keyboard
        searchBar = UITextField()
        searchBar.placeholder = "Search GIFs..."
        searchBar.borderStyle = .roundedRect
        searchBar.inputView = UIView()
        searchBar.clearButtonMode = .whileEditing
        searchBar.delegate = self
        searchBar.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        // GIF grid
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GifCell.self, forCellWithReuseIdentifier: GifCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        // Inline keyboard (hidden until search bar is tapped)
        inlineKeyboardView = buildKeyboardView()
        inlineKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        inlineKeyboardView.isHidden = true
        view.addSubview(inlineKeyboardView)

        NSLayoutConstraint.activate([
            globeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            globeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            globeButton.widthAnchor.constraint(equalToConstant: 32),
            globeButton.heightAnchor.constraint(equalToConstant: 32),

            searchBar.leadingAnchor.constraint(equalTo: globeButton.trailingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchBar.heightAnchor.constraint(equalToConstant: 36),

            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),

            inlineKeyboardView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            inlineKeyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inlineKeyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inlineKeyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildKeyboardView() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 6
        outerStack.distribution = .fillEqually
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(outerStack)

        for row in keyRows {
            outerStack.addArrangedSubview(makeKeyRow(row))
        }
        outerStack.addArrangedSubview(makeBottomRow())

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            outerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            outerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            outerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        return container
    }

    private func makeKeyRow(_ keys: [String]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 5
        row.distribution = .fillEqually

        for key in keys {
            let btn = makeKeyButton(title: key)
            if key == "⌫" {
                btn.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
            } else {
                btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            }
            row.addArrangedSubview(btn)
        }
        return row
    }

    private func makeBottomRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 5

        let spaceBtn = makeKeyButton(title: "space")
        spaceBtn.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let doneBtn = makeKeyButton(title: "done")
        doneBtn.backgroundColor = .systemBlue
        doneBtn.setTitleColor(.white, for: .normal)
        doneBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        row.addArrangedSubview(spaceBtn)
        row.addArrangedSubview(doneBtn)
        return row
    }

    private func makeKeyButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        btn.backgroundColor = .secondarySystemBackground
        btn.layer.cornerRadius = 5
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 0
        return btn
    }

    // MARK: - Key Actions

    @objc private func keyTapped(_ sender: UIButton) {
        guard let key = sender.title(for: .normal) else { return }
        searchBar.insertText(key.lowercased())
        searchTextChanged()
    }

    @objc private func backspaceTapped() {
        guard let text = searchBar.text, !text.isEmpty else { return }
        searchBar.text = String(text.dropLast())
        searchTextChanged()
    }

    @objc private func spaceTapped() {
        searchBar.insertText(" ")
        searchTextChanged()
    }

    @objc private func doneTapped() {
        dismissSearch()
    }

    // MARK: - Search Mode

    private func activateSearch() {
        collectionView.isHidden = true
        inlineKeyboardView.isHidden = false
    }

    private func dismissSearch() {
        searchBar.resignFirstResponder()
        inlineKeyboardView.isHidden = true
        collectionView.isHidden = false
    }

    @objc private func searchTextChanged() {
        let query = searchBar.text ?? ""
        filteredEntries = GifSearchService.filter(entries: entries, query: query)
        collectionView.reloadData()
    }

    // MARK: - Copy GIF

    private func copyGif(_ entry: GifEntry) {
        let gifURL = containerURL.appendingPathComponent(entry.gifPath)
        try? GifPasteboardService.copyGifToPasteboard(from: gifURL)
        dismissSearch()
        showCopiedToast()
    }

    private func showCopiedToast() {
        let toast = UILabel()
        toast.text = "Copied! Long press in message field to paste"
        toast.font = .systemFont(ofSize: 13, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            toast.heightAnchor.constraint(equalToConstant: 36),
        ])
        toast.layoutIfNeeded()
        toast.widthAnchor.constraint(equalToConstant: toast.intrinsicContentSize.width + 24).isActive = true

        UIView.animate(withDuration: 0.2, delay: 2.0, options: [], animations: {
            toast.alpha = 0
        }, completion: { _ in toast.removeFromSuperview() })
    }
}

// MARK: - UITextFieldDelegate

extension KeyboardViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        activateSearch()
        return true
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredEntries.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GifCell.reuseID, for: indexPath) as! GifCell
        let entry = filteredEntries[indexPath.item]
        let thumbURL = containerURL.appendingPathComponent(entry.thumbnailPath)
        cell.configure(with: thumbURL)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        copyGif(filteredEntries[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 4
        let spacing: CGFloat = 4
        let totalSpacing = spacing * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }
}

// MARK: - GifCell

private final class GifCell: UICollectionViewCell {
    static let reuseID = "GifCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with thumbnailURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: thumbnailURL),
                  let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}
