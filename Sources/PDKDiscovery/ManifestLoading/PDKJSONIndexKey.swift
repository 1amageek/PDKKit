internal struct PDKJSONIndexKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(_ index: Int) { intValue = index; stringValue = "Index " + String(index) }
    init(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init(intValue: Int) { self.init(intValue) }
}
