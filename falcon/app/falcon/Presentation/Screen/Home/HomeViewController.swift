//
//  HomeViewController.swift
//  falcon
//
//  Created by Manu Herrera on 05/12/2018.
//  Copyright © 2018 muun. All rights reserved.
//

import UIKit
import core

class HomeViewController: MUViewController {

    fileprivate lazy var presenter = instancePresenter(HomePresenter.init, delegate: self)

    private var homeView: HomeView!

    override var screenLoggingName: String {
        return "home"
    }

    override func customLoggingParameters() -> [String: Any]? {
        return ["type": presenter.logType()]
    }

    override func loadView() {
        super.loadView()

        homeView = HomeView(delegate: self)
        self.view = homeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Asset.Colors.cellBackground.color

        makeViewTestable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        additionalSafeAreaInsets = UIEdgeInsets.zero
        setUpNavigation()
        populateView()

        presenter.setUp()

        if presenter.shouldDisplayTransactionListTooltip() {
            homeView.displayTooltip()
        } else {
            homeView.hideTooltip()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.tearDown()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if presenter.shouldDisplayWelcomeMessage() {
            presentWelcomePopUp()
        }
    }

    private func populateView() {
        populateBalanceView()
        decideBackUpCTA()
        homeView.updateBalanceAndChevron(state: presenter.getOperationsState())
    }

    fileprivate func setUpNavigation() {
        navigationController!.setNavigationBarHidden(false, animated: true)
        navigationController!.hideSeparator()

        setUpRightButtonItems()
        setUpLeftButtonItems()
    }

    fileprivate func setUpRightButtonItems() {

        let supportButton = UIBarButtonItem(
            image: Asset.Assets.feedback.image,
            style: .plain,
            target: self,
            action: .supportTouched
        )

        self.navigationItem.rightBarButtonItems = [supportButton]
    }

    fileprivate func setUpLeftButtonItems() {
        let label = UILabel()
        label.text = "Muun"
        label.textAlignment = .left
        label.font = Constant.Fonts.system(size: .homeCurrency, weight: .medium)
        label.textColor = Asset.Colors.title.color

        self.navigationItem.leftBarButtonItems = [UIBarButtonItem(customView: label)]
    }

    @objc fileprivate func supportTouched() {
        let navController = UINavigationController()

        if !presenter.hasEmailAndPassword() {
            navController.viewControllers = [SupportViewController(type: .anonSupport)]
            present(navController, animated: true)
        } else {
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            actionSheet.addAction(UIAlertAction(title: L10n.HomeViewController.s1, style: .default, handler: { _ in

                navController.viewControllers = [SupportViewController(type: .help)]
                self.present(navController, animated: true)
            }))
            actionSheet.addAction(UIAlertAction(title: L10n.HomeViewController.s2, style: .default, handler: { _ in
                navController.viewControllers = [SupportViewController(type: .feedback)]
                self.present(navController, animated: true)
            }))

            actionSheet.addAction(UIAlertAction(title: L10n.HomeViewController.s3, style: .cancel, handler: { _ in
                actionSheet.dismiss(animated: true)
            }))

            present(actionSheet, animated: true)
        }
    }

    private func presentWelcomePopUp() {
        show(popUp: WelcomePopUpView(), duration: nil)
        presenter.setWelcomeMessageSeen()
    }

    private func populateBalanceView() {
        homeView.setUp(
            btcBalance: presenter.getBTCBalance(),
            primaryBalance: presenter.getPrimaryBalance(),
            isBalanceHidden: presenter.isBalanceHidden()
        )
    }

    private func decideBackUpCTA() {
        if presenter.isAnonUser() {
            homeView.addBackUpCTA()
        } else {
            homeView.removeBackUpCTA()
        }
    }
}

extension HomeViewController: HomePresenterDelegate {

    func didReceiveNewOperation(amount: MonetaryAmount, direction: OperationDirection) {
        homeView.displayOpsBadge(bitcoinAmount: amount, direction: direction)
    }

    func onBalanceVisibilityChange(_ isHidden: Bool) {
        homeView.setBalanceHidden(isHidden)
    }

    func onOperationsChange() {
        populateView()
    }

    func onBalanceChange(_ balance: MonetaryAmount) {
        populateBalanceView()
    }

}

extension HomeViewController: HomeViewDelegate {

    func sendButtonTap() {
        navigationController!.pushViewController(ScanQRViewController(), animated: true)
    }

    func receiveButtonTap() {
        navigationController!.pushViewController(ReceiveViewController(origin: .receiveButton), animated: true)
    }

    func chevronTap() {
        let txListVc = TransactionListViewController(delegate: self)
        let txListNavBar = UINavigationController(rootViewController: txListVc)
        txListNavBar.modalPresentationStyle = .fullScreen
        navigationController!.present(txListNavBar, animated: true)
    }

    func backUpTap() {
        SecurityCenterViewController.origin = .emptyAnonUser
        tabBarController!.selectedIndex = 1
    }

    func balanceTap() {
        presenter.toggleBalanceVisibility()
    }

    func didShowTransactionListTooltip() {
        presenter.setTooltipSeen()
    }

}

extension HomeViewController: TransactionListViewControllerDelegate {

    func didTapLoadWallet() {
        receiveButtonTap()
    }

}

extension HomeViewController: UITestablePage {

    typealias UIElementType = UIElements.Pages.HomePage

    func makeViewTestable() {
        makeViewTestable(view, using: .root)
    }

}

fileprivate extension Selector {
    static let supportTouched = #selector(HomeViewController.supportTouched)
}
