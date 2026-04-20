import Foundation

enum AppError: LocalizedError {
    case databaseSetup(underlying: Error)
    case migrationFailed(underlying: Error)
    case fileAccessDenied(path: String)
    case bookmarkResolutionFailed
    case bookmarkStale
    case bridgeTimeout
    case bookNotFound(id: String)
    case invalidEPUB(reason: String)

    var errorDescription: String? {
        switch self {
        case .databaseSetup(let e):
            return "Не удалось открыть базу данных: \(e.localizedDescription)"
        case .migrationFailed(let e):
            return "Ошибка миграции БД: \(e.localizedDescription)"
        case .fileAccessDenied(let path):
            return "Нет доступа к файлу: \(path)"
        case .bookmarkResolutionFailed:
            return "Не удалось восстановить доступ к файлу. Откройте книгу заново."
        case .bookmarkStale:
            return "Путь к файлу устарел. Откройте книгу заново."
        case .bridgeTimeout:
            return "EPUB движок не ответил. Попробуйте перезагрузить книгу."
        case .bookNotFound(let id):
            return "Книга не найдена: \(id)"
        case .invalidEPUB(let reason):
            return "Файл повреждён: \(reason)"
        }
    }
}
