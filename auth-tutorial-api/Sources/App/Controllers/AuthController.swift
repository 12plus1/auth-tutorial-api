import Vapor
import Fluent
import FluentSQLite
import Crypto

final class AuthController {
    // MARK: Route: GET on /auth/register
    private func renderRegister(req: Request) throws -> Future<Response> {
        return try renderAuth(request: req, type: .register)
    }
    
    // MARK: Route: GET on /auth/login
    private func renderLogin(req: Request) throws -> Future<Response> {
        return try renderAuth(request: req, type: .login)
    }
    
    // MARK: Route: GET on /auth/consent
    private func skipConsent(req: Request) throws -> Future<Response> {
        let hydra = try req.make(HydraService.self)
        return try hydra.getConsentRequest(for: req).flatMap { hydraConsentRequest in
            try hydra.acceptConsentRequest(for: req.with(hydraConsentRequest)).map { redirect in
                req.redirect(to: redirect.redirect_to)
            }
        }
    }
    
    // MARK: Route: POST on /auth/register
    private func register(req: Request, payload: LoginPayload) throws -> Future<Response> {
        return try authenticate(req: req, payload: payload, type: .register)
    }
    
    // MARK: Route: POST on /auth/login
    private func login(req: Request, payload: LoginPayload) throws -> Future<Response> {
        return try authenticate(req: req, payload: payload, type: .login)
    }
    
    // MARK: User management helper
    private func authenticate(req: Request, payload: LoginPayload, type: AuthType) throws -> Future<Response> {
        try payload.validate()
        let hydra = try req.make(HydraService.self)
        
        return try loginOrRegister(req: req, payload: payload, type: type).flatMap { _ in
            try hydra.acceptLoginRequest(for: req, payload: payload).map { redirect in
                req.redirect(to: redirect.redirect_to)
            }
        }.catchFlatMap { (error: Error) in
            var msg = error.localizedDescription
            if let error = error as? AbortError {
                msg = error.reason
            }
            return try self.renderAuth(request: req, type: .login, errorMsg: msg, challenge: payload.challenge)
        }
    }
    
    private func loginOrRegister(req: Request, payload: LoginPayload, type: AuthType) throws -> Future<UserResponse> {
        switch type {
        case .login: return try loginUser(req: req, payload: payload)
        case .register: return try registerUser(req: req, payload: payload)
        }
    }
    
    private func registerUser(req: Request, payload: LoginPayload) throws -> Future<UserResponse> {
        return User.query(on: req).filter(\.email == payload.email).first().flatMap { existingUser in
            guard existingUser == nil else {
                throw Abort(.badRequest, reason: "A user with this email already exists" , identifier: nil)
            }
            
            let user = try self.encryptedNewUser(for: req, from: payload)
            return user.save(on: req).map(UserResponse.init(from:))
        }
    }
    
    private func encryptedNewUser(for request: Request, from payload: LoginPayload) throws -> User {
        let digest = try request.make(BCryptDigest.self)
        let password = try digest.hash(payload.password)
        return User(id: nil, email: payload.email, password: password)
    }
    
    private func loginUser(req: Request, payload: LoginPayload) throws -> Future<UserResponse> {
        return User.query(on: req).filter(\.email == payload.email).first().map { existingUser in
            guard let user = existingUser else {
                throw Abort(.badRequest, reason: "Invalid email or password" , identifier: nil)
            }
            
            if try BCrypt.verify(payload.password, created: user.password) {
                return UserResponse(from: user)
            } else {
                throw Abort(.unauthorized, reason: "Invalid email or password" , identifier: nil)
            }
        }
    }
    
    // MARK: Ory Hydra interaction helper
    private func renderAuth(request req: Request, type: AuthType, errorMsg: String = "", challenge: String? = nil) throws -> Future<Response> {
        let hydra = try req.make(HydraService.self)
        let challenge = try (challenge ?? (try hydra.getLoginChallenge(from: req)))
        return try hydra.getLoginRequest(for: req, challenge: challenge).flatMap { hydraLoginRequest in
            if hydraLoginRequest.skip {
                return try hydra.acceptLoginRequest(for: req.with(hydraLoginRequest)).map { redirect in
                    throw Abort.redirect(to: redirect.redirect_to)
                }
            } else {
                return try self.renderAuthForm(request: req, challenge: hydraLoginRequest.challenge, type: type, errorMsg: errorMsg)
            }
        }
    }
    
    private func renderAuthForm(request req: Request, challenge: String, type: AuthType, errorMsg: String) throws -> Future<Response> {
        let viewVariables = ["challenge": challenge, "errorMessage": errorMsg]
        return try req.view().render(type.rawValue, viewVariables)
            .flatMap { $0.encode(status: .ok, for: req) }
    }
}

extension AuthController: RouteCollection {
    func boot(router: Router) throws {
        let group = router.grouped("auth")
        group.get("register", use: renderRegister)
        group.get("login", use: renderLogin)
        group.get("consent", use: skipConsent)
        group.post(LoginPayload.self, at: "register", use: register)
        group.post(LoginPayload.self, at: "login", use: login)
    }
}

struct LoginPayload: Content, Validatable {
    let challenge: String
    let email: String
    let password: String
    
    static func validations() -> Validations<LoginPayload> {
        var validations = Validations(LoginPayload.self)
        validations.add(\.challenge, at: ["challenge"], !.empty)
        validations.add(\.email, at: ["email"], .email)
        validations.add(\.password, at: ["password"], !.empty)
        return validations
    }
}

enum AuthType: String {
    case login, register
}
