//
//  PaymentRequest.swift
//  falcon
//
//  Created by Manu Herrera on 07/01/2019.
//  Copyright © 2019 muun. All rights reserved.
//

import Foundation
import Libwallet

public enum PaymentIntent {
    case toContact
    case toAddress(uri: MuunPaymentURI)
    case submarineSwap(invoice: LibwalletInvoice)
    case toHardwareWallet
    case fromHardwareWallet
}

public protocol PaymentRequestType {
    func destination() -> String
    func presetAmount() -> Satoshis?
    func expiresTime() -> Double?
    func presetDescription() -> String?
    func defaultConfirmationTarget(currentBlockchainHeight: Int) -> UInt
}

public struct FlowToAddress {
    public let uri: MuunPaymentURI

    public init(uri: MuunPaymentURI) {
        self.uri = uri
    }

    public func address() -> String {
        return uri.address ??  ""
    }
}

public struct FlowSubmarineSwap {
    public let invoice: LibwalletInvoice
    public let submarineSwap: SubmarineSwap

    public init(invoice: LibwalletInvoice, submarineSwap: SubmarineSwap) {
        self.invoice = invoice
        self.submarineSwap = submarineSwap
    }

    public func willPreOpenChannel() -> Bool {
        return submarineSwap._willPreOpenChannel
    }
}

extension FlowToAddress: PaymentRequestType {

    public func destination() -> String {
        if let label = uri.label, label != "" {
            return label
        } else {
            return truncate(address: uri.address ?? "")
        }
    }

    private func truncate(address: String) -> String {
        return address.prefix(5) + "..." + address.suffix(5)
    }

    public func presetAmount() -> Satoshis? {
        if let amount = uri.amount, amount != 0 {
            return Satoshis.from(bitcoin: amount)
        }

        return nil
    }

    public func expiresTime() -> Double? {
        if let expiresTimeString = uri.expiresTime,
            let expiresTime = Double(expiresTimeString) {
            return expiresTime
        }

        return nil
    }

    public func presetDescription() -> String? {
            if let message = uri.message, message != "" {
                return uri.message
            }

        return nil

    }

    public func defaultConfirmationTarget(currentBlockchainHeight: Int) -> UInt {
        return 1
    }

}

extension FlowSubmarineSwap: PaymentRequestType {

    public func destination() -> String {
        if let alias = submarineSwap._receiver._alias {
            return alias
        }

        if let pubKey = submarineSwap._receiver._publicKey {
            return truncate(address: pubKey)
        }

        return ""
    }

    private func truncate(address: String) -> String {
        return address.prefix(5) + "..." + address.suffix(5)
    }

    public func presetAmount() -> Satoshis? {
        if let amount = Int64(invoice.milliSat) {
            return Satoshis(value: amount / 1000)
        }
        return nil
    }

    public func defaultConfirmationTarget(currentBlockchainHeight: Int) -> UInt {
        if submarineSwap._fundingOutput._confirmationsNeeded == 0 {
            // Since refunds are instant we can use 250 all the time
            return 250
        }
        // For non 0-conf, use 1 block as confirmation target:
        return 1
    }

    public func expiresTime() -> Double? {
        if invoice.expiry > 0 {
            return Double(invoice.expiry)
        }

        return nil
    }

    public func presetDescription() -> String? {
        if invoice.description != "" {
            return invoice.description
        }

        return nil

    }

}

public struct PaymentRequest {
    public let type: PaymentRequestType
    public let amount: BitcoinAmount
    public let description: String

    public init(type: PaymentRequestType, amount: BitcoinAmount, description: String) {
        self.type = type
        self.amount = amount
        self.description = description
    }
}
