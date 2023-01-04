//
//  CreateTiles.swift
//  
//
//  Created by Bob Voorneveld on 03/01/2023.
//

import Vapor

struct CreateTilesCommand: Command {
    struct Signature: CommandSignature { }

    var help: String {
        "Creates tiles for all activities in the db"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let promise = context.application.eventLoopGroup.next()
            .makePromise(of: Void.self)
        
        promise.completeWithTask {
            let activities = try await StravaActivity.query(on: context.application.db).with(\.$user).all()
            for (index, activity) in activities.enumerated() {
                context.application.logger.info("\(index + 1) of \(activities.count)")
                try await activity.getTiles(on: context.application.db, forced: true)
            }
        }
        try promise.futureResult.wait()
    }
}
