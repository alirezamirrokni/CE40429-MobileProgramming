import Foundation
import SQLite3

final class Database {
    static let shared = Database()
    let path: String
    var db: OpaquePointer?
    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        path = dir.appendingPathComponent("simplenote.sqlite").path
        sqlite3_open(path, &db)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)
        let sql = "CREATE TABLE IF NOT EXISTS notes(id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, updatedAt INTEGER NOT NULL, createdAt INTEGER NOT NULL, dirty INTEGER NOT NULL, deleted INTEGER NOT NULL);"
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    func upsertNote(_ n: NoteEntity) {
        let sql = "INSERT OR REPLACE INTO notes(id,title,content,updatedAt,createdAt,dirty,deleted) VALUES(?,?,?,?,?,?,?)"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, n.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, n.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, n.content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 4, sqlite3_int64(n.updatedAt))
        sqlite3_bind_int64(stmt, 5, sqlite3_int64(n.createdAt))
        sqlite3_bind_int(stmt, 6, n.dirty ? 1 : 0)
        sqlite3_bind_int(stmt, 7, n.deleted ? 1 : 0)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
    func deleteNoteById(_ id: String) {
        let sql = "DELETE FROM notes WHERE id=?"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
    func byId(_ id: String) -> NoteEntity? {
        let sql = "SELECT id,title,content,updatedAt,createdAt,dirty,deleted FROM notes WHERE id=?"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let content = String(cString: sqlite3_column_text(stmt, 2))
            let updatedAt = Int(sqlite3_column_int64(stmt, 3))
            let createdAt = Int(sqlite3_column_int64(stmt, 4))
            let dirty = sqlite3_column_int(stmt, 5) != 0
            let deleted = sqlite3_column_int(stmt, 6) != 0
            sqlite3_finalize(stmt)
            return NoteEntity(id: id, title: title, content: content, updatedAt: updatedAt, createdAt: createdAt, dirty: dirty, deleted: deleted)
        }
        sqlite3_finalize(stmt)
        return nil
    }
    func paging(_ query: String, page: Int, pageSize: Int) -> [NoteEntity] {
        let like = "%\(query)%"
        let offset = (page - 1) * pageSize
        let sql = "SELECT id,title,content,updatedAt,createdAt,dirty,deleted FROM notes WHERE deleted=0 AND (title LIKE ? OR content LIKE ?) ORDER BY updatedAt DESC LIMIT ? OFFSET ?"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, like, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, like, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(pageSize))
        sqlite3_bind_int(stmt, 4, Int32(offset))
        var out: [NoteEntity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let content = String(cString: sqlite3_column_text(stmt, 2))
            let updatedAt = Int(sqlite3_column_int64(stmt, 3))
            let createdAt = Int(sqlite3_column_int64(stmt, 4))
            let dirty = sqlite3_column_int(stmt, 5) != 0
            let deleted = sqlite3_column_int(stmt, 6) != 0
            out.append(NoteEntity(id: id, title: title, content: content, updatedAt: updatedAt, createdAt: createdAt, dirty: dirty, deleted: deleted))
        }
        sqlite3_finalize(stmt)
        return out
    }
    func clear() {
        sqlite3_exec(db, "DELETE FROM notes", nil, nil, nil)
    }
}

struct NoteEntity: Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
    var updatedAt: Int
    var createdAt: Int
    var dirty: Bool
    var deleted: Bool
}
