import Foundation

final class AppEnvironment: ObservableObject {
    @Published var api = APIClient(baseURL: URL(string: "https://simple.darkube.app/")!)
    @Published var db = Database.shared
    @Published var auth = AuthManager.shared
}
