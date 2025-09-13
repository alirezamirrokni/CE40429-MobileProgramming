import SwiftUI

struct NoteDetailScreen: View {
    @EnvironmentObject var env: AppEnvironment
    let id: String
    @State private var note: NoteEntity?
    @State private var confirmDelete = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let n = note {
                Text(n.title).font(.title2).fontWeight(.bold)
                Text(n.content)
                Spacer()
                HStack {
                    NavigationLink("Edit") { EditNoteScreen(id: n.id) }
                    Spacer()
                    Button("Delete") { confirmDelete = true }.foregroundColor(.red)
                }
            }
        }.padding()
        .task { note = env.db.byId(id) }
        .alert("Delete note", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await Repository(api: env.api, db: env.db).delete(id: id)
                }
            }
        }
    }
}
