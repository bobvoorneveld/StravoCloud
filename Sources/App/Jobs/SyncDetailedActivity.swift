//
//  File.swift
//  
//
//  Created by Bob Voorneveld on 02/01/2023.
//

import Foundation
import Queues
import FluentKit
import Vapor


struct DetailedActivityPayload: Codable {
    let activityID: UUID
    let forced: Bool
}

struct SyncDetailedActivity: AsyncJob {
    typealias Payload = DetailedActivityPayload

    func dequeue(_ context: QueueContext, _ payload: DetailedActivityPayload) async throws {
        context.logger.info("fetching details of activity: \(payload.activityID)")
        
        guard let activity = try await StravaActivity.query(on: context.application.db)
            .filter(\.$id == payload.activityID)
            .with(\.$user, { user in
                user.with(\.$stravaToken)
            })
            .first() else {
            throw StravaError.noActivity
        }
        let connector = StravaConnector(user: activity.user, client: context.application.client, db: context.application.db)
        try await activity.loadDetails(connector: connector)
    }
}

extension StravaActivity {
    func loadDetails(connector: StravaConnector) async throws {
        
        guard detailedLine == nil else {
            connector.logger.info("Already fetched")
            return
        }
        
        let updatedActivity: SummaryActivity = try await connector.get(path: "api/v3/activities/\(stravaID)", query: nil)
        
        try await update(with: updatedActivity, on: connector.db)
        
        connector.logger.info("Getting the tiles for activity: \(id!)")
        try await getTiles(on: connector.db, forced: true)

        connector.logger.info("Getting the counties for activity: \(id!)")
        try await getCounties(on: connector.db, forced: true)

        connector.logger.info("Details saved of activity: \(id!)")
    }
}
