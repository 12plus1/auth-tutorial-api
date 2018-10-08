import Vapor

struct RequestWith<T> {
    let request: Request
    let with: T
}

extension Request {
    func with<T>(_ with: T) -> RequestWith<T> {
        return RequestWith(request: self, with: with)
    }
}
