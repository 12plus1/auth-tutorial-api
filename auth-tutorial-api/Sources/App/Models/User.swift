import Vapor
import Fluent
import FluentSQLite

struct User: Content, SQLiteModel, Migration {
    var id: Int?
    private(set) var email: String
    private(set) var password: String
}

struct UserResponse: Content {
    var id: Int?
    private(set) var email: String
    
    init(from user: User) {
        self.id = user.id
        self.email = user.email
    }
}
