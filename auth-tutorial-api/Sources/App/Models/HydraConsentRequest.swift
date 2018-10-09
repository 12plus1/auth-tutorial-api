import Vapor

struct HydraConsentRequest: Content {
    let challenge: String
    let skip: Bool
    let requested_scope: [String]
    
    var alwaysRememberAcceptPayload: HydraAcceptConsentRequestPayload {
        return HydraAcceptConsentRequestPayload(remember: !skip, remember_for: 0, grant_scope: requested_scope)
    }
}

struct HydraAcceptConsentRequestPayload: Content {
    let remember: Bool
    let remember_for: Int64
    let grant_scope: [String]
}
