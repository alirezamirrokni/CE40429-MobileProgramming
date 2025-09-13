import Foundation

@MainActor
final class Repository: ObservableObject {
    let api: APIClient
    let db: Database
    init(api: APIClient, db: Database) {
        self.api = api
        self.db = db
    }
    func login(username: String, password: String) async throws {
        try await api.login(username: username, password: password)
    }
    func register(first: String, last: String, username: String, email: String, password: String) async throws {
        try await api.register(username: username, email: email, password: password, first: first, last: last)
        try await api.login(username: username, password: password)
    }
    func logout() {
        AuthManager.shared.clear()
        db.clear()
    }
    func userInfo() async throws -> UserInfo {
        try await api.userinfo()
    }
    func changePassword(old: String, new: String) async throws {
        try await api.changePassword(old: old, new: new)
    }
    func notesPaged(query: String, page: Int, pageSize: Int) -> [NoteEntity] {
        db.paging(query, page: page, pageSize: pageSize)
    }
    func syncOnce(query: String) async {
        do {
            var page = 1
            while true {
                let p: Page<NoteDTO>
                if query.isEmpty {
                    p = try await api.listNotes(page: page, pageSize: 10)
                } else {
                    p = try await api.filterNotes(title: query, description: query, page: page, pageSize: 10)
                }
                for d in p.results {
                    let updated = ISO8601DateFormatter().date(from: d.updated_at) ?? Date()
                    let created = ISO8601DateFormatter().date(from: d.created_at) ?? Date()
                    let n = NoteEntity(id: String(d.id), title: d.title, content: d.description, updatedAt: Int(updated.timeIntervalSince1970 * 1000), createdAt: Int(created.timeIntervalSince1970 * 1000), dirty: false, deleted: false)
                    db.upsertNote(n)
                }
                if p.next == nil { break }
                page += 1
            }
        } catch {}
    }
    func create(title: String, content: String) async -> String {
        do {
            let dto = try await api.createNote(title: title, description: content)
            let updated = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
            let created = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
            let id = String(dto.id)
            let n = NoteEntity(id: id, title: dto.title, content: dto.description, updatedAt: Int(updated.timeIntervalSince1970 * 1000), createdAt: Int(created.timeIntervalSince1970 * 1000), dirty: false, deleted: false)
            db.upsertNote(n)
            return id
        } catch {
            let id = UUID().uuidString
            let now = Int(Date().timeIntervalSince1970 * 1000)
            db.upsertNote(NoteEntity(id: id, title: title, content: content, updatedAt: now, createdAt: now, dirty: true, deleted: false))
            return id
        }
    }
    func update(id: String, title: String, content: String) async {
        do {
            let nid = Int(id) ?? -1
            if nid > 0 {
                let dto = try await api.updateNote(id: nid, title: title, description: content)
                let updated = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
                let created = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
                let n = NoteEntity(id: String(dto.id), title: dto.title, content: dto.description, updatedAt: Int(updated.timeIntervalSince1970 * 1000), createdAt: Int(created.timeIntervalSince1970 * 1000), dirty: false, deleted: false)
                db.upsertNote(n)
            } else {
                let cur = db.byId(id) ?? NoteEntity(id: id, title: title, content: content, updatedAt: Int(Date().timeIntervalSince1970 * 1000), createdAt: Int(Date().timeIntervalSince1970 * 1000), dirty: true, deleted: false)
                db.upsertNote(NoteEntity(id: id, title: title, content: content, updatedAt: Int(Date().timeIntervalSince1970 * 1000), createdAt: cur.createdAt, dirty: true, deleted: false))
            }
        } catch {
            let cur = db.byId(id) ?? NoteEntity(id: id, title: title, content: content, updatedAt: Int(Date().timeIntervalSince1970 * 1000), createdAt: Int(Date().timeIntervalSince1970 * 1000), dirty: true, deleted: false)
            db.upsertNote(NoteEntity(id: id, title: title, content: content, updatedAt: Int(Date().timeIntervalSince1970 * 1000), createdAt: cur.createdAt, dirty: true, deleted: false))
        }
    }
    func delete(id: String) async {
        do {
            let nid = Int(id) ?? -1
            if nid > 0 {
                try await api.deleteNote(id: nid)
                db.deleteNoteById(id)
            } else {
                if let cur = db.byId(id) {
                    db.upsertNote(NoteEntity(id: id, title: cur.title, content: cur.content, updatedAt: cur.updatedAt, createdAt: cur.createdAt, dirty: cur.dirty, deleted: true))
                }
            }
        } catch {
            if let cur = db.byId(id) {
                db.upsertNote(NoteEntity(id: id, title: cur.title, content: cur.content, updatedAt: cur.updatedAt, createdAt: cur.createdAt, dirty: cur.dirty, deleted: true))
            }
        }
    }
    func note(id: String) -> NoteEntity? {
        db.byId(id)
    }
}
