//
//  CreateFirstSession.swift
//  core
//
//  Created by Manu Herrera on 24/04/2020.
//

import Foundation

struct CreateFirstSession {

    let client: Client
    let gcmToken: String
    let primaryCurrency: String
    let basePublicKey: WalletPublicKey
    let anonChallengeSetup: ChallengeSetup

}

public struct CreateFirstSessionOk {

    let user: User
    let cosigningPublicKey: WalletPublicKey

}

struct Client {

    let type: String = "FALCON"
    let buildType: String
    let version: Int

}