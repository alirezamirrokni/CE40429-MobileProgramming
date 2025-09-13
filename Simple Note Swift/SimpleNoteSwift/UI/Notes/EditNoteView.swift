import SwiftUI

struct EditNoteScreen: View {
    @EnvironmentObject var env: AppEnvironment
    let id: String?
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextEditor(text: $content).frame(height: 200)
            }
            Section {
                Button(id == nil ? "Create" : "Save") {
                    Task {
                        if let id = id {
                            await Repository(api: env.api, db: env.db).update(id: id, title: title, content: content)
                        } else {
                            let newId = await Repository(api: env.api, db: env.db).create(title: title, content: content)
                            let _ = newId
                        }
                        dismiss()
                    }
                }
            }
        }.onAppear {
            if let id = id, let n = env.db.byId(id) {
                title = n.title
                content = n.content
            }
        }
    }
}
