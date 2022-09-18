//
//  main.swift
//  pkquicken
//
//  Created by Eric Rabil on 9/18/22.
//

import Foundation
import PassKitCore
import OSLog
import SwiftCLI

class PKQAccountCommands: CommandGroup {
    let name = "accounts"
    let shortDescription = "inspect and traverse PKAccounts"
    
    class ListAccounts: Command {
        let name = "list"
        
        func execute() throws {
            print(PKAccountStatementExportController.shared.allAccounts.debugDescription)
        }
    }
    
    let children: [Routable] = [ListAccounts()]
}

extension PKAccount {
    var statementExportURL: URL {
        PKQDefaults.shared.defaultOutputDirectory.appendingPathComponent(accountIdentifier).appendingPathComponent(Date().debugDescription)
    }
}

class PKQStatementCommands: CommandGroup {
    let name = "statements"
    let shortDescription = "access statements for eligible PKAccounts"
    
    class ListStatements: Command {
        let name = "list"
        
        @Param var accountID: String?
        
        func execute() throws {
            if let accountID = accountID {
                print(PKAccountStatementExportSession.loadStatements(accountIdentifier: accountID, options: .init()).debugDescription)
            } else {
                print(PKAccountStatementExportController.shared.allAccounts.map {
                    PKAccountStatementExportSession.loadStatements(accountIdentifier: $0.accountIdentifier, options: .init())
                }.debugDescription)
            }
        }
    }
    
    class ExportStatements: Command {
        let name = "export"
        
        @Param var accountID: String
        @Key("-f", "--format") var format: String?
        @Key("-a", "--after") var afterStatement: String?
        
        func execute() throws {
            guard let account = PKAccountStatementExportController.shared.exportableAccounts.first(where: { $0.accountIdentifier == accountID }) else {
                fatalError("No exportable account with identifier \(accountID)")
            }
            let format = format ?? "qfx"
            var afterDate: Date?
            if let afterStatement = afterStatement {
                let statements = PKAccountStatementExportSession.loadStatements(accountIdentifier: account.accountIdentifier, options: .init())
                for statement in statements {
                    if statement.identifier == afterStatement {
                        afterDate = statement.openingDate
                    }
                }
                if afterDate == nil {
                    fatalError("No statements with the ID \(afterStatement) found within account \(accountID)")
                }
            }
            let options = PKAccountStatementExportOptions(startFrom: afterDate, exportFormat: format)
            let output = account.statementExportURL
            try PKAccountStatementExportSession(controller: .shared, account: account, options: options).export(to: output)
            print("Statements exported to \(output.path)")
        }
    }
    
    let children: [Routable] = [ListStatements(), ExportStatements()]
}

let cli = CLI(name: "pkquicken", commands: [PKQAccountCommands(), PKQStatementCommands()])
cli.goAndExit()
