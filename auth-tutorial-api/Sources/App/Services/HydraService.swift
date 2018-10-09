import Vapor

final class HydraService: Service {
    private let baseUrl = Environment.get("HYDRA_ADMIN_URL")!
    private func getHydraRequestEndpoint(for type: HydraRequestType, challenge: String) -> String {
        return "\(baseUrl)/oauth2/auth/requests/\(type.rawValue)/\(challenge)"
    }
    
    private func getHydraAcceptRequestEndpoint(for type: HydraRequestType, challenge: String) -> String {
        return "\(baseUrl)/oauth2/auth/requests/\(type.rawValue)/\(challenge)/accept"
    }
    
    func getLoginRequest(for req: Request, challenge: String) throws -> Future<HydraLoginRequest> {
        let endpoint = getHydraRequestEndpoint(for: .login, challenge: challenge)
        return try req.client()
            .get(endpoint)
            .flatMapResponse(to: HydraLoginRequest.self)
    }
    
    func acceptLoginRequest(for req: RequestWith<HydraLoginRequest>) throws -> Future<HydraRedirect> {
        let endpoint = getHydraAcceptRequestEndpoint(for: .login, challenge: req.with.challenge)
        return try req.request.client()
            .put(endpoint, body: req.with.alwaysRememberAcceptPayload)
            .flatMapResponse(to: HydraRedirect.self)
    }
    
    func acceptLoginRequest(for req: Request, payload: LoginPayload) throws -> Future<HydraRedirect> {
        let endpoint = getHydraAcceptRequestEndpoint(for: .login, challenge: payload.challenge)
        let body = HydraAcceptLoginRequestPayload(remember: true, remember_for: 0, subject: payload.email)
        return try req.client()
            .put(endpoint, body: body)
            .flatMapResponse(to: HydraRedirect.self)
    }
    
    func getConsentRequest(for req: Request) throws -> Future<HydraConsentRequest> {
        let challenge = try req.query.get(String.self, at: HydraRequestType.consent.challengeKey)
        let endpoint = getHydraRequestEndpoint(for: .consent, challenge: challenge)
        return try req.client()
            .get(endpoint)
            .flatMapResponse(to: HydraConsentRequest.self)
    }
    
    func acceptConsentRequest(for req: RequestWith<HydraConsentRequest>) throws -> Future<HydraRedirect> {
        let endpoint = getHydraAcceptRequestEndpoint(for: .consent, challenge: req.with.challenge)
        return try req.request.client()
            .put(endpoint, body: req.with.alwaysRememberAcceptPayload)
            .flatMapResponse(to: HydraRedirect.self)
    }
    
    func getLoginChallenge(from req: Request) throws -> String {
        return try req.query.get(String.self, at: HydraRequestType.login.challengeKey)
    }
}

struct HydraRedirect: Content {
    let redirect_to: String
}

enum HydraRequestType: String {
    case login
    case consent
    
    var challengeKey: String {
        switch self {
        case .login: return "login_challenge"
        case .consent: return "consent_challenge"
        }
    }
}
