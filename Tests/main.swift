//
// Copyright (c) Vatsal Manot
//

import FrontApp
import Merge
import Swallow
import XCTest

final class FrontAPI_Tests: XCTestCase {
    let client = FrontAPI.Client()
    
    func testShit() async throws {
        client.token = "<insert token>"
        
        let conversations = try await client.fetchAllConversations()
        
        print(conversations)
    }
}
