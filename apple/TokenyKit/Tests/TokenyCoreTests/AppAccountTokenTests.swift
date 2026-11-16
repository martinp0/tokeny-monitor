import Foundation
import Testing

@testable import TokenyCore

struct AppAccountTokenTests {
    @Test func matchesTheRfc4122Vector() {
        #expect(
            AppAccountToken.uuidV5(namespace: "6ba7b810-9dad-11d1-80b4-00c04fd430c8", name: "www.example.com")
                == "2ed6657d-e927-568b-95e1-2665a8aea6a2"
        )
    }

    @Test func derivesAStableTokenFromTheUserId() {
        let user = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
        let token = AppAccountToken.string(forUserId: "  \(user)  ")
        #expect(token == AppAccountToken.string(forUserId: user.lowercased()))
        #expect(token != user.lowercased())
        let uuid = AppAccountToken.uuid(forUserId: user)
        #expect(uuid?.uuidString.lowercased() == token)
        #expect(AppAccountToken.string(forUserId: "001234.apple.user") == nil)
        #expect(AppAccountToken.string(forUserId: "") == nil)
        #expect(AppAccountToken.namespace == "b7e1c4a2-5d38-4f0e-9c61-2a8e6f0d4b93")
    }

    @Test func purchaseRequiresAServerUserId() {
        #expect(ProPurchaseGate.token(serverUserID: nil) == nil)
        #expect(ProPurchaseGate.token(serverUserID: "001234.appleid") == nil)
        let upper = ProPurchaseGate.token(serverUserID: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")
        let lower = ProPurchaseGate.token(serverUserID: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        #expect(upper != nil)
        #expect(upper == lower)
    }
}
