//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import NetworkKit
import Swallow

public struct FrontAPI: RESTAPISpecification {
    public let token: String?
    public let host = URL(string: "https://api2.frontapp.com")!
    
    public init(token: String?) {
        self.token = token
    }
    
    public var id: some Hashable {
        token
    }
    
    @GET
    @Path("contacts")
    public var getContacts = Endpoint<Void, ResponseBodies.GetContacts, RequestOptions.PaginatedRequest>()
    
    @POST
    @Path("contacts")
    @Body(json: \.input, keyEncodingStrategy: .convertToSnakeCase)
    public var createContact = Endpoint<RequestBodies.CreateContact, JSON, Void>()
    
    @DELETE
    @Path({ context in "contacts/\(context.input)" })
    public var deleteContact = Endpoint<String, JSON, Void>()
    
    @GET
    @Path("conversations")
    public var listConversations = Endpoint<Void, ResponseBodies.ListConversations, RequestOptions.PaginatedRequest>()
    
    @GET
    @Path("tags")
    public var listTags = Endpoint<Void, ResponseBodies.ListTags, RequestOptions.PaginatedRequest>()
    
    @GET
    @Path({ context in "tags/\(context.input.id)/children" })
    public var listTagChildren = Endpoint<Schema.Tag, ResponseBodies.ListTags, RequestOptions.PaginatedRequest>()
}

extension FrontAPI {
    public final class Endpoint<Input, Output, Options>: BaseHTTPEndpoint<FrontAPI, Input, Output, Options> {
        override public func buildRequestBase(
            from input: Input,
            context: BuildRequestContext
        ) throws -> Request {
            try super.buildRequestBase(from: input, context: context)
                .header(.authorization(.bearer, context.root.token.unwrap()))
                .header(.accept(.json))
                .header(.contentType(.json))
                .query([
                    "limit": (context.options is CursorPaginated) ? "100" : nil,
                    "page_token": (context.options as? CursorPaginated)?.paginationCursor?.stringValue
                ])
        }
        
        override public func decodeOutputBase(
            from response: Request.Response,
            context: DecodeOutputContext
        ) throws -> Output {
            do {
                try response.validate()
            } catch {
                print(response)
                print(context.request.url)
            }
            
            return try response.decode(
                Output.self,
                dateDecodingStrategy: .secondsSince1970,
                keyDecodingStrategy: .convertFromSnakeCase
            )
        }
    }
}

// MARK: - Schema -

extension FrontAPI {
    public enum Schema {
        public struct Tag: Codable, CustomStringConvertible, Hashable, Identifiable {
            public var _links: JSON?
            public var id: String
            public var name: String
            public var highlight: String?
            public var isPrivate: Bool
            public var createdAt: Date
            public var updatedAt: Date
            
            public var description: String {
                name
            }
        }
        
        public struct Recipient: Codable, Hashable, Identifiable {
            public let _links: JSON?
            public let handle: String
            public let role: String
            
            public var id: String {
                handle
            }
        }
        
        public struct Contact: Codable, Hashable, Identifiable {
            public struct Links: Codable, Hashable {
                public let `self`: URL
            }
            
            public struct Handle: Codable, Hashable {
                public let handle: String
                public let source: String
                
                public init(handle: String, source: String) {
                    self.handle = handle
                    self.source = source
                }
            }
            
            public struct Group: Codable, Hashable {
                public let _links: Links?
                public let id: String
                public let name: String
                public let isPrivate: Bool
            }
            
            public let _links: Links?
            public var id: String
            public var name: String
            public var description: String?
            public var avatarURL: String?
            public var isSpammer: Bool?
            public var links: [String]?
            public var handles: [Handle]?
            public var groups: [Group]?
            public var updatedAt: JSONNumber
            public var customFields: [String: String]?
            public var isPrivate: Bool
        }
        
        public struct Message: Codable, CustomStringConvertible, Hashable, Identifiable {
            public struct Links: Codable, Hashable {
                public let `self`: URL
            }
            
            public var _links: Links?
            public var id: String
            public var type: String
            public var isInbound: Bool
            public var isDraft: Bool
            public var createdAt: Date
            public var blurb: String
            public var author: JSON
            public let recipients: [Recipient]
            
            public var description: String {
                blurb
            }
        }
        
        public struct Conversation: Codable, Hashable, Identifiable {
            public struct Links: Codable, Hashable {
                public let `self`: URL
            }
            
            public struct Assignee: Codable, Hashable, Identifiable {
                public let id: String
                public let email: String?
                public let username: String?
                public let firstName: String?
                public let lastName: String?
            }
            
            public var _links: Links
            public var id: String
            public var subject: String
            public var status: String
            public var assignee: Assignee?
            public var recipient: Recipient
            public var tags: [Tag]
            public var createdAt: Date
            public var isPrivate: Bool
        }
    }
}

extension FrontAPI {
    public enum RequestBodies {
        public struct CreateContact: Encodable {
            public let name: String?
            public let description: String?
            // public let avatar: Data
            public let isSpammer: Bool?
            public let links: [String]?
            public let groupNames: [String]?
            public let customFields: [String: String]?
            public let handles: [Schema.Contact.Handle]
            public let handle: String
            public let source: String
        }
    }
    
    public enum RequestOptions {
        public struct PaginatedRequest: CursorPaginated, ExpressibleByNilLiteral {
            public var paginationCursor: PaginationCursor?
            public let fetchLimit: FetchLimit? = .max(100)
            
            public init(nilLiteral: ()) {
                
            }
            
            public init(next: String?) {
                self.paginationCursor = next.map(PaginationCursor.string)
            }
        }
    }
    
    public enum ResponseBodies {
        public struct Paginated<Resource: Decodable>: Decodable, PaginatedResponse {
            public struct Pagination: Decodable {
                public let next: String?
                
                public var nextPageToken: String? {
                    guard let next = next else {
                        return nil
                    }
                    
                    return next.components(separatedBy: "page_token=").last
                }
            }
            
            public let _pagination: Pagination?
            public let _links: JSON?
            public let _results: [Resource]?
            
            public func convert() throws -> PartialOf<CursorPaginatedList<Resource>> {
                .init(.init(items: _results, nextCursor: _pagination?.nextPageToken.map(PaginationCursor.string)))
            }
        }
        
        public typealias GetContacts = Paginated<Schema.Contact>
        public typealias ListConversations = Paginated<Schema.Conversation>
        public typealias ListTags = Paginated<Schema.Tag>
    }
}
