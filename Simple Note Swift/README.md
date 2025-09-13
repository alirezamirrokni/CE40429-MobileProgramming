# SimpleNoteSwift

A SwiftUI rewrite of the Kotlin **SimpleNote** app with the same features and flow: authentication with refresh tokens, offline‑first notes with local SQLite storage, remote sync, search, and CRUD.

---

## ✨ Features

- Sign up / Log in (JWT) and automatic refresh on 401
- List notes with paging + local caching
- Full‑text search by title/description
- View note details
- Create / Edit / Delete
- Profile and log out
- Offline‑first: everything backed by local SQLite, syncs when online
- No external dependencies; uses `URLSession`, `Security` (Keychain), and `libsqlite3`

---

## 🧱 Tech Stack

- SwiftUI app lifecycle (`@main`)
- `URLSession` with `async/await` for networking
- Keychain Services for secure token storage
- SQLite (C API) for a compact local store
- Simple JWT compatible backend (Django/DRF)

---

## 🗂 Project Structure

```
SimpleNoteSwift/
├── SimpleNoteSwift.xcodeproj
└── SimpleNoteSwift/
    ├── App.swift
    ├── Environment.swift
    ├── Assets.xcassets/
    ├── Info.plist
    ├── Data/
    │   ├── API/
    │   │   ├── APIClient.swift
    │   │   └── Models.swift
    │   ├── Auth/
    │   │   ├── AuthManager.swift
    │   │   └── Keychain.swift
    │   ├── Persistence/
    │   │   └── Database.swift
    │   └── Repository.swift
    └── UI/
        ├── RootView.swift
        ├── Auth/
        │   ├── OnboardingView.swift
        │   ├── LoginView.swift
        │   └── RegisterView.swift
        ├── Home/
        │   └── HomeScreen.swift
        ├── Notes/
        │   ├── EditNoteView.swift
        │   └── NoteDetailView.swift
        └── Settings/
            └── SettingsScreen.swift
```

---

## 🧭 Architecture

```
flowchart LR
    A[SwiftUI Views] --> B[Repository]
    B --> C[APIClient\nURLSession async/await]
    B --> D[SQLite DB\n(libsqlite3)]
    C -- JWT access --> E[(Backend)]
    C <-- 401/refresh --> F[AuthManager+Keychain]
    F --> C
    D <--> B
```

- `APIClient` performs requests and, on `401`, refreshes tokens then retries once.
- `Repository` exposes use‑cases (login, sync, CRUD) and keeps SQLite in sync with server pages.
- `Database` is a small wrapper over SQLite C API with one `notes` table (`id, title, content, updatedAt, createdAt, dirty, deleted`).
- `AuthManager` persists tokens in the Keychain.

---

## 🚀 Getting Started

### Requirements
- Xcode 15+
- iOS 15+ (simulator or device)

### Run
1. Open `SimpleNoteSwift.xcodeproj` in Xcode.
2. Select any iOS 15+ Simulator.
3. Set a Development Team under **Signing & Capabilities** if running on device.
4. Update the backend base URL if needed (see **Configuration** below).
5. Build & Run.

### Configuration
Open `SimpleNoteSwift/Environment.swift` and set the backend URL:
```swift
@Published var api = APIClient(baseURL: URL(string: "https://your-backend.example/")!)
```
If you are using DRF + Simple JWT, the default endpoints used are:
```
POST   api/auth/token/            -> obtain access/refresh
POST   api/auth/token/refresh/    -> refresh access (optionally returns new refresh)
POST   api/auth/register/         -> register
GET    api/auth/userinfo/         -> current user
POST   api/auth/change-password/  -> change password
GET    api/notes/                 -> list (page, page_size)
GET    api/notes/filter           -> filter (title, description, page, page_size)
GET    api/notes/{id}/            -> detail
POST   api/notes/                 -> create
PUT    api/notes/{id}/            -> update
DELETE api/notes/{id}/            -> delete
```

---

## 🔁 Offline‑First & Sync

- Notes are stored in a local SQLite database.
- On app start and whenever the search query changes, `Repository.syncOnce(query:)` requests server pages until `next == null` and upserts into SQLite.
- Creating/updating while offline writes locally and marks items `dirty`. Deletions on unsynced local items are marked `deleted`. On reconnect, server operations apply and local rows are reconciled.

---

## 🔐 Authentication

- Access and refresh tokens are stored securely in the Keychain.
- Each network call includes `Authorization: Bearer <access>` when available.
- If a request returns 401, a refresh request is made; on success the original request is replayed once.

---

## 🧪 API Docs & Postman

If your backend exposes OpenAPI docs (for example, DRF Spectacular), you can usually view interactive docs at:
```
/api/schema/redoc/
```
From there, download the OpenAPI spec and import it into Postman (**Import → OpenAPI**).

---

## 🛠 Implementation Notes

### Networking
- `URLSession` `data(for:)` `async/await` is used for all requests and retries.
- JSON encoding/decoding via `Codable` for request/response models.

### Local Database
- The app links against `libsqlite3` and calls the SQLite C API directly (`sqlite3_open`, `sqlite3_exec`, prepared statements).
- Schema:
  ```sql
  CREATE TABLE IF NOT EXISTS notes(
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    updatedAt INTEGER NOT NULL,
    createdAt INTEGER NOT NULL,
    dirty INTEGER NOT NULL,
    deleted INTEGER NOT NULL
  );
  ```

### Security
- Tokens are saved in the iOS Keychain (generic password entries).
- For development against non‑TLS servers you may need ATS exceptions; the project ships with `NSAppTransportSecurity` allowing arbitrary loads. Remove or scope these before release.

---

## 🧰 Troubleshooting

- **Login succeeds but notes don’t load**  
  Verify the base URL and endpoints; check that your account has notes and that the server returns paginated results for `/api/notes/`.
- **HTTP blocked**  
  Use HTTPS on the server or add an ATS exception only for your domain. Prefer TLS in production.
- **401 loops**  
  Ensure the refresh token is valid and the refresh endpoint returns a new access token; rotate refresh tokens if your backend is configured to do so.
- **SQLite file location**  
  The database is created under the app’s Documents directory as `simplenote.sqlite`.

