//
//  main.swift
//  pkquicken
//
//  Created by Eric Rabil on 9/18/22.
//

import Foundation
import PassKitCore
import OSLog

class PKAccountStatementExportController {
    init() {}
}

struct PKAccountStatementExportOptions {
    var startFrom: Date?
    var exportFormat: String = "qfx"
    var timeZone: TimeZone = .current
    
    func include(statement: PKCreditAccountStatement) -> Bool {
        if let startFrom, startFrom > statement.openingDate {
            return false
        }
        return true
    }
}

class PKAccountStatementExportSession {
    unowned let controller: PKAccountStatementExportController
    let account: PKAccount
    let statements: Set<PKCreditAccountStatement>
    let options: PKAccountStatementExportOptions
    let log = Logger(subsystem: "com.ericrabil.pkquicken", category: "ExportSession")
    
    static func loadStatements(accountIdentifier: String, options: PKAccountStatementExportOptions) -> Set<PKCreditAccountStatement> {
        let semaphore = DispatchSemaphore(value: 0)
        var statements = Set<PKCreditAccountStatement>()
        PKAccountService.sharedInstance().creditStatements(forAccountIdentifier: accountIdentifier) { pkStatements, error in
            if let pkStatements = pkStatements {
                statements = Set(pkStatements.filter(options.include(statement:)))
            } else if let error = error {
                print(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return statements
    }
    
    init(controller: PKAccountStatementExportController, account: PKAccount, options: PKAccountStatementExportOptions = PKAccountStatementExportOptions()) {
        self.controller = controller
        self.account = account
        self.options = options
        self.statements = Self.loadStatements(accountIdentifier: account.accountIdentifier, options: options)
    }
    
    private let exportLock = NSLock()
    
    private func export(_ statement: PKCreditAccountStatement, callback: @escaping PKAccountStatementExportBlock) {
        PKAccountService.sharedInstance().exportTransactionData(forAccountIdentifier: account.accountIdentifier, withFileFormat: options.exportFormat, begin: statement.openingDate, end: statement.closingDate, productTimeZone: options.timeZone, completion: callback)
    }
    
    func export(to output: URL) throws {
        exportLock.lock()
        defer {
            exportLock.unlock()
        }
        
        var results: [String: Result<PKAccountWebServiceExportTransactionDataResponse?, Error>] = [:]
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        for statement in statements {
            queue.addOperation {
                let semaphore = DispatchSemaphore(value: 0)
                self.log.info("Beginning export for \(self.account.accountIdentifier)/\(statement.identifier) from \(statement.openingDate) to \(statement.closingDate)")
                self.export(statement) { response, error in
                    results[statement.identifier] = error.map(Result.failure(_:)) ?? Result.success(response)
                    self.log.info("Export for \(self.account.accountIdentifier)/\(statement.identifier) finished successfully: \(error == nil && response != nil)")
                    semaphore.signal()
                }
                semaphore.wait()
            }
            
        }
        queue.waitUntilAllOperationsAreFinished()
        log.info("All exports finished. Writing results to disk.")
        
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        
        for (id, result) in results {
            switch result {
            case .success(.some(let response)):
                let output = output.appendingPathComponent(response.transactionDataFilename)
                try response.transactionData.write(to: output)
                log.info("Wrote \(id) to \(output)")
            case .success(.none):
                log.warning("Export of statement \(id) did not fail, but had no result")
            case .failure(let error):
                log.error("Export of statement \(id) failed with error \(error)")
            }
        }
    }
}

extension PKAccountStatementExportController {
    static let shared = PKAccountStatementExportController()
    
    var exportableAccounts: [PKAccount] {
        var accounts: [PKAccount] = []
        let semaphore = DispatchSemaphore(value: 0)
        PKAccountService.sharedInstance().accounts { pkAccounts in
            accounts = pkAccounts
            semaphore.signal()
        }
        semaphore.wait()
        return accounts
    }
    
    func autoExportAll(output outputFolder: URL, options: PKAccountStatementExportOptions = PKAccountStatementExportOptions()) throws {
        for account in exportableAccounts {
            let session = PKAccountStatementExportSession(controller: self, account: account, options: options)
            try session.export(to: outputFolder.appendingPathComponent(account.accountIdentifier))
        }
    }
}

let documentsDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
let outDir = documentsDirectory.appendingPathComponent("PKQuicken", isDirectory: true).appendingPathComponent(Date().debugDescription)
try PKAccountStatementExportController.shared.autoExportAll(output: outDir)
