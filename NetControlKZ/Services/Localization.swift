import Foundation

enum L {
    static var language = UserDefaults.standard.string(forKey: "app.language") ?? "Русский"

    private static let ru: [String: String] = [
        "dashboard":"Главная", "devices":"Устройства", "blacklist":"Чёрный список", "parental":"Родительский контроль", "settings":"Настройки",
        "router":"Роутер", "connected":"Подключено", "not_connected":"Не подключено", "connect":"Подключиться", "refresh":"Обновить устройства",
        "open_admin":"Открыть панель роутера", "host":"Адрес роутера", "username":"Логин", "password":"Пароль администратора",
        "provider":"Провайдер", "brand":"Производитель роутера", "save":"Сохранить настройки", "no_devices":"Устройства пока не загружены",
        "blocked":"Заблокировано", "allow":"Разблокировать", "block":"Заблокировать интернет", "connected_devices":"Подключённые устройства",
        "apply_schedule":"Применить расписание", "router_schedules":"Расписания в роутере", "child_device":"Устройство ребёнка",
        "mark_child":"Добавить в детские устройства", "remove_child":"Убрать из детских устройств", "no_schedules":"Расписания не найдены",
        "schedule_note":"Создай расписание в панели роутера, затем выбери его здесь. Поддержка зависит от модели.",
        "compatibility":"Совместимость", "language":"Язык приложения", "status":"Статус", "unknown":"Неизвестно",
        "local_network":"Для работы нужен доступ к локальной сети iPhone.", "only_keenetic":"Автоматическое управление устройствами сейчас доступно для Keenetic/Netcraze с поддерживаемой RCI.",
        "empty_blacklist":"Чёрный список пуст", "save_success":"Настройки сохранены", "connect_success":"Роутер отвечает", "need_mac":"У устройства нет MAC-адреса — действие невозможно.",
        "native_api":"Управление через API", "web_only":"Только веб-панель", "cancel":"Закрыть", "router_page":"Панель роутера",
        "profile":"Профиль", "provider_note":"Провайдер — это подсказка для выбора профиля. Реальная совместимость определяется моделью и прошивкой роутера.",
        "privacy":"Пароль хранится в связке ключей iOS. Приложение не отправляет данные на сторонний сервер.", "unsupported":"Для этой модели пока доступна только веб-панель.",
        "language_ru":"Русский", "language_kk":"Қазақша", "language_en":"English", "connecting":"Проверка подключения…"
    ]
    private static let kk: [String: String] = [
        "dashboard":"Басты бет", "devices":"Құрылғылар", "blacklist":"Қара тізім", "parental":"Ата-ана бақылауы", "settings":"Параметрлер",
        "router":"Маршрутизатор", "connected":"Қосылған", "not_connected":"Қосылмаған", "connect":"Қосылу", "refresh":"Құрылғыларды жаңарту",
        "open_admin":"Маршрутизатор панелін ашу", "host":"Маршрутизатор мекенжайы", "username":"Логин", "password":"Әкімші құпиясөзі",
        "provider":"Провайдер", "brand":"Маршрутизатор өндірушісі", "save":"Параметрлерді сақтау", "no_devices":"Құрылғылар әлі жүктелмеді",
        "blocked":"Бұғатталған", "allow":"Бұғаттан шығару", "block":"Интернетті бұғаттау", "connected_devices":"Қосылған құрылғылар",
        "apply_schedule":"Кестені қолдану", "router_schedules":"Маршрутизатордағы кестелер", "child_device":"Баланың құрылғысы",
        "mark_child":"Балалар құрылғыларына қосу", "remove_child":"Балалар құрылғыларынан алып тастау", "no_schedules":"Кестелер табылмады",
        "schedule_note":"Кестені маршрутизатор панелінде жаса, содан кейін оны осы жерден таңда. Қолдау модельге байланысты.",
        "compatibility":"Үйлесімділік", "language":"Қолданба тілі", "status":"Күйі", "unknown":"Белгісіз",
        "local_network":"Жұмыс істеу үшін iPhone жергілікті желіге кіруге рұқсат сұрайды.", "only_keenetic":"Құрылғыларды автоматты басқару әзірге RCI қолдайтын Keenetic/Netcraze үшін қолжетімді.",
        "empty_blacklist":"Қара тізім бос", "save_success":"Параметрлер сақталды", "connect_success":"Маршрутизатор жауап берді", "need_mac":"Құрылғыда MAC мекенжайы жоқ — әрекет орындалмады.",
        "native_api":"API арқылы басқару", "web_only":"Тек веб-панель", "cancel":"Жабу", "router_page":"Маршрутизатор панелі",
        "profile":"Профиль", "provider_note":"Провайдер — профильді таңдауға арналған белгі. Нақты үйлесімділік маршрутизатор моделі мен микробағдарламасына байланысты.",
        "privacy":"Құпиясөз iOS кілттер қоймасында сақталады. Қолданба деректерді бөгде серверге жібермейді.", "unsupported":"Бұл модель үшін әзірге тек веб-панель қолжетімді.",
        "language_ru":"Русский", "language_kk":"Қазақша", "language_en":"English", "connecting":"Қосылым тексерілуде…"
    ]
    private static let en: [String: String] = [
        "dashboard":"Dashboard", "devices":"Devices", "blacklist":"Blacklist", "parental":"Parental control", "settings":"Settings",
        "router":"Router", "connected":"Connected", "not_connected":"Not connected", "connect":"Connect", "refresh":"Refresh devices",
        "open_admin":"Open router admin", "host":"Router address", "username":"Username", "password":"Admin password",
        "provider":"Internet provider", "brand":"Router manufacturer", "save":"Save settings", "no_devices":"No devices loaded yet",
        "blocked":"Blocked", "allow":"Unblock", "block":"Block internet", "connected_devices":"Connected devices",
        "apply_schedule":"Apply schedule", "router_schedules":"Router schedules", "child_device":"Child device",
        "mark_child":"Add to child devices", "remove_child":"Remove from child devices", "no_schedules":"No schedules found",
        "schedule_note":"Create a schedule in the router admin page, then select it here. Support depends on the model.",
        "compatibility":"Compatibility", "language":"App language", "status":"Status", "unknown":"Unknown",
        "local_network":"The app needs access to the iPhone's local network.", "only_keenetic":"Automatic device control currently works with Keenetic/Netcraze models that support RCI.",
        "empty_blacklist":"The blacklist is empty", "save_success":"Settings saved", "connect_success":"Router responded", "need_mac":"This device has no MAC address; action unavailable.",
        "native_api":"API control", "web_only":"Web admin only", "cancel":"Close", "router_page":"Router admin",
        "profile":"Profile", "provider_note":"The provider is a profile hint. Actual compatibility depends on the router model and firmware.",
        "privacy":"The password is stored in the iOS Keychain. The app does not send data to a third-party server.", "unsupported":"Only the router web admin page is available for this model.",
        "language_ru":"Русский", "language_kk":"Қазақша", "language_en":"English", "connecting":"Checking connection…"
    ]

    static func s(_ key: String) -> String {
        let table = language == "Қазақша" ? kk : (language == "English" ? en : ru)
        return table[key] ?? ru[key] ?? key
    }
}
