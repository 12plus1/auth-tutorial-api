import Vapor

extension Future where T: Response {
    func flatMapResponse<Wrapped: Content>(to type: Wrapped.Type) -> Future<Wrapped> {
        return flatMap(to: type) { response in
            return try response.content.decode(type)
        }
    }
}
