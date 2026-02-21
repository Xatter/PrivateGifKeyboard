import UIKit
import UniformTypeIdentifiers

class KeyboardViewController: UIInputViewController {

    private var entries: [GifEntry] = []
    private var filteredEntries: [GifEntry] = []
    private var containerURL: URL!

    private var collectionView: UICollectionView!
    private var searchBar: UITextField!

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

        // Search bar
        searchBar = UITextField()
        searchBar.placeholder = "Search GIFs..."
        searchBar.borderStyle = .roundedRect
        searchBar.returnKeyType = .search
        searchBar.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        // Globe button to switch keyboards
        let globeButton = UIButton(type: .system)
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)),
                              for: .allTouchEvents)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(globeButton)

        // Collection view
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
            collectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    @objc private func searchTextChanged() {
        let query = searchBar.text ?? ""
        filteredEntries = GifSearchService.filter(entries: entries, query: query)
        collectionView.reloadData()
    }

    private func copyGif(_ entry: GifEntry) {
        let gifURL = containerURL.appendingPathComponent(entry.gifPath)
        try? GifPasteboardService.copyGifToPasteboard(from: gifURL)
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
        let entry = filteredEntries[indexPath.item]
        copyGif(entry)
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
