import Foundation

nonisolated struct ListPageRequest: Equatable, Sendable {
    static let defaultLimit = 50
    static let first = ListPageRequest()

    let limit: Int
    let offset: Int

    init(limit: Int = Self.defaultLimit, offset: Int = 0) {
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }

    var next: ListPageRequest {
        ListPageRequest(limit: limit, offset: offset + limit)
    }

    var fetchLimit: Int {
        limit + 1
    }

    var inclusiveRangeEnd: Int {
        offset + fetchLimit - 1
    }
}

nonisolated struct ListPage<Item> {
    let items: [Item]
    let request: ListPageRequest
    let hasMore: Bool

    init(
        items fetchedItems: [Item],
        request: ListPageRequest,
        hasMore explicitHasMore: Bool? = nil
    ) {
        self.request = request
        self.hasMore = explicitHasMore ?? (fetchedItems.count > request.limit)
        self.items = self.hasMore ? Array(fetchedItems.prefix(request.limit)) : fetchedItems
    }

    var nextRequest: ListPageRequest? {
        hasMore ? request.next : nil
    }
}
