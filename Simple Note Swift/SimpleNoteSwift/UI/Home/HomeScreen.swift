import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var vm = HomeVM()
    @State private var showCreate = false
    var body: some View {
        VStack {
            HStack {
                TextField("Search", text: $vm.query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                    .onChange(of: vm.query) { q in
                        Task { await vm.sync(env: env, q: q) }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                NavigationLink("Settings") { SettingsScreen() }
            }.padding()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vm.items, id: \.id) { n in
                        NoteCard(note: n).onTapGesture { vm.selected = n }
                    }
                }.padding(.horizontal)
            }
            Button { showCreate = true } label: { Text("+").frame(width: 56, height: 56).background(.blue).foregroundColor(.white).clipShape(Circle()) }.padding(.bottom, 12)
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await vm.reload(env: env) } }) {
            EditNoteScreen(id: nil)
        }
        .navigationDestination(isPresented: Binding(get: { vm.selected != nil }, set: { if !$0 { vm.selected = nil } })) {
            if let n = vm.selected { NoteDetailScreen(id: n.id) }
        }
        .task { await vm.initial(env: env) }
        .navigationTitle("Notes")
    }
}

final class HomeVM: ObservableObject {
    @Published var query = ""
    @Published var page = 1
    @Published var items: [NoteEntity] = []
    @Published var selected: NoteEntity?
    func initial(env: AppEnvironment) async {
        await sync(env: env, q: "")
        await reload(env: env)
    }
    func reload(env: AppEnvironment) async {
        items = Repository(api: env.api, db: env.db).notesPaged(query: query, page: 1, pageSize: 100)
    }
    func sync(env: AppEnvironment, q: String) async {
        await Repository(api: env.api, db: env.db).syncOnce(query: q)
        await reload(env: env)
    }
}

struct NoteCard: View {
    let note: NoteEntity
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title).fontWeight(.semibold).lineLimit(2)
            Text(note.content).lineLimit(6).foregroundColor(.secondary).font(.subheadline)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(radius: 1)
    }
}
