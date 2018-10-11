import FluentSQLite
import Vapor
import Leaf
import CSRF

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    try services.register(FluentSQLiteProvider())
    try services.register(LeafProvider())
    services.register(HydraService())

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    /// Use Leaf for rendering views
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    
    /// Register CSRF
    services.register(CSRF())

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    
    middlewares.use(SessionsMiddleware.self)
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
    
    middlewares.use(CSRF.self)
    services.register(middlewares)

    // Configure a SQLite database
    let sqlite = try SQLiteDatabase(storage: .memory)

    /// Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: sqlite, as: .sqlite)
    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .sqlite)
    services.register(migrations)
}
