//
//  commands.swift
//  
//
//  Created by Bob Voorneveld on 03/01/2023.
//

import Vapor

func setupCommands(app: Application) {
    app.commands.use(CreateTilesCommand(), as: "create-tiles")
}
