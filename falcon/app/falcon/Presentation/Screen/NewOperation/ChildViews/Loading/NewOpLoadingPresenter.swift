//
//  NewOpLoadingPresenter.swift
//  falcon
//
//  Created by Manu Herrera on 27/02/2019.
//  Copyright © 2019 muun. All rights reserved.
//

import RxSwift
import Libwallet
import core

protocol NewOpLoadingPresenterDelegate: BasePresenterDelegate {
    func loadingDidFinish(feeInfo: FeeInfo,
                          user: User,
                          paymentRequestType: PaymentRequestType)
    func expiredInvoice()
    func invalidAddress()
    func swapError(_ error: NewOpError)
    func unexpectedError()
    func invoiceMissingAmount()
}

class NewOpLoadingPresenter<Delegate: NewOpLoadingPresenterDelegate>: BasePresenter<Delegate> {

    private let paymentIntent: PaymentIntent
    private let feeCalculatorAction: FeeCalculatorAction
    private let userSelector: UserSelector
    private let submarineSwapAction: SubmarineSwapAction
    private let bip70Action: BIP70Action

    init(delegate: Delegate,
         state: PaymentIntent,
         feeCalculatorAction: FeeCalculatorAction,
         userSelector: UserSelector,
         submarineSwapAction: SubmarineSwapAction,
         bip70Action: BIP70Action) {
        self.paymentIntent = state
        self.feeCalculatorAction = feeCalculatorAction
        self.userSelector = userSelector
        self.submarineSwapAction = submarineSwapAction
        self.bip70Action = bip70Action

        super.init(delegate: delegate)
    }

    func startLoading() {

        let paymentRequestType: Single<PaymentRequestType>
        var isSwap = false

        switch paymentIntent {
        case .toAddress(let uri):
            if let u = bip70Url() {
                paymentRequestType = loadBIP70(url: u, uri: uri)
            } else {
                paymentRequestType = Single.just(FlowToAddress(uri: uri))
            }

        case .submarineSwap(let invoice):
            paymentRequestType = createSubmarineSwap(invoice: invoice)
            isSwap = true

        case .fromHardwareWallet,
             .toHardwareWallet,
             .toContact,
             .lnurlWithdraw:
            preconditionFailure()
        }

        let loadSingle = Single.zip(feeCalculatorAction.getValue(),
                                    paymentRequestType,
                                    userSelector.get())

        subscribeTo(loadSingle, onSuccess: self.didLoad)

        feeCalculatorAction.run(isSwap: isSwap)
    }

    private func createSubmarineSwap(invoice: LibwalletInvoice) -> Single<PaymentRequestType> {
        submarineSwapAction.run(invoice: invoice.rawInvoice)

        return submarineSwapAction.getValue().map({ (submarineSwap) -> PaymentRequestType in
            return FlowSubmarineSwap(invoice: invoice, submarineSwap: submarineSwap)
        })
    }

    private func loadBIP70(url: String, uri: MuunPaymentURI) -> Single<PaymentRequestType> {

        return Single.deferred {

            do {
                return try self.bip70Action.getPaymentRequest(url: url)
            } catch {
                let expiredString = "Failed to Unmarshall paymentRequest"
                if let e = error as? MuunError {
                    if e.localizedDescription.contains(expiredString) {
                        // If the error contains the expired string, that means that the invoice has expired
                        return Single.error(Errors.expiredInvoice)
                    } else if self.uriHasAddress() {
                        // If the request fails but the invoice did not expire and it has an address, we continue
                        // the flow to that address
                        return Single.just(FlowToAddress(uri: uri))
                    }
                    // In any other case we display the invalid address message
                    return Single.error(Errors.invalidAddress)
                }
                return Single.error(Errors.invalidAddress)
            }

        }

    }

    private func bip70Url() -> String? {
        switch paymentIntent {
        case .toAddress(let uri):
            if let url = uri.bip70URL, !url.isEmpty {
                return url
            }
        default:
            return nil
        }

        return nil
    }

    private func uriHasAddress() -> Bool {
        switch paymentIntent {
        case .toAddress(let uri):
            if let address = uri.address, !address.isEmpty {
                return true
            }
        default:
            return false
        }

        return false
    }

    func didLoad(feeInfo: FeeInfo, paymentRequestType: PaymentRequestType, user: User) {
        delegate?.loadingDidFinish(feeInfo: feeInfo,
                                   user: user,
                                   paymentRequestType: paymentRequestType)
    }

    override func handleError(_ e: Error) {
        if let error = e as? Errors {
            switch error {

            case .expiredInvoice:
                DispatchQueue.main.async {
                    self.delegate.expiredInvoice()
                }

            case .invalidAddress:
                DispatchQueue.main.async {
                    self.delegate.invalidAddress()
                }

            case .invoiceMissingAmount:
                DispatchQueue.main.async {
                    self.delegate.invoiceMissingAmount()
                }
            }

        } else if let swapError = swapError(e) {
            delegate.swapError(swapError)
        } else {
            delegate.unexpectedError()
        }
    }

    private func swapError(_ e: Error) -> NewOpError? {
        if e.isKindOf(.invalidInvoice) {
            return .invalidInvoice
        } else if e.isKindOf(.invoiceAlreadyUsed) {
            return .invoiceAlreadyUsed
        } else if e.isKindOf(.invoiceExpiresTooSoon) {
            return .invoiceExpiresTooSoon
        } else if e.isKindOf(.noPaymentRoute) {
            return .noPaymentRoute
        } else if e.isKindOf(.invoiceUnreachableNode) {
            return .invoiceUnreachableNode
        } else if e.isKindOf(.cyclicalSwap) {
            return .cyclicalSwap
        } else if e.isKindOf(.amountLessInvoicesNotSupported) {
            return .invoiceMissingAmount
        }

        return nil
    }

    enum Errors: Error {
        case expiredInvoice
        case invalidAddress
        case invoiceMissingAmount
    }

}
