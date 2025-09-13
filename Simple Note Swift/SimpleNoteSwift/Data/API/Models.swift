import Foundation

struct TokenResponse: Codable {
    let access: String
    let refresh: String?
}

struct TokenObtainPairRequest: Codable {
    let username: String
    let password: String
}

struct TokenRefreshRequest: Codable {
    let refresh: String
}

struct RegisterRequest: Codable {
    let username: String
    let password: String
    let email: String
    let first_name: String?
    let last_name: String?
}

struct ChangePasswordRequest: Codable {
    let old_password: String
    let new_password: String
}

struct NoteDTO: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let created_at: String
    let updated_at: String
}

struct NoteCreate: Codable {
    let title: String
    let description: String
}

struct Page<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

struct UserInfo: Codable {
    let id: Int
    let username: String
    let email: String
    let first_name: String?
    let last_name: String?
}
