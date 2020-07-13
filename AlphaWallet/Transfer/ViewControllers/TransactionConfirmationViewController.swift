//
//  TransactionConfirmationViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.07.2020.
//

import BigInt
import Foundation
import UIKit
import StackViewController
import Result

enum ConfirmType {
    case sign
    case signThenSend
}

enum ConfirmResult {
    case signedTransaction(Data)
    case sentTransaction(SentTransaction)
}

class TransactionConfirmationViewController: ConfirmationViewController {

    private let account: EthereumAccount
    private let keystore: Keystore
    private let session: WalletSession
    private lazy var sendTransactionCoordinator = SendTransactionCoordinator(session: session, keystore: keystore, confirmType: confirmType)
    private var viewModel: TransactionConfirmationViewModel
    private var ensName: String?
    private var configurator: TransactionConfigurator
    private let confirmType: ConfirmType

    var didCompleted: ((Result<ConfirmResult, AnyError>) -> Void)?
    //    private let loadingIndicatorView: CircularProgressView = {
    //        let view = CircularProgressView()
    //        view.translatesAutoresizingMaskIntoConstraints = false
    //        return view
    //    }()
    
    init(session: WalletSession, keystore: Keystore, configurator: TransactionConfigurator, confirmType: ConfirmType, account: EthereumAccount) {
        self.account = account
        self.session = session
        self.keystore = keystore
        self.configurator = configurator
        self.confirmType = confirmType
        let viewModel = TransactionConfirmationViewModel(
            transaction: configurator.previewTransaction(),
            server: session.server,
            currentBalance: session.balance,
            currencyRate: session.balanceCoordinator.currencyRate,
            session: session,
            account: account,
            ensName: ensName
        )

        self.viewModel = viewModel
        super.init(viewModel: viewModel)

        //        buttonsBar.isHidden = true
        //        footerBar.addSubview(loadingIndicatorView)

        NSLayoutConstraint.activate([
        //            loadingIndicatorView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
        //            loadingIndicatorView.centerXAnchor.constraint(equalTo: footerBar.centerXAnchor),
        //            loadingIndicatorView.widthAnchor.constraint(equalToConstant: 50),
        //            loadingIndicatorView.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TransactionRowInfoTableViewCell.self)

        configurator.load { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                strongSelf.reloadView()
            case .failure(let error):
                strongSelf.displayError(error: error)
            }
        }

        configurator.configurationUpdate.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.reloadView()
        }
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        loadingIndicatorView.progressAnimation(5)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        loadingIndicatorView.layoutIfNeeded()
    }

    private func reloadView() {
        let viewModel = TransactionConfirmationViewModel(
            transaction: configurator.previewTransaction(),
            server: session.server,
            currentBalance: session.balance,
            currencyRate: session.balanceCoordinator.currencyRate,
            session: session,
            account: account,
            ensName: ensName
        )

        configure(for: viewModel)
    }

    override func confirmationButtonSelected() {
        displayLoading()

        let transaction = configurator.formUnsignedTransaction()
        sendTransactionCoordinator.send(transaction: transaction) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.didCompleted?(result)
            strongSelf.hideLoading()
            strongSelf.showFeedbackOnSuccess(result)
        }
    }

    private func showFeedbackOnSuccess(_ result: Result<ConfirmResult, AnyError>) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        switch result {
        case .success:
            //Hackish, but delay necessary because of the switch to and from user-presence for signing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                //TODO sound too
                feedbackGenerator.notificationOccurred(.success)
            }
        case .failure:
            break
        }
    }

    @objc func edit() {
        let controller = ConfigureTransactionViewController(
            configuration: configurator.configuration,
            transferType: configurator.transaction.transferType,
            server: session.server,
            currencyRate: session.balanceCoordinator.currencyRate
        )
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension TransactionConfirmationViewController: ConfigureTransactionViewControllerDelegate {
    func didEdit(configuration: TransactionConfiguration, in viewController: ConfigureTransactionViewController) {
        configurator.update(configuration: configuration)
        reloadView()

        navigationController?.popViewController(animated: true)
    }
}

extension TransactionConfirmationViewController {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        //FIXME: remove later
        switch viewModel.sections[indexPath.section] {
        case .gas:
            edit()
        case .amount, .balance, .recipient:
            break
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TransactionRowInfoTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.title(indexPath: indexPath))

        return cell
    }

    private func configureTransactionTableViewHeaderWithResolvedESN(_ section: Int, header: ConfirmationTableHeaderView) {
        header.delegate = self
        header.configure(viewModel: .init(
            title: viewModel.addressReplacedWithESN(ensName),
            placeholder: viewModel.sections[section].title,
            isOpened: viewModel.openedSections.contains(section),
            section: section
        ))

//        //FIXME: Replace later with resolving ENS name
//
//        guard ensName == nil else { return }
//
//        let serverToResolveEns = RPCServer.main
//        let address = account.address
//
//        ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
//            guard let strongSelf = self else { return }
//            strongSelf.ensName = result.value
//
//            header.configure(viewModel: .init(
//                title: strongSelf.viewModel.addressReplacedWithESN(result.value),
//                placeholder: placeholder,
//                isOpened: isOpened,
//                section: section
//            ))
//        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isOpened = viewModel.openedSections.contains(section)
        let placeholder = viewModel.sections[section].title

        switch viewModel.sections[section] {
        case .recipient:
            let header: ConfirmationTableHeaderView = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            configureTransactionTableViewHeaderWithResolvedESN(section, header: header)

            return header
        case .balance, .gas:
            let header: ConfirmationTableHeaderView = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            header.configure(viewModel: .init(
                title: "Default",
                placeholder: placeholder,
                isOpened: isOpened,
                section: section
            ))

            return header
        case .amount:
            let header: ConfirmationTableHeaderView = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            header.configure(viewModel: .init(
                title: viewModel.amountAttributedString.string,
                placeholder: placeholder,
                isOpened: isOpened,
                section: section,
                shouldHideExpandButton: viewModel.shouldHideExpandButton(section: section)
            ))

            return header
        }
    }
}
