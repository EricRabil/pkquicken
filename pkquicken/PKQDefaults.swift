//
//  PKQDefaults.swift
//  pkquicken
//
//  Created by Eric Rabil on 9/18/22.
//

import Foundation

class PKQDefaults {
    let suite = UserDefaults()
    
    lazy var userDocumentsDirectory: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            return URL(fileURLWithPath: ("~/Documents" as NSString).expandingTildeInPath)
        }
    }()
}

extension PKQDefaults {
    static let shared = PKQDefaults()
    
    static let outputDirectoryKey = "PKQDefaultOutputDirectory"
    
    var defaultOutputDirectory: URL {
        if let path = suite.string(forKey: Self.outputDirectoryKey) {
            return URL(fileURLWithPath: path)
        }
        return userDocumentsDirectory.appendingPathComponent("PKQuicken", isDirectory: true)
    }
}
