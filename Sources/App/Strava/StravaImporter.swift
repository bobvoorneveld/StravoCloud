//
//  StravaImporter.swift
//  
//
//  Created by Bob Voorneveld on 29/12/2022.
//
import Vapor

enum StravaError: Error {
    case invalidToken
}

func loadActivities(req: Request) async throws -> [StravaActivity] {
    let user = try req.auth.require(User.self)

    guard let accessToken = try await user.stravaToken?.getAccessToken(req: req) else {
        throw StravaError.invalidToken
    }
    
    let response = try await req.client.get("https://www.strava.com/api/v3/athlete/activities") { req in
        try req.query.encode([
            "page": "1",
            "per_page": "30"
        ])
        req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    let activities = try response.content.decode([SummaryActivity].self, using: decoder)
    
    let stravaActivities = activities.map { StravaActivity(activity: $0, userID: user.id!) }
    
    try await stravaActivities.create(on: req.db)
    
    return stravaActivities
}
