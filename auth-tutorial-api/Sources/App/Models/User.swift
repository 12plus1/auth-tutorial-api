import Vapor
import Fluent
import FluentSQLite

struct User: Content, SQLiteModel, Migration {
    var id: Int?
    let email: String
    let password: String
}

struct UserResponse: Content {
    var id: Int?
    let email: String
    
    init(from user: User) {
        self.id = user.id
        self.email = user.email
    }
}
