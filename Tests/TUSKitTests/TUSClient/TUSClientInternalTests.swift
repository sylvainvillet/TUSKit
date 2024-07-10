//
//  TUSClientInternalTests.swift
//  
//
//  Created by Tjeerd in ‘t Veen on 01/10/2021.
//

import XCTest
@testable import TUSKit // These tests are for when you want internal access for testing. Please prefer to use TUSClientTests for closer to real-world testing.

final class TUSClientInternalTests: XCTestCase {
    
    var client: TUSClient!
    var tusDelegate: TUSMockDelegate!
    var relativeStoragePath: URL!
    var fullStoragePath: URL!
    var data: Data!
    var files: Files!
    
    override func setUp() async throws {
        try await super.setUp()
        
        do {
            relativeStoragePath = URL(string: "TUSTEST")!
            
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fullStoragePath = docDir.appendingPathComponent(relativeStoragePath.absoluteString)
            files = try Files(storageDirectory: fullStoragePath)
            clearDirectory(dir: fullStoragePath)
            
            data = Data("abcdef".utf8)
            
            client = makeClient(storagePath: relativeStoragePath)
            tusDelegate = TUSMockDelegate()
            await client.setDelegate(tusDelegate)
        } catch {
            XCTFail("Could not instantiate Files \(error)")
        }
        MockURLProtocol.reset()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        MockURLProtocol.reset()
        clearDirectory(dir: fullStoragePath)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        clearDirectory(dir: cacheDir)
        do {
            try await client.reset()
        } catch {
            // Some dirs may not exist, that's fine. We can ignore the error.
        }
    }
  
    @discardableResult
    private func storeFiles() throws -> UploadMetadata {
        let id = UUID()
        let path = try files.store(data: data, id: id)
        return UploadMetadata(id: id, filePath: path, uploadURL: URL(string: "io.tus")!, size: data.count, customHeaders: [:], mimeType: nil)
    }
        
    
    func testClientDoesNotRemoveUnfinishedUploadsOnStartup() throws {
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
        
        try storeFiles()
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertFalse(contents.isEmpty)
        
        client = makeClient(storagePath: fullStoragePath)
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertFalse(contents.isEmpty, "The client is expected to NOT remove unfinished uploads on startup")
    }
    
    func testClientDoesNotRemoveFinishedUploadsOnStartup() throws {
        var contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssert(contents.isEmpty)
        
        let finishedMetadata = try storeFiles()
        finishedMetadata.uploadedRange = 0..<data.count
        try files.encodeAndStore(metaData: finishedMetadata)
        
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertFalse(contents.isEmpty)
        
        client = makeClient(storagePath: fullStoragePath)
        contents = try FileManager.default.contentsOfDirectory(at: fullStoragePath, includingPropertiesForKeys: nil)
        XCTAssertFalse(contents.isEmpty, "The client is expected to NOT remove finished uploads on startup")
    }
}
