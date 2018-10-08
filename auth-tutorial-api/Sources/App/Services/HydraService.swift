import Vapor

final class HydraService: Service {
    private let baseUrl = Environment.get("HYDRA_ADMIN_URL")!
    private func getHydraLoginRequestEndpoint(challenge: String) -> String {
        return "\(baseUrl)/oauth2/auth/requests/login/\(challenge)"
    }
    
    private func getHydraAcceptLoginRequestEndpoint(challenge: String) -> String {
        return "\(baseUrl)/oauth2/auth/requests/login/\(challenge)/accept"
    }
    
    func getLoginRequest(for req: Request, challenge: String) throws -> Future<HydraLoginRequest> {
        let endpoint = getHydraLoginRequestEndpoint(challenge: challenge)
        return try req.client()
            .get(endpoint)
            .flatMapResponse(to: HydraLoginRequest.self)
    }
    
    func acceptLoginRequest(for req: RequestWith<HydraLoginRequest>) throws -> Future<HydraRedirect> {
        let endpoint = getHydraAcceptLoginRequestEndpoint(challenge: req.with.challenge)
        return try req.request.client()
            .put(endpoint, body: req.with.alwaysRememberAcceptPayload)
            .flatMapResponse(to: HydraRedirect.self)
    }
    
    func getLoginChallenge(from req: Request) throws -> String {
        return try req.query.get(String.self, at: "login_challenge")
    }
}

struct HydraRedirect: Content {
    let redirect_to: String
}
