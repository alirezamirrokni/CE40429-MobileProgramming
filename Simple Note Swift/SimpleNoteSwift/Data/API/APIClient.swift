import Foundation

final class APIClient {
    let baseURL: URL
    let session: URLSession
    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }
    func request<T: Decodable, B: Encodable>(_ path: String, method: String = "GET", body: B? = nil, authorized: Bool = true, retry: Bool = true) async throws -> T {
        var url = URL(string: path, relativeTo: baseURL)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let token = AuthManager.shared.access {
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401, retry {
            try await refreshToken()
            return try await request(path, method: method, body: body, authorized: authorized, retry: false)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func requestVoid<B: Encodable>(_ path: String, method: String = "POST", body: B, authorized: Bool = true) async throws {
        var url = URL(string: path, relativeTo: baseURL)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token = AuthManager.shared.access {
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshToken()
            try await requestVoid(path, method: method, body: body, authorized: authorized)
        }
    }
    func refreshToken() async throws {
        guard let r = AuthManager.shared.refresh else { throw NSError(domain: "no_refresh", code: 0) }
        let payload = TokenRefreshRequest(refresh: r)
        let resp: TokenResponse = try await request("api/auth/token/refresh/", method: "POST", body: payload, authorized: false, retry: false)
        AuthManager.shared.access = resp.access
        if let nr = resp.refresh { AuthManager.shared.refresh = nr }
    }
    func login(username: String, password: String) async throws {
        let payload = TokenObtainPairRequest(username: username, password: password)
        let resp: TokenResponse = try await request("api/auth/token/", method: "POST", body: payload, authorized: false, retry: false)
        AuthManager.shared.access = resp.access
        AuthManager.shared.refresh = resp.refresh
    }
    func register(username: String, email: String, password: String, first: String?, last: String?) async throws {
        let payload = RegisterRequest(username: username, password: password, email: email, first_name: first, last_name: last)
        let _: Empty = try await request("api/auth/register/", method: "POST", body: payload, authorized: false, retry: false)
    }
    func userinfo() async throws -> UserInfo {
        try await request("api/auth/userinfo/")
    }
    func changePassword(old: String, new: String) async throws {
        let payload = ChangePasswordRequest(old_password: old, new_password: new)
        let _: Empty = try await request("api/auth/change-password/", method: "POST", body: payload)
    }
    func listNotes(page: Int?, pageSize: Int? = 10) async throws -> Page<NoteDTO> {
        var qs: [URLQueryItem] = []
        if let p = page { qs.append(URLQueryItem(name: "page", value: String(p))) }
        if let ps = pageSize { qs.append(URLQueryItem(name: "page_size", value: String(ps))) }
        var url = URL(string: "api/notes/", relativeTo: baseURL)!
        if qs.count > 0 {
            var c = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            c.queryItems = qs
            url = c.url!
        }
        let (data, resp) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60))
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshToken()
            return try await listNotes(page: page, pageSize: pageSize)
        }
        return try JSONDecoder().decode(Page<NoteDTO>.self, from: data)
    }
    func filterNotes(title: String?, description: String?, page: Int?, pageSize: Int? = 10) async throws -> Page<NoteDTO> {
        var items: [URLQueryItem] = []
        if let t = title { items.append(URLQueryItem(name: "title", value: t)) }
        if let d = description { items.append(URLQueryItem(name: "description", value: d)) }
        if let p = page { items.append(URLQueryItem(name: "page", value: String(p))) }
        if let ps = pageSize { items.append(URLQueryItem(name: "page_size", value: String(ps))) }
        var c = URLComponents(url: URL(string: "api/notes/filter", relativeTo: baseURL)!, resolvingAgainstBaseURL: true)!
        c.queryItems = items.count > 0 ? items : nil
        var req = URLRequest(url: c.url!)
        if let token = AuthManager.shared.access {
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshToken()
            return try await filterNotes(title: title, description: description, page: page, pageSize: pageSize)
        }
        return try JSONDecoder().decode(Page<NoteDTO>.self, from: data)
    }
    func createNote(title: String, description: String) async throws -> NoteDTO {
        let payload = NoteCreate(title: title, description: description)
        return try await request("api/notes/", method: "POST", body: payload)
    }
    func getNote(id: Int) async throws -> NoteDTO {
        try await request("api/notes/\(id)/")
    }
    func updateNote(id: Int, title: String, description: String) async throws -> NoteDTO {
        let payload = NoteCreate(title: title, description: description)
        return try await request("api/notes/\(id)/", method: "PUT", body: payload)
    }
    func deleteNote(id: Int) async throws {
        var req = URLRequest(url: URL(string: "api/notes/\(id)/", relativeTo: baseURL)!)
        req.httpMethod = "DELETE"
        if let token = AuthManager.shared.access { req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshToken()
            try await deleteNote(id: id)
        }
    }
}

struct Empty: Codable {}
