import Foundation

struct RouterSettings: Codable {
    var host = "192.168.1.1"
    var username = "admin"
    var modelName = ""
    var brand: RouterBrand = .auto
    var provider = "Beeline Kazakhstan"
    var useHTTPS = false

    var baseURL: URL? {
        let raw = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let normalized = raw.contains("://") ? raw : "\(useHTTPS ? "https" : "http")://\(raw)"
        guard let url = URL(string: normalized),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
}

enum RouterBrand: String, CaseIterable, Codable, Identifiable {
    case auto = "Автоопределение"
    case keenetic = "Keenetic / Netcraze"
    case huawei = "Huawei / OptiXstar"
    case zte = "ZTE"
    case tpLink = "TP-Link"
    case asus = "ASUS"
    case mikrotik = "MikroTik"
    case xiaomi = "Xiaomi"
    case dLink = "D-Link"
    case nokia = "Nokia"
    case fiberHome = "FiberHome"
    case sercomm = "Sercomm"
    case sagemcom = "Sagemcom"
    case tenda = "Tenda"
    case mercusys = "Mercusys"
    case netis = "Netis"
    case ubiquiti = "Ubiquiti"
    case zyxel = "Zyxel"
    case cudy = "Cudy"
    case totolink = "Totolink"
    case linkSys = "Linksys"
    case h3c = "H3C"
    case ruijie = "Ruijie"

    var id: String { rawValue }
}

struct RouterDevice: Identifiable, Codable, Equatable {
    var id: String { mac.uppercased() }
    var name: String
    var mac: String
    var ip: String
    var isConnected: Bool
    var isBlocked: Bool
}

struct CompatibilityEntry: Identifiable {
    let brand: String
    let level: String
    let details: String
    var id: String { brand }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "Русский"
    case kazakh = "Қазақша"
    case english = "English"
    var id: String { rawValue }
}

let kazakhstanProviders = [
    "Beeline Kazakhstan", "Казахтелеком", "Tele2 / Altel", "AlmaTV",
    "Transtelecom", "Freedom Telecom", "Другой провайдер"
]

let routerCompatibility: [CompatibilityEntry] = [
    .init(brand: "Keenetic / Netcraze", level: "API", details: "Список клиентов, блокировка/разблокировка и привязка существующего расписания через RCI; зависит от прошивки и регистрации устройства."),
    .init(brand: "Huawei / OptiXstar", level: "Веб-панель", details: "Открытие панели. Родительский контроль на поддерживаемых CPE настраивается в самой панели; прямой API не подтверждён."),
    .init(brand: "TP-Link", level: "Веб-панель", details: "Открытие панели Access Control. Автоматическое управление зависит от конкретной модели и прошивки."),
    .init(brand: "ZTE, Nokia, FiberHome, Sercomm, Sagemcom", level: "Веб-панель", details: "Подключение к странице администратора. Универсального публичного API для всех моделей нет."),
    .init(brand: "ASUS, MikroTik, Xiaomi, D-Link, Tenda, Mercusys, Netis", level: "Веб-панель", details: "Профили производителя и переход к локальной панели; автоматические действия пока не заявляются."),
    .init(brand: "Ubiquiti, Zyxel, Cudy, Totolink, Linksys, H3C, Ruijie", level: "Веб-панель", details: "Локальная панель администратора; интеграция зависит от модели/прошивки.")
]
