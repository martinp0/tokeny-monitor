import SwiftUI
import TokenyCore

/// Home for an Apple ID that is saved only on this device. Nothing here is a Tokeny server session.
struct LocalIdentityView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false
    @State private var showingPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signed in with Apple on this device")
                        .font(.title2.bold())
                    if let name = model.auth.localAccount?.name, !name.isEmpty {
                        Text(name)
                            .font(.headline)
                    }
                    if let email = model.auth.email {
                        LabeledContent("Signed in as", value: email)
                    }
                    Text("This Apple ID is saved only on this device. Tokeny on the web does not have this sign-in yet, so spend here comes from a file or sample data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Import usage") { model.showsImportHub = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("View sample data") { model.showSample() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("See Tokeny Pro") { showingPaywall = true }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Delete Apple ID from this device", role: .destructive) { confirmingDelete = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                ScrollView {
                    ProPaywallView()
                        .padding(20)
                }
                .navigationTitle("Tokeny Pro")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPaywall = false }
                    }
                }
            }
        }
        .confirmationDialog("Remove the Apple ID saved on this device?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove from this device", role: .destructive) {
                Task { try? await model.deleteAccount() }
            }
        } message: {
            Text("This removes the Apple ID saved on this device. It does not delete a Tokeny account on the web.")
        }
    }

}
