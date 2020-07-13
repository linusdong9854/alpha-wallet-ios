// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol ConfirmationViewModelType: class {
    var confirmButtonTitle: String { get }
    var navigationTitle: String { get }
    var backgroundColor: UIColor { get }
    var openedSections: Set<Int> { get set }
    var numberOfSections: Int { get }

    func indexPaths(for section: Int) -> [IndexPath]
    func numberOfRows(in section: Int) -> Int
}

extension ConfirmationViewModelType {

    var confirmButtonTitle: String {
        return "Confirm"
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return "Confirm Transaction"
    }
}
