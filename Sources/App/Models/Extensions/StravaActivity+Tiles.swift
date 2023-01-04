//
//  StravaActivity+Tiles.swift
//  
//
//  Created by Bob Voorneveld on 01/01/2023.
//

import Vapor
import FluentSQL

extension StravaActivity {

    @discardableResult
    func getTiles(on db: Database, forced: Bool = false) async throws -> [ActivityTile] {
        if !forced {
            try await $tiles.load(on: db)
            guard tiles.isEmpty else {
                return tiles
            }
        }

        guard let sql = db as? SQLDatabase else {
            throw Abort(.internalServerError)
        }
        
        let column = detailedLine != nil ? "map_detailed_line" : "map_summary_line"

        var tiles = try await sql.raw("""
WITH
  -- parameter injection, for convenience
  zoom(lvl, csize) AS (
    VALUES ( 14, (2*PI()*6378137)/POW(2, 14) )
  ),

  -- subdivide your polygons to minimize per-geometry vertex count
  poi AS (
    SELECT
      id, sdv AS geom
    FROM
      strava_activities AS ply,
      LATERAL ST_SubDivide(
        ST_Transform(ply.\(raw: column), 3857),
        64
      ) AS sdv
      WHERE id='\(raw: id!.uuidString)'
  )

-- get all covering tile indices for each POI
SELECT DISTINCT
  grid.i as x, grid.j as y, z.lvl as z
FROM
  zoom as z,
  poi AS t,
  LATERAL ST_SquareGrid(z.csize, t.geom) AS grid

-- filter for those that actually intersect any of the subdivisions
WHERE
  ST_Intersects(t.geom, grid.geom)
;
""").all(decoding: Tile.self)
        
        tiles = tiles.map {
            let x = $0.x + 8192
            let y = 8192 - $0.y
            return Tile(x: x, y: y, z: $0.z)
        }

        if forced {
            // Remove any old tiles
            try await $tiles.query(on: db).delete()
        }
        // Store new tiles
        try await tiles.map {
            ActivityTile(
                activityID: id!,
                userID: try! user.requireID(),
                x: $0.x,
                y: $0.y,
                z: $0.z
            )
        }.create(on: db)
        
        // load the new tiles
        try await $tiles.load(on: db)
        
        // return them
        return self.tiles
    }
    
    private struct Tile: Content {
        let x: Int
        let y: Int
        let z: Int
    }
}
