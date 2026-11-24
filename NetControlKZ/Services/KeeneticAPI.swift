import Foundation

private final class RouterAuthDelegate: NSObject, URLSessionTaskDelegate {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodHTTPDigest {
            let credential = URLCredential(user: username, password: password, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

final class KeeneticAPI {
    private let baseURL: URL
    private let session: URLSession
    private let authDelegate: RouterAuthDelegate

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.authDelegate = RouterAuthDelegate(username: username, password: password)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config, delegate: authDelegate, delegateQueue: nil)
    }

    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: [String: Any]? = nil) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RouterAPIError.invalidAddress
        }
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw RouterAPIError.invalidAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RouterAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 { throw RouterAPIError.authentication }
            throw RouterAPIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func checkConnection() async throws -> String {
        let data = try await request("/rci/show/version")
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let model = (object["model"] as? String) ?? (object["title"] as? String) ?? "Keenetic"
        return model
    }

    func loadDevices() async throws -> [RouterDevice] {
        let paths = ["/rci/show/associations", "/rci/show/ip/dhcp/bindings", "/rci/show/ip/hotspot"]
        var merged: [String: RouterDevice] = [:]
        var successCount = 0
        for path in paths {
            guard let data = try? await request(path) else { continue }
            successCount += 1
            for device in Self.extractDevices(from: data) {
                let key = device.mac.uppercased()
                if let old = merged[key] {
                    merged[key] = RouterDevice(
                        name: device.name == "Unknown" ? old.name : device.name,
                        mac: device.mac,
                        ip: device.ip.isEmpty ? old.ip : device.ip,
                        isConnected: old.isConnected || device.isConnected,
                        isBlocked: old.isBlocked || device.isBlocked
                    )
                } else {
                    merged[key] = device
                }
            }
        }
        guard successCount > 0 else { throw RouterAPIError.noDeviceData }
        return merged.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setBlocked(_ device: RouterDevice, blocked: Bool) async throws {
        let mac = Self.normalizedMAC(device.mac)
        guard !mac.isEmpty else { throw RouterAPIError.missingMAC }
        // Keenetic requires a host to be registered before applying a hotspot access rule.
        _ = try await request("/rci/known/host", method: "POST",
                              query: [URLQueryItem(name: "mac", value: mac)],
                              body: ["name": device.name.isEmpty ? "LANControl" : device.name])
        _ = try await request("/rci/ip/hotspot/host", method: "POST",
                              query: [URLQueryItem(name: "mac", value: mac)],
                              body: [blocked ? "deny" : "permit": true])
        let verify = try await request("/rci/ip/hotspot/host", query: [URLQueryItem(name: "mac", value: mac)])
        guard Self.confirmAccessState(data: verify, blocked: blocked) else {
            throw RouterAPIError.notConfirmed
        }
    }

    func loadSchedules() async throws -> [String] {
        let data = try await request("/rci/schedule")
        var names = Set<String>()
        Self.collectScheduleNames((try? JSONSerialization.jsonObject(with: data)) as Any, into: &names)
        return names.sorted()
    }

    func assignSchedule(_ name: String, to device: RouterDevice) async throws {
        let mac = Self.normalizedMAC(device.mac)
        guard !mac.isEmpty else { throw RouterAPIError.missingMAC }
        _ = try await request("/rci/known/host", method: "POST",
                              query: [URLQueryItem(name: "mac", value: mac)],
                              body: ["name": device.name.isEmpty ? "LANControl" : device.name])
        _ = try await request("/rci/ip/hotspot/host", method: "POST",
                              query: [URLQueryItem(name: "mac", value: mac)],
                              body: ["schedule": name])
        let verify = try await request("/rci/ip/hotspot/host", query: [URLQueryItem(name: "mac", value: mac)])
        guard Self.contains(value: name, in: (try? JSONSerialization.jsonObject(with: verify)) as Any) else {
            throw RouterAPIError.notConfirmed
        }
    }

    private static func normalizedMAC(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func validMAC(_ value: String) -> Bool {
        value.range(of: "^[0-9A-Fa-f]{2}([:-])[0-9A-Fa-f]{2}(\\1[0-9A-Fa-f]{2}){4}$", options: .regularExpression) != nil
    }

    private static func extractDevices(from data: Data) -> [RouterDevice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var found: [String: RouterDevice] = [:]
        func walk(_ value: Any) {
            if let array = value as? [Any] { array.forEach(walk); return }
            guard let dict = value as? [String: Any] else { return }
            var lower: [String: Any] = [:]
            for (key, value) in dict { lower[key.lowercased()] = value }
            var mac = (lower["mac"] as? String) ?? (lower["macaddress"] as? String) ?? (lower["hwaddr"] as? String) ?? (lower["hardwareaddress"] as? String) ?? ""
            if mac.isEmpty {
                mac = dict.keys.first(where: { validMAC($0) }) ?? ""
            }
            if validMAC(mac) {
                let name = (lower["name"] as? String) ?? (lower["hostname"] as? String) ?? (lower["description"] as? String) ?? "Unknown"
                let ip = (lower["ip"] as? String) ?? (lower["address"] as? String) ?? (lower["ipaddress"] as? String) ?? ""
                let connected = (lower["active"] as? Bool) ?? (lower["connected"] as? Bool) ?? (lower["online"] as? Bool) ?? true
                let denied = (lower["deny"] as? Bool) == true || (lower["blocked"] as? Bool) == true || (lower["access"] as? String)?.lowercased() == "deny"
                let permitted = (lower["permit"] as? Bool) == true || (lower["access"] as? String)?.lowercased() == "permit"
                let candidate = RouterDevice(name: name, mac: mac, ip: ip, isConnected: connected, isBlocked: denied && !permitted)
                let key = mac.uppercased()
                if let old = found[key] {
                    found[key] = RouterDevice(name: candidate.name == "Unknown" ? old.name : candidate.name,
                                              mac: candidate.mac, ip: candidate.ip.isEmpty ? old.ip : candidate.ip,
                                              isConnected: old.isConnected || candidate.isConnected,
                                              isBlocked: old.isBlocked || candidate.isBlocked)
                } else { found[key] = candidate }
            }
            for (key, child) in dict where validMAC(key) {
                if let childDict = child as? [String: Any] {
                    var augmented = childDict
                    augmented["mac"] = key
                    walk(augmented)
                }
            }
            dict.values.forEach(walk)
        }
        walk(root)
        return Array(found.values)
    }

    private static func confirmAccessState(data: Data, blocked: Bool) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return false }
        var values: [String: Any] = [:]
        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                for (key, child) in dict { values[key.lowercased()] = child; walk(child) }
            } else if let array = value as? [Any] { array.forEach(walk) }
        }
        walk(object)
        if blocked { return (values["deny"] as? Bool) == true || (values["access"] as? String)?.lowercased() == "deny" }
        return (values["permit"] as? Bool) == true || (values["access"] as? String)?.lowercased() == "permit"
    }

    private static func contains(value: String, in object: Any) -> Bool {
        if let string = object as? String { return string == value }
        if let dict = object as? [String: Any] { return dict.contains { $0.key == value || contains(value: value, in: $0.value) } }
        if let array = object as? [Any] { return array.contains { contains(value: value, in: $0) } }
        return false
    }

    private static func collectScheduleNames(_ object: Any, into names: inout Set<String>) {
        func walk(_ value: Any, directScheduleChildren: Bool) {
            if let dict = value as? [String: Any] {
                if let name = dict["name"] as? String, !name.isEmpty { names.insert(name) }
                for (key, child) in dict {
                    if directScheduleChildren,
                       key.range(of: "^[A-Za-z0-9_-]{2,40}$", options: .regularExpression) != nil,
                       child is [String: Any] {
                        names.insert(key)
                    }
                    walk(child, directScheduleChildren: false)
                }
            } else if let array = value as? [Any] {
                array.forEach { walk($0, directScheduleChildren: false) }
            }
        }
        // GET /rci/schedule returns the schedule branch; its direct object keys are schedule names.
        walk(object, directScheduleChildren: true)
    }
}

enum RouterAPIError: LocalizedError {
    case invalidAddress, invalidResponse, authentication, http(Int, String), noDeviceData, missingMAC, notConfirmed
    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Неверный адрес роутера. Укажи локальный IP, например 192.168.1.1."
        case .invalidResponse: return "Роутер вернул некорректный ответ."
        case .authentication: return "Роутер отклонил логин или пароль."
        case .http(let code, _): return "Ошибка роутера (HTTP \(code))."
        case .noDeviceData: return "Не удалось получить список устройств через API. Проверь модель и права пользователя."
        case .missingMAC: return "У устройства нет MAC-адреса."
        case .notConfirmed: return "Роутер не подтвердил изменение. Приложение не отметило действие как успешное."
        }
    }
}
