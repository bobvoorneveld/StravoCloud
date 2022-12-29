import Fluent
import FluentPostgresDriver
import FluentPostGIS
import Leaf
import Redis
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)
    
    app.views.use(.leaf)
    
    let redisHostname = Environment.get("REDIS_HOSTNAME") ?? "localhost"
    let redisConfig = try RedisConfiguration(hostname: redisHostname)
    app.redis.configuration = redisConfig
    app.sessions.use(.redis)
    app.middleware.use(app.sessions.middleware)

    app.migrations.add(User.Migration())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(StravaToken.Migration())
    
    app.migrations.add(EnablePostGISMigration())

    // register routes
    try routes(app)
}
