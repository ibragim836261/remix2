import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: RouterSettings
    @Published var password: String
    @Published var devices: [RouterDevice] = []
    @Published var schedules: [String] = []
    @Published var childMACs: Set<String> = []
    @Published var isConnected = false
    @Published var isWorking = false
    @Published var routerTitle = ""
    @Published var message: String?
    @Published var language: AppLanguage {
        didSet { L.language = language.rawValue; UserDefaults.standard.set(language.rawValue, forKey: "app.language") }
    }

    private var api: KeeneticAPI?
    private var nativeAPIAvailable = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "router.settings"),
           let saved = try? JSONDecoder().decode(RouterSettings.self, from: data) { settings = saved }
        else { settings = RouterSettings() }
        password = KeychainStore.read()
        let savedLanguage = UserDefaults.standard.string(forKey: "app.language") ?? "Русский"
        language = AppLanguage.allCases.first(where: { $0.rawValue == savedLanguage }) ?? .russian
        childMACs = Set(UserDefaults.standard.stringArray(forKey: "child.macs") ?? [])
        L.language = language.rawValue
    }

    var adminURL: URL? { settings.baseURL }
    var hasNativeDeviceControl: Bool { nativeAPIAvailable }

    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { message = "Не удалось сохранить настройки."; return }
        UserDefaults.standard.set(data, forKey: "router.settings")
        do { try KeychainStore.save(password); message = L.s("save_success") }
        catch { message = "Не удалось сохранить пароль в Keychain: \(error.localizedDescription)" }
    }

    func connect() async {
        guard Self.isLocalRouterHost(settings.host), let baseURL = settings.baseURL else {
            message = "Укажи локальный адрес роутера (например, 192.168.1.1 или 192.168.0.1)."
            return
        }
        isWorking = true
        defer { isWorking = false }
        nativeAPIAvailable = false
        api = nil
        if settings.brand == .auto || settings.brand == .keenetic {
            let candidate = KeeneticAPI(baseURL: baseURL, username: settings.username, password: password)
            do {
                routerTitle = try await candidate.checkConnection()
                api = candidate
                nativeAPIAvailable = true
                isConnected = true
                saveSettingsSilently()
                message = "\(L.s("connect_success")): \(routerTitle)"
                await refreshDevices()
                await refreshSchedules()
                return
            } catch {
                if settings.brand == .keenetic {
                    isConnected = false
                    message = error.localizedDescription
                    return
                }
            }
        }
        // For other vendors we only verify that the local admin page answers; no vendor API is guessed.
        do {
            var request = URLRequest(url: baseURL)
            request.timeoutInterval = 8
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                isConnected = true
                routerTitle = settings.brand == .auto ? "Веб-панель роутера" : settings.brand.rawValue
                message = "Панель отвечает. \(L.s("unsupported"))"
            } else {
                isConnected = false
                message = "Не удалось проверить веб-панель роутера."
            }
        } catch {
            isConnected = false
            message = "Не удалось подключиться: \(error.localizedDescription)"
        }
    }

    func refreshDevices() async {
        guard let api, nativeAPIAvailable else {
            message = L.s("only_keenetic")
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            devices = try await api.loadDevices()
            message = "Найдено устройств: \(devices.count)"
        } catch { message = error.localizedDescription }
    }

    func refreshSchedules() async {
        guard let api, nativeAPIAvailable else { schedules = []; return }
        do { schedules = try await api.loadSchedules() }
        catch { schedules = [] }
    }

    func setBlocked(_ device: RouterDevice, blocked: Bool) async {
        guard let api, nativeAPIAvailable else { message = L.s("unsupported"); return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.setBlocked(device, blocked: blocked)
            await refreshDevices()
            message = blocked ? "Интернет заблокирован на роутере." : "Доступ разрешён роутером."
        } catch { message = error.localizedDescription }
    }


    func blockManualMAC(_ rawMAC: String, name: String = "Устройство вручную") async {
        let mac = rawMAC.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard mac.range(of: "^[0-9A-F]{2}([:-])[0-9A-F]{2}(\\1[0-9A-F]{2}){4}$", options: .regularExpression) != nil else {
            message = "Проверь MAC-адрес. Формат: AA:BB:CC:DD:EE:FF"
            return
        }
        guard let api, nativeAPIAvailable else {
            message = "Для этой модели нет проверенного API-блокирования. Открой встроенный браузер и добавь MAC в Access Control / Blacklist."
            return
        }
        let normalized = mac.replacingOccurrences(of: "-", with: ":")
        let device = devices.first(where: { $0.mac.uppercased().replacingOccurrences(of: "-", with: ":") == normalized })
            ?? RouterDevice(name: name, mac: normalized, ip: "", isConnected: false, isBlocked: false)
        await setBlocked(device, blocked: true)
    }

    func setChild(_ device: RouterDevice, child: Bool) {
        let key = device.mac.uppercased()
        if child { childMACs.insert(key) } else { childMACs.remove(key) }
        UserDefaults.standard.set(Array(childMACs), forKey: "child.macs")
    }

    func applySchedule(_ schedule: String, to device: RouterDevice) async {
        guard let api, nativeAPIAvailable else { message = L.s("unsupported"); return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.assignSchedule(schedule, to: device)
            message = "Расписание «\(schedule)» подтверждено роутером для \(device.name)."
        } catch { message = error.localizedDescription }
    }

    private func saveSettingsSilently() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "router.settings")
        try? KeychainStore.save(password)
    }

    private static func isLocalRouterHost(_ raw: String) -> Bool {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = URL(string: cleaned.contains("://") ? cleaned : "http://" + cleaned)?.host ?? cleaned
        if host == "localhost" || host.hasSuffix(".local") || ["tplinkwifi.net", "routerlogin.net", "myrouter.local"].contains(host) { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        return parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 172 && (16...31).contains(parts[1])) ||
            (parts[0] == 100 && (64...127).contains(parts[1]))
    }
}
