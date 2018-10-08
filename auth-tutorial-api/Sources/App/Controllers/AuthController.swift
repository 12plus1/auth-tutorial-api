import Vapor
import Fluent
import FluentSQLite
import Crypto

final class AuthController {
    // MARK: Route: POST on /auth/register
    private func register(req: Request, payload: LoginPayload) throws -> Future<UserResponse> {
        return try authenticate(req: req, payload: payload, type: .register)
    }
    
    // MARK: Route: POST on /auth/login
    private func login(req: Request, payload: LoginPayload) throws -> Future<UserResponse> {
        return try authenticate(req: req, payload: payload, type: .login)
    }
    
    // MARK: User management helper
    private func authenticate(req: Request, payload: LoginPayload, type: AuthType) throws -> Future<UserResponse> {
        try payload.validate()
        switch type {
        case .login:
            return try loginUser(req: req, payload: payload)
        case .register:
            return try registerUser(req: req, payload: payload)
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
}

extension AuthController: RouteCollection {
    func boot(router: Router) throws {
        let group = router.grouped("auth")
        group.post(LoginPayload.self, at: "register", use: register)
        group.post(LoginPayload.self, at: "login", use: login)
    }
}

struct LoginPayload: Content, Validatable {
    let email: String
    let password: String
    
    static func validations() -> Validations<LoginPayload> {
        var validations = Validations(LoginPayload.self)
        validations.add(\.email, at: ["email"], .email)
        validations.add(\.password, at: ["password"], !.empty)
        return validations
    }
}

enum AuthType: String {
    case login, register
}
