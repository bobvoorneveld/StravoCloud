//
//  StravaConnector.swift
//  
//
//  Created by Bob Voorneveld on 08/01/2023.
//

import Foundation
import NIOHTTP1
import Vapor
import Fluent
import Queues



struct StravaConnector {
    
    private let user: User
    private let client: Client
    let db: Database
    
    var logger: Logger {
        db.logger
    }
    
    init(user: User, client: Client, db: Database) {
        self.user = user
        self.client = client
        self.db = db
    }
    
    func get<D: Decodable>(path: String, query: (any Content)?) async throws -> D {
        let accessToken = try await getAccessToken()
        let response = try await client.get("https://www.strava.com/\(path)") { req in
            if let query {
                try req.query.encode(query)
            }
            req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }
        
        if response.status == .tooManyRequests {
            throw StravaError.tooManyRequests
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try response.content.decode(D.self, using: decoder)
    }
    
    func post<D: Decodable>(path: String, query: (any Content)?, withToken: Bool = true) async throws -> D {
        var auth: BearerAuthorization? = nil
        if withToken {
            let accessToken = try await getAccessToken()
            auth = BearerAuthorization(token: accessToken)
        }
        let response = try await client.post("https://www.strava.com/\(path)") { req in
            if let query {
                try req.query.encode(query)
            }
            req.headers.bearerAuthorization = auth
        }
        
        if response.status == .tooManyRequests {
            throw StravaError.tooManyRequests
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try response.content.decode(D.self, using: decoder)
    }
    
    private func getAccessToken() async throws -> String {
        try await user.$stravaToken.load(on: db)

        guard let accessToken = try await user.stravaToken?.getAccessToken(connector: self) else {
            throw StravaError.invalidToken
        }
        return accessToken
    }
}
