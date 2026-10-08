internal enum PDKJSONSyntax {
    case null
    case boolean(Bool)
    case string(String)
    case number(String)
    case array([Int])
    case object([(String, Int)])
}
