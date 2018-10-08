import Vapor

extension Client {
    func put<T: Content>(_ url: URLRepresentable, headers: HTTPHeaders = [:], body: T) -> Future<Response> {
        return put(url, headers: headers) { request in
            try request.content.encode(body)
        }
    }
}
