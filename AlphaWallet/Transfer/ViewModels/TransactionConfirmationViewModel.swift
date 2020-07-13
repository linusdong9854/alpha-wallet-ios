//
//  TransactionConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.07.2020.
//

import UIKit
import BigInt

class TransactionConfirmationViewModel: ConfirmationViewModelType {

    private let session: WalletSession
    private let transaction: PreviewTransaction
    private let currentBalance: BalanceProtocol?
    private let currencyRate: CurrencyRate?
    private let server: RPCServer
    private let fullFormatter = EtherNumberFormatter.full
    private let account: EthereumAccount
    private let ensName: String?

    private var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    private var totalFee: BigInt {
        return transaction.gasPrice * transaction.gasLimit
    }

    private var gasLimit: BigInt {
        return transaction.gasLimit
    }

    func addressReplacedWithESN(_ ensName: String? = nil) -> String {
        return account.address.addressReplacedWithESN(ensName)
    }

    init(
        transaction: PreviewTransaction,
        server: RPCServer,
        currentBalance: BalanceProtocol?,
        currencyRate: CurrencyRate?,
        session: WalletSession,
        account: EthereumAccount,
        ensName: String?
    ) {
        self.account = account
        self.session = session
        self.transaction = transaction
        self.currentBalance = currentBalance
        self.server = server
        self.currencyRate = currencyRate
        self.ensName = ensName
    }

    private var gasPriceText: String {
        let unit = UnitConfiguration.gasPriceUnit
        let amount = fullFormatter.string(from: transaction.gasPrice, units: UnitConfiguration.gasPriceUnit)

        return String(format: "%@ %@", amount, unit.name)
    }

    private var feeText: String {
        let feeAndSymbol = gasViewModel.feeText
        let warningFee = BigInt(EthereumUnit.ether.rawValue) / BigInt(20)
        guard totalFee <= warningFee else {
            return R.string.localizable.confirmPaymentHighFeeWarning(feeAndSymbol)
        }

        return feeAndSymbol
    }

    var amountTextColor: UIColor {
        return Colors.red
    }

    func shouldHideExpandButton(section: Int) -> Bool {
        return numberOfRows(in: section) == 0
    }

    var amountAttributedString: NSAttributedString {
        switch transaction.transferType {
        case .ERC20Token(let token, _, _):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .nativeCryptocurrency, .dapp:
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value)
            )
        case .ERC875Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC875TokenOrder(let token):
            return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721ForTicketToken(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        }
    }

    private func amountAttributedText(string: String) -> NSAttributedString {
        let amount = NSAttributedString(
            string: amountWithSign(for: string),
            attributes: [
                .font: Fonts.regular(size: 28) as Any,
                .foregroundColor: amountTextColor,
            ]
        )

        let currency = NSAttributedString(
            string: " \(transaction.transferType.symbol)",
            attributes: [
                .font: Fonts.regular(size: 20) as Any,
            ]
        )

        return amount + currency
    }

    private func amountWithSign(for amount: String) -> String {
        guard amount != "0" else { return amount }
        return "-\(amount)"
    }

    func title(indexPath: IndexPath) -> TransactionRowInfoTableViewCellViewModel {
        switch sections[indexPath.section] {
        case .balance:
            switch balanceSectionRows[indexPath.row] {
            case .address:
                return .init(title: R.string.localizable.confirmPaymentFromLabelTitle(), subTitle: session.account.address.eip55String)
            }
        case .gas:
            switch gasSectionRows[indexPath.row] {
            case .gasLimit:
                return .init(title: R.string.localizable.confirmPaymentGasLimitLabelTitle(), subTitle: gasLimit.description)
            case .gasPrice:
                return .init(title: R.string.localizable.confirmPaymentGasPriceLabelTitle(), subTitle: gasPriceText)
            case .fee:
                return .init(title: R.string.localizable.confirmPaymentGasFeeLabelTitle(), subTitle: feeText)
            case .data:
                return .init(title: R.string.localizable.confirmPaymentDataLabelTitle(), subTitle: transaction.data.description)
            case .nonce:
                return .init(title: R.string.localizable.confirmPaymentNonceLabelTitle(), subTitle: transaction.nonce.description)
            }
        case .recipient:
            switch recipientSectionRows[indexPath.row] {
            case .recipient:
                return .init(title: "Wallet Address", subTitle: transaction.address?.description ?? "--")
            case .ens:
                return .init(title: "Blockie & ENS", subTitle: transaction.address?.addressReplacedWithESN(ensName))
            }
        case .amount:
            return .init(title: "", subTitle: "")
        }
    }

    var sections: [ConfirmPaymentSection] = ConfirmPaymentSection.allCases
    var openedSections = Set<Int>()

    func numberOfRows(in section: Int) -> Int {
        let isOpened = openedSections.contains(section)

        switch sections[section] {
        case .balance:
            return isOpened ? balanceSectionRows.count : 0
        case .gas:
            return isOpened ? gasSectionRows.count : 0
        case .recipient:
            return isOpened ? recipientSectionRows.count : 0
        case .amount:
            return 0
        }
    }

    func indexPaths(for section: Int) -> [IndexPath] {
        switch sections[section] {
        case .balance:
            return balanceSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .gas:
            return gasSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .recipient:
            return recipientSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .amount:
            return []
        }
    }

    var numberOfSections: Int {
        return sections.count
    }

    private var balanceSectionRows: [BalanceSectionRow] {
        return BalanceSectionRow.allCases
    }

    private var gasSectionRows: [GasSectionRow] {
        if transaction.nonce > -1 {
            return GasSectionRow.allCases
        } else {
            return [.gasLimit, .gasPrice, .fee, .data]
        }
    }

    private var recipientSectionRows: [RecipientSectionRow] {
        if ensName != nil {
            return RecipientSectionRow.allCases
        } else {
            return [.recipient]
        }
    }
}

private enum BalanceSectionRow: Int, CaseIterable {
    case address
}

private enum GasSectionRow: Int, CaseIterable {
    case gasLimit
    case gasPrice
    case fee
    case data
    case nonce
}

private enum RecipientSectionRow: Int, CaseIterable {
    case recipient
    case ens
}

struct TransactionRowInfoTableViewCellViewModel {
    let title: String
    let subTitle: String?
}

enum ConfirmPaymentSection: Int, CaseIterable {
    case balance
    case recipient
    case gas
    case amount

    var title: String {
        switch self {
        case .balance:
            return "Balance"
        case .recipient:
            return "Recipient"
        case .gas:
            return "Speed (Gas)"
        case .amount:
            return "Amount"
        }
    }
}

