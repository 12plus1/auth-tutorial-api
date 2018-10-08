import Vapor

struct HydraLoginRequest: Content {
    let challenge: String
    let skip: Bool
    let subject: String?
    
    var alwaysRememberAcceptPayload: HydraAcceptLoginRequestPayload {
        return HydraAcceptLoginRequestPayload(remember: !skip, remember_for: 0, subject: subject)
    }
}

struct HydraAcceptLoginRequestPayload: Content {
    let remember: Bool
    let remember_for: Int64
    let subject: String?
}
