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

@discardableResult
func loadActivities(req: Request) async throws -> [StravaActivity] {
    let user = try req.auth.require(User.self)
    
    let lastRideStartDate = try await user.$activities.query(on: req.db).sort(\.$startDate, .descending).first()?.startDate

    if let lastRideStartDate {
        req.logger.info("Last start date? \(lastRideStartDate)")
    } else {
        req.logger.info("No sync before, loading all")
    }

    guard let accessToken = try await user.stravaToken?.getAccessToken(req: req) else {
        throw StravaError.invalidToken
    }
    
    var activities = [SummaryActivity]()
    var page = 1
    while true {
        req.logger.info("Loading page: \(page)")
        let response = try await req.client.get("https://www.strava.com/api/v3/athlete/activities") { req in
            var query = [
                "page": "\(page)",
                "per_page": "30"
            ]
            if let date = lastRideStartDate {
                query["after"] = "\(Int(date.timeIntervalSince1970) - 10)"
            }
            try req.query.encode(query)
            req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let newAct = try response.content.decode([SummaryActivity].self, using: decoder)
        if !newAct.isEmpty {
            activities.append(contentsOf: newAct)
            page += 1
        } else {
            break
        }
    }

    let existingIDs = Set(try await StravaActivity.query(on: req.db).field(\.$stravaID).all().map { $0.stravaID })

    req.logger.info("Existing ids in database: \(existingIDs.count)")

    let stravaActivities = activities
        .filter { !existingIDs.contains($0.id) }
        .map { StravaActivity(activity: $0, userID: user.id!) }

    req.logger.info("Adding activities to database: \(stravaActivities.count)")

    try await stravaActivities.create(on: req.db)
    
    return try await user.$activities.get(reload: true, on: req.db)
}
