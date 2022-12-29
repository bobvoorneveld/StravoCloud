//
//  UserController.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//

import Vapor


extension User {
    struct Create: Content {
        var name: String
        var email: String
        var password: String
        var confirmPassword: String
    }
}

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

struct UserController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post(use: create)
        users.post("basic", use: basic)
        
        let passwordProtected = users.grouped(User.authenticator())
        passwordProtected.post("token/login", use: tokenLogin)
        
        let authSessionsRoutes = users.grouped(User.sessionAuthenticator())
        authSessionsRoutes.get("login", use: loginHandler)
        authSessionsRoutes.get("logout", use: logoutHandler)

        let credentialsAuthRoutes = authSessionsRoutes.grouped(User.credentialsAuthenticator())
        credentialsAuthRoutes.post("login", use: loginPostHandler)

        let tokenProtected = users.grouped(UserToken.authenticator())
        tokenProtected.get("me", use: me)
    }
    
    func loginHandler(_ req: Request) -> EventLoopFuture<View> {
        return req.view.render("User/login")
    }

    func loginPostHandler(_ req: Request) async throws -> Response {
        if req.auth.has(User.self) {
            return req.redirect(to: "/")
        }
        return try await req.view
            .render("User/login", ["loginError": true])
            .encodeResponse(for: req)
    }

    func logoutHandler(_ req: Request) -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/")
    }

    
    func me(req: Request) async throws -> User {
        try req.auth.require(User.self)
    }

    func create(req: Request) async throws -> User {
        try User.Create.validate(content: req)
        let create = try req.content.decode(User.Create.self)
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        let user = try User(
            name: create.name,
            email: create.email,
            passwordHash: Bcrypt.hash(create.password)
        )
        try await user.save(on: req.db)
        return user
    }
    
    func tokenLogin(req: Request) async throws -> UserToken {
        let user = try req.auth.require(User.self)
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    struct Basic: Decodable {
        let email: String
        let password: String
    }

    func basic(req: Request) async throws -> String {
        let basic = try req.content.decode(Basic.self)
        
        let token = "\(basic.email):\(basic.password)".base64String()
        return "Basic \(token)"
    }
}
