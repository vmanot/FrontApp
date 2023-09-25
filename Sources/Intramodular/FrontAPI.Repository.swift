//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import NetworkKit
import Swallow
import Darwin

extension FrontAPI {
    public class Client: HTTPClient {
        public var session = HTTPSession()
        
        @Published public var token: String?
        
        public var interface: FrontAPI {
            .init(token: token)
        }
        
        public init(token: String? = nil) {
            self.token = token
        }
    }
}

extension FrontAPI.Client {
    public func createContactWithName(
        _ name: String?,
        description: String? = nil,
        avatar: Data? = nil,
        isSpammer: Bool? = nil,
        links: [String]? = nil,
        groupNames: [String]? = nil,
        customFields: [String: String]? = nil,
        handles: [FrontAPI.Schema.Contact.Handle],
        handle: String,
        source: String
    ) -> AnyTask<JSON, FrontAPI.Error> {
        run(
            \.createContact,
             with: .init(
                name: name,
                description: description,
                isSpammer: isSpammer,
                links: links,
                groupNames: groupNames,
                customFields: customFields,
                handles: [.init(handle: handle, source: source)] + handles,
                handle: handle,
                source: source
             )
        )
    }
    
    public func deleteContactWithID(
        _ id: String
    ) -> some ObservableTask {
        run(\.deleteContact, with: id)
    }
    
    public func fetchAllContacts() async throws -> [FrontAPI.Schema.Contact] {
        try await fetchAllAvailableValues(from: \.getContacts)
    }
}

extension FrontAPI.Client {
    public func fetchAllConversations() async throws -> [FrontAPI.Schema.Conversation] {
        try await fetchAllAvailableValues(from: \.listConversations)
    }
    
    public func fetchAllConversations(
        maxAgeInDays: Int
    ) async throws -> [FrontAPI.Schema.Conversation] {
        try await fetchAllAvailableValues(
            from: \.listConversations,
            predicate: {
                $0.createdAt.daysToNow <= maxAgeInDays
            }
        )
    }
}

extension FrontAPI.Client {
    public func fetchAllTags() async throws -> [FrontAPI.Schema.Tag] {
        try await fetchAllAvailableValues(from: \.listTags)
    }
    
    public func fetchAllTagHierarchies() async throws -> [ReferenceTree<FrontAPI.Schema.Tag>] {
        let tags = try await fetchAllTags()
        var result: [ReferenceTree<FrontAPI.Schema.Tag>] = []
        
        for tag in tags {
            try await Task.sleep(.milliseconds(200))
            
            if let child = try await fetchTagHierarchy(for: tag) {
                result.append(child)
            }
        }
        
        return result
    }
    
    public func fetchTagHierarchy(
        for tag: FrontAPI.Schema.Tag
    ) async throws -> ReferenceTree<FrontAPI.Schema.Tag>? {
        let children = try await run(\.listTagChildren, with: tag, options: nil).value._results ?? []
        let result = ReferenceTree<FrontAPI.Schema.Tag>(tag)
        
        for child in children {
            if let subchildren = try await fetchTagHierarchy(for: child) {
                result.addChild(subchildren)
            }
            
            try await Task.sleep(.milliseconds(100))
        }
        
        return result
    }
}

// MARK: - Auxiliary

extension FrontAPI.Client {
    func fetchAllAvailableValues<T, E: Endpoint>(
        from endpoint: KeyPath<API, E>,
        predicate: (T) -> Bool = { _ in true }
    ) async throws -> [T] where E.Root == API, E.Input == Void, E.Output == API.ResponseBodies.Paginated<T>, E.Options == API.RequestOptions.PaginatedRequest {
        let runEndpoint = self[dynamicMember: endpoint]
        
        var nextCursor: String?
        var result: [T] = []
        
        let firstResponse = try await runEndpoint()
        
        logger.debug("Fetched first response.")
        
        result.append(contentsOf: firstResponse._results ?? [])
        
        nextCursor = firstResponse._pagination?.nextPageToken
        
        paginate: while nextCursor != nil {
            let nextResponse = try await Task.retrying(maxRetryCount: 2, retryDelay: .seconds(2)) {
                try await runEndpoint(options: .init(next: nextCursor))
            }.value
            
            logger.debug("Fetched \(nextResponse._results?.count ?? 0) item(s).")
            
            nextCursor = nextResponse._pagination?.nextPageToken
            
            for item in nextResponse._results ?? [] {
                if predicate(item) {
                    result.append(item)
                } else {
                    break paginate
                }
            }
        }
        
        return result
    }
}
