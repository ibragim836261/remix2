import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            DashboardView().tabItem { Label(L.s("dashboard"), systemImage: "house.fill") }
            DevicesView().tabItem { Label(L.s("devices"), systemImage: "wifi") }
            BlacklistView().tabItem { Label(L.s("blacklist"), systemImage: "hand.raised.fill") }
            ParentalControlView().tabItem { Label(L.s("parental"), systemImage: "person.2.fill") }
            SettingsView().tabItem { Label(L.s("settings"), systemImage: "gearshape.fill") }
        }
        .tint(.cyan)
        .alert("LANControl KZ", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(L.s("cancel"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showBrowser = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LANControl KZ").font(.largeTitle.bold())
                        Text("Управление домашней сетью") .foregroundStyle(.secondary)
                    }
                    statusCard
                    HStack(spacing: 12) {
                        metricCard(title: "Устройства", value: "\(model.devices.count)", icon: "wifi")
                        metricCard(title: "В чёрном списке", value: "\(model.devices.filter(\.isBlocked).count)", icon: "hand.raised")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.s("router")).font(.headline)
                        Text("\(model.settings.brand.rawValue) • \(model.settings.host)").foregroundStyle(.secondary)
                        Button { Task { await model.connect() } } label: {
                            Label(model.isWorking ? L.s("connecting") : L.s("connect"), systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).disabled(model.isWorking)
                        Button { showBrowser = true } label: {
                            Label(L.s("open_admin"), systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }.padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    Text(L.s("local_network")).font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showBrowser) {
                if let url = model.adminURL { RouterBrowserView(url: url) }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: model.isConnected ? "checkmark.shield.fill" : "wifi.slash")
                .font(.title).foregroundStyle(model.isConnected ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.isConnected ? L.s("connected") : L.s("not_connected")).font(.headline)
                Text(model.routerTitle.isEmpty ? "Проверь подключение к Wi‑Fi роутера" : model.routerTitle)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.cyan)
            Text(value).font(.title.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct DevicesView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationStack {
            Group {
                if model.devices.isEmpty {
                    EmptyStateView(title: L.s("no_devices"), icon: "wifi.slash", detail: L.s("only_keenetic"))
                } else {
                    List(model.devices) { device in
                        DeviceRow(device: device)
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L.s("devices"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await model.refreshDevices() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(model.isWorking)
                }
            }
        }
    }
}

struct DeviceRow: View {
    @EnvironmentObject private var model: AppModel
    let device: RouterDevice
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isConnected ? "iphone.gen3" : "desktopcomputer")
                .font(.title2).frame(width: 32).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.headline)
                Text([device.ip, device.mac].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption2).foregroundStyle(.secondary)
                if device.isBlocked { Text(L.s("blocked")).font(.caption).foregroundStyle(.orange) }
            }
            Spacer(minLength: 6)
            Button {
                Task { await model.setBlocked(device, blocked: !device.isBlocked) }
            } label: {
                Image(systemName: device.isBlocked ? "lock.open" : "hand.raised.fill")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .disabled(model.isWorking || device.mac.isEmpty)
            .accessibilityLabel(device.isBlocked ? L.s("allow") : L.s("block"))
        }.padding(.vertical, 4)
    }
}

struct BlacklistView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showBrowser = false
    @State private var manualMAC = ""
    @State private var manualName = ""
    private var blocked: [RouterDevice] { model.devices.filter(\.isBlocked) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Добавить вручную по MAC") {
                        TextField("MAC: AA:BB:CC:DD:EE:FF", text: $manualMAC)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        TextField("Имя устройства (необязательно)", text: $manualName)
                        Button {
                            Task {
                                await model.blockManualMAC(manualMAC, name: manualName.isEmpty ? "Устройство вручную" : manualName)
                                if !model.hasNativeDeviceControl { showBrowser = true }
                                manualMAC = ""
                                manualName = ""
                            }
                        } label: { Label("Добавить в чёрный список", systemImage: "hand.raised.fill") }
                        .disabled(manualMAC.isEmpty || model.isWorking)
                        Text("Для роутеров без API откроется встроенный браузер. В нём войди в панель и добавь MAC в Access Control / Blacklist.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.frame(maxHeight: 245)
                Group {
                if blocked.isEmpty {
                    VStack(spacing: 12) {
                        EmptyStateView(title: L.s("empty_blacklist"), icon: "checkmark.shield", detail: "Заблокированные устройства появятся здесь после подтверждения роутером.")
                        Button(L.s("open_admin")) { showBrowser = true }.buttonStyle(.bordered)
                    }
                } else {
                    List(blocked) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name).font(.headline)
                                Text(device.mac).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(L.s("allow")) { Task { await model.setBlocked(device, blocked: false) } }
                                .buttonStyle(.bordered)
                                .disabled(model.isWorking)
                        }
                    }.listStyle(.insetGrouped)
                }
                }
            }
            .navigationTitle(L.s("blacklist"))
            .sheet(isPresented: $showBrowser) { if let url = model.adminURL { RouterBrowserView(url: url) } }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await model.refreshDevices() } } label: { Image(systemName: "arrow.clockwise") } } }
        }
    }
}

struct ParentalControlView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showBrowser = false
    @State private var selectedMAC = ""
    @State private var selectedSchedule = ""

    private var childDevices: [RouterDevice] { model.devices.filter { model.childMACs.contains($0.mac.uppercased()) } }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.s("child_device")) {
                    if model.devices.isEmpty {
                        Text(L.s("no_devices")).foregroundStyle(.secondary)
                        Text(L.s("only_keenetic")).font(.footnote).foregroundStyle(.secondary)
                        Button(L.s("open_admin")) { showBrowser = true }
                    } else {
                        ForEach(model.devices) { device in
                            Toggle(isOn: Binding(
                                get: { model.childMACs.contains(device.mac.uppercased()) },
                                set: { model.setChild(device, child: $0) }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text(device.mac).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section(L.s("router_schedules")) {
                    if childDevices.isEmpty {
                        Text("Сначала отметь устройства ребёнка.").foregroundStyle(.secondary)
                    } else {
                        Picker("Устройство", selection: $selectedMAC) {
                            Text("Выбери устройство").tag("")
                            ForEach(childDevices) { device in Text(device.name).tag(device.mac.uppercased()) }
                        }
                        Picker("Расписание", selection: $selectedSchedule) {
                            Text("Выбери расписание").tag("")
                            ForEach(model.schedules, id: \.self) { Text($0).tag($0) }
                        }
                        if model.schedules.isEmpty { Text(L.s("no_schedules")).foregroundStyle(.secondary) }
                        Button(L.s("apply_schedule")) {
                            guard let device = childDevices.first(where: { $0.mac.uppercased() == selectedMAC }) else { return }
                            Task { await model.applySchedule(selectedSchedule, to: device) }
                        }
                        .disabled(selectedMAC.isEmpty || selectedSchedule.isEmpty || model.isWorking)
                    }
                    Text(L.s("schedule_note")).font(.footnote).foregroundStyle(.secondary)
                }
                Section("Быстрые действия") {
                    ForEach(childDevices) { device in
                        HStack {
                            Text(device.name)
                            Spacer()
                            Button(device.isBlocked ? L.s("allow") : L.s("block")) {
                                Task { await model.setBlocked(device, blocked: !device.isBlocked) }
                            }.buttonStyle(.bordered).disabled(model.isWorking)
                        }
                    }
                }
            }
            .navigationTitle(L.s("parental"))
            .sheet(isPresented: $showBrowser) { if let url = model.adminURL { RouterBrowserView(url: url) } }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await model.refreshSchedules() } } label: { Image(systemName: "arrow.clockwise") } } }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showCompatibility = false
    @State private var showBrowser = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L.s("router")) {
                    TextField("URL роутера (например, http://192.168.1.1)", text: $model.settings.host).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField(L.s("username"), text: $model.settings.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Модель роутера (например, ZTE F680)", text: $model.settings.modelName).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(L.s("password"), text: $model.password)
                    Toggle("HTTPS", isOn: $model.settings.useHTTPS)
                    Picker(L.s("provider"), selection: $model.settings.provider) {
                        ForEach(kazakhstanProviders, id: \.self) { Text($0).tag($0) }
                    }
                    Picker(L.s("brand"), selection: $model.settings.brand) {
                        ForEach(RouterBrand.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(L.s("provider_note")).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button(L.s("save")) { model.saveSettings() }
                    Button(L.s("connect")) { Task { await model.connect() } }.disabled(model.isWorking)
                    Button(L.s("open_admin")) { showBrowser = true }
                    Button(L.s("compatibility")) { showCompatibility = true }
                }
                Section(L.s("language")) {
                    Picker(L.s("language"), selection: $model.language) {
                        ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Конфиденциальность") { Text(L.s("privacy")).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(L.s("settings"))
            .sheet(isPresented: $showCompatibility) { CompatibilityView() }
            .sheet(isPresented: $showBrowser) { if let url = model.adminURL { RouterBrowserView(url: url) } }
        }
    }
}

struct CompatibilityView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(routerCompatibility) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.brand).font(.headline)
                        Spacer()
                        Text(item.level).font(.caption).foregroundStyle(.cyan)
                    }
                    Text(item.details).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            .navigationTitle(L.s("compatibility"))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(L.s("cancel")) { dismiss() } } }
        }
    }
}

struct RouterBrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var currentURL: URL?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Введите URL роутера", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .textFieldStyle(.roundedBorder).onSubmit { navigate() }
                    Button("Перейти") { navigate() }.buttonStyle(.borderedProminent)
                }.padding()
                if let currentURL {
                    RouterWebView(url: currentURL).ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("Введите адрес роутера", systemImage: "safari", description: Text("Например: http://192.168.1.1"))
                }
            }
            .navigationTitle("Браузер роутера")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(L.s("cancel")) { dismiss() } } }
            .onAppear { address = url.absoluteString; currentURL = url }
        }
    }
    private func navigate() {
        let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = URL(string: raw.contains("://") ? raw : "http://" + raw)
        guard let candidate, ["http", "https"].contains(candidate.scheme?.lowercased() ?? ""), candidate.host != nil else { return }
        currentURL = candidate
    }
}

struct RouterWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url { uiView.load(URLRequest(url: url)) }
    }
}

struct EmptyStateView: View {
    let title: String
    let icon: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 42)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
