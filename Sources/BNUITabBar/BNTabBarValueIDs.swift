/// The bar's string ids for the tab values of a SwiftUI face, and the way back.
///
/// The bar knows its sections by id, a SwiftUI host by value — usually a case of its own enum. An
/// id is the value's description, so it stays put when a tab is added beside it and reads as
/// itself in a debugger; two values that describe themselves alike get a number, and an id the
/// bar keeps for itself (the "More" section) is never handed out.
nonisolated struct BNTabBarValueIDs<Value: Hashable> {
    let values: [Value]
    let ids: [String]

    init(_ values: [Value], reserving reserved: Set<String> = []) {
        assert(Set(values).count == values.count, "Two tabs share a value, so a selection cannot tell them apart")
        self.values = values
        var used = reserved
        ids = values.map { value in
            let description = String(describing: value)
            var id = description
            var number = 1
            while !used.insert(id).inserted {
                number += 1
                id = "\(description) \(number)"
            }
            return id
        }
    }

    func id(for value: Value) -> String? {
        values.firstIndex(of: value).map { ids[$0] }
    }

    func value(for id: String) -> Value? {
        ids.firstIndex(of: id).map { values[$0] }
    }
}
