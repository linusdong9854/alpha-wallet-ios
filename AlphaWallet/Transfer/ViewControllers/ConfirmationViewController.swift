// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit
import StackViewController
import Result

class ConfirmationViewController: UIViewController, UpdatablePreferredContentSize {
    lazy var buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: ConfirmationViewModelType

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.registerHeaderFooterView(ConfirmationTableHeaderView.self)
        tableView.separatorStyle = .none
        
        return tableView
    }()

    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonsBar)

        return view
    }()

    private var contentSizeObservation: NSKeyValueObservation!
    private let footerHeight: CGFloat = ScreenChecker().isNarrowScreen ? 80 : 120
    private let separatorHeight: CGFloat = 1.0
    private var contentSize: CGSize {
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let contantHeight = tableView.contentSize.height + footerHeight + separatorHeight
        let height = min(UIScreen.main.bounds.height - statusBarHeight, contantHeight)
        return CGSize(width: UIScreen.main.bounds.width, height: height)
    }

    //NOTE: we are using flag to disable animation until first UITableView open/hide action
    var updatePreferredContentSizeAnimated: Bool = false

    init(viewModel: ConfirmationViewModelType) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        view.addSubview(separatorLine)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: ScreenChecker().isNarrowScreen ? 10 : 20),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            separatorLine.heightAnchor.constraint(equalToConstant: 1.0),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem.appIconBarButton
        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dismissViewController))

        let button = buttonsBar.buttons[0]
        button.addTarget(self, action: #selector(confirmationButtonSelected), for: .touchUpInside)

        let trottler = Throttler(minimumDelay: 0.05)

        //NOTE: we observe UITableView.contentSize to determine view controller height.
        //we are using Throttler because during UITableViewUpdate procces contentSize changes with range of values, so we need latest valid value.
        contentSizeObservation = tableView.observe(\.contentSize, options: [.new, .initial]) { [weak self] _, _ in
            trottler.throttle {
                guard let strongSelf = self, let controller = strongSelf.navigationController else { return }
                controller.preferredContentSize = strongSelf.contentSize
            }
        } 
    }

    deinit {
        contentSizeObservation.invalidate()
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }

    func configure(for viewModel: ConfirmationViewModelType) {
        buttonsBar.configure()

        title = viewModel.navigationTitle
        footerBar.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.navigationTitle

        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.confirmButtonTitle, for: .normal)

        tableView.reloadData()
    }

    @objc func confirmationButtonSelected() {

    }
    
    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ConfirmationViewController: UITableViewDelegate {

}

extension ConfirmationViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}

extension ConfirmationViewController: ConfirmationTableHeaderViewDelegate {

    func headerView(_ header: ConfirmationTableHeaderView, didSelectExpand sender: UIButton, section: Int) {
        updatePreferredContentSizeAnimated = true

        if !viewModel.openedSections.contains(section) {
            viewModel.openedSections.insert(section)

            tableView.insertRows(at: viewModel.indexPaths(for: section), with: .none)
        } else {
            viewModel.openedSections.remove(section)

            tableView.deleteRows(at: viewModel.indexPaths(for: section), with: .none)
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
}

extension UIBarButtonItem {

    static var appIconBarButton: UIBarButtonItem {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.awLogoSmall()
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.anchorsConstraint(to: container)
        ])

        return UIBarButtonItem(customView: container)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }

    static func cancelBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(title: R.string.localizable.cancel(), style: .plain, target: target, action: selector)
    }
}
