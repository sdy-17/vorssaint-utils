// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct TodoStrings {
    let title, caption, open, newItem, add, filter, all, pending, completed: String
    let edit, save, cancel, delete, markPending, markCompleted, empty: String
    let loadFailed, saveFailed, retry: String
    let archive, archived, restore, archiveAfterDays, archiveNever, days: String

    static var current: TodoStrings { FeatureStrings.todo(L10n.shared.language) }

    static let enUS = TodoStrings(
        title: "To-do", caption: "Simple private tasks, saved on this Mac", open: "Open to-do",
        newItem: "New task", add: "Add", filter: "Show tasks", all: "All", pending: "Pending", completed: "Completed",
        edit: "Edit", save: "Save", cancel: "Cancel", delete: "Delete task",
        markPending: "Mark as pending", markCompleted: "Mark as completed", empty: "No tasks here",
        loadFailed: "Tasks could not be opened. The saved file was left unchanged.",
        saveFailed: "Changes could not be saved. Your previous tasks are unchanged. Please try again.", retry: "Retry",
        archive: "Archive", archived: "Archived", restore: "Restore", archiveAfterDays: "Auto-archive completed tasks after", archiveNever: "0 = Never automatically archive", days: "days")
    static let zhHans = TodoStrings(
        title: "待办", caption: "轻量私密待办，仅保存在这台 Mac 上", open: "打开待办",
        newItem: "新增待办事项", add: "新增", filter: "筛选待办", all: "全部", pending: "未完成", completed: "已完成",
        edit: "编辑", save: "保存", cancel: "取消", delete: "删除待办",
        markPending: "标为未完成", markCompleted: "标为已完成", empty: "暂无待办事项",
        loadFailed: "无法读取待办，已保留原有文件。",
        saveFailed: "无法保存更改，原有待办未改变，请重试。", retry: "重试",
        archive: "归档", archived: "已归档", restore: "恢复", archiveAfterDays: "完成后自动归档", archiveNever: "0 表示不自动归档", days: "天")
    static let zhTW = TodoStrings(
        title: "待辦", caption: "輕量私密待辦，僅儲存在這部 Mac 上", open: "開啟待辦",
        newItem: "新增待辦事項", add: "新增", filter: "篩選待辦", all: "全部", pending: "未完成", completed: "已完成",
        edit: "編輯", save: "儲存", cancel: "取消", delete: "刪除待辦",
        markPending: "標為未完成", markCompleted: "標為已完成", empty: "暫無待辦事項",
        loadFailed: "無法讀取待辦，已保留原有檔案。",
        saveFailed: "無法儲存變更，原有待辦未改變，請重試。", retry: "重試",
        archive: "封存", archived: "已封存", restore: "還原", archiveAfterDays: "完成後自動封存", archiveNever: "0 表示不自動封存", days: "天")
    static let ptBR = TodoStrings(
        title: "Tarefas",
        caption: "Tarefas simples e privadas, salvas neste Mac",
        open: "Abrir tarefas",
        newItem: "Nova tarefa",
        add: "Adicionar",
        filter: "Mostrar tarefas",
        all: "Todas",
        pending: "Pendentes",
        completed: "Concluídas",
        edit: "Editar",
        save: "Salvar",
        cancel: "Cancelar",
        delete: "Excluir tarefa",
        markPending: "Marcar como pendente",
        markCompleted: "Marcar como concluída",
        empty: "Nenhuma tarefa aqui",
        loadFailed: "Não foi possível abrir as tarefas. O arquivo salvo não foi alterado.",
        saveFailed: "Não foi possível salvar. Suas tarefas anteriores não foram alteradas. Tente novamente.",
        retry: "Tentar novamente",
        archive: "Arquivar", archived: "Arquivadas", restore: "Restaurar", archiveAfterDays: "Arquivar tarefas concluídas após", archiveNever: "0 = Nunca arquivar automaticamente", days: "dias")
    static let tr = TodoStrings(
        title: "Yapılacaklar",
        caption: "Bu Mac’te saklanan basit, özel görevler",
        open: "Yapılacakları aç",
        newItem: "Yeni görev",
        add: "Ekle",
        filter: "Görevleri göster",
        all: "Tümü",
        pending: "Bekleyen",
        completed: "Tamamlanan",
        edit: "Düzenle",
        save: "Kaydet",
        cancel: "İptal",
        delete: "Görevi sil",
        markPending: "Bekliyor olarak işaretle",
        markCompleted: "Tamamlandı olarak işaretle",
        empty: "Burada görev yok",
        loadFailed: "Görevler açılamadı. Kayıtlı dosya değiştirilmedi.",
        saveFailed: "Değişiklikler kaydedilemedi. Önceki görevleriniz değişmedi. Yeniden deneyin.",
        retry: "Yeniden dene",
        archive: "Arşivle", archived: "Arşivlenenler", restore: "Geri yükle", archiveAfterDays: "Tamamlananları otomatik arşivle", archiveNever: "0 = Otomatik arşivleme yok", days: "gün")
    static let ru = TodoStrings(
        title: "Задачи",
        caption: "Простые личные задачи, сохранённые на этом Mac",
        open: "Открыть задачи",
        newItem: "Новая задача",
        add: "Добавить",
        filter: "Показать задачи",
        all: "Все",
        pending: "Не завершены",
        completed: "Завершены",
        edit: "Изменить",
        save: "Сохранить",
        cancel: "Отмена",
        delete: "Удалить задачу",
        markPending: "Отметить незавершённой",
        markCompleted: "Отметить завершённой",
        empty: "Задач пока нет",
        loadFailed: "Не удалось открыть задачи. Сохранённый файл не изменён.",
        saveFailed: "Не удалось сохранить изменения. Прежние задачи не изменены. Повторите попытку.",
        retry: "Повторить",
        archive: "Архивировать", archived: "В архиве", restore: "Восстановить", archiveAfterDays: "Архивировать завершённые через", archiveNever: "0 = Не архивировать автоматически", days: "дн.")
    static let es = TodoStrings(
        title: "Tareas",
        caption: "Tareas sencillas y privadas, guardadas en este Mac",
        open: "Abrir tareas",
        newItem: "Nueva tarea",
        add: "Añadir",
        filter: "Mostrar tareas",
        all: "Todas",
        pending: "Pendientes",
        completed: "Completadas",
        edit: "Editar",
        save: "Guardar",
        cancel: "Cancelar",
        delete: "Eliminar tarea",
        markPending: "Marcar como pendiente",
        markCompleted: "Marcar como completada",
        empty: "No hay tareas aquí",
        loadFailed: "No se pudieron abrir las tareas. El archivo guardado no se ha modificado.",
        saveFailed: "No se pudieron guardar los cambios. Tus tareas anteriores no han cambiado. Inténtalo de nuevo.",
        retry: "Reintentar",
        archive: "Archivar", archived: "Archivadas", restore: "Restaurar", archiveAfterDays: "Archivar tareas completadas después de", archiveNever: "0 = Nunca archivar automáticamente", days: "días")
    static let sk = TodoStrings(
        title: "Úlohy",
        caption: "Jednoduché súkromné úlohy uložené na tomto Macu",
        open: "Otvoriť úlohy",
        newItem: "Nová úloha",
        add: "Pridať",
        filter: "Zobraziť úlohy",
        all: "Všetky",
        pending: "Nedokončené",
        completed: "Dokončené",
        edit: "Upraviť",
        save: "Uložiť",
        cancel: "Zrušiť",
        delete: "Vymazať úlohu",
        markPending: "Označiť ako nedokončenú",
        markCompleted: "Označiť ako dokončenú",
        empty: "Žiadne úlohy",
        loadFailed: "Úlohy sa nepodarilo otvoriť. Uložený súbor zostal nezmenený.",
        saveFailed: "Zmeny sa nepodarilo uložiť. Predchádzajúce úlohy zostali nezmenené. Skúste to znova.",
        retry: "Skúsiť znova",
        archive: "Archivovať", archived: "Archivované", restore: "Obnoviť", archiveAfterDays: "Automaticky archivovať dokončené po", archiveNever: "0 = Nikdy automaticky nearchivovať", days: "dní")
    static let de = TodoStrings(
        title: "Aufgaben",
        caption: "Einfache private Aufgaben, auf diesem Mac gespeichert",
        open: "Aufgaben öffnen",
        newItem: "Neue Aufgabe",
        add: "Hinzufügen",
        filter: "Aufgaben anzeigen",
        all: "Alle",
        pending: "Offen",
        completed: "Erledigt",
        edit: "Bearbeiten",
        save: "Sichern",
        cancel: "Abbrechen",
        delete: "Aufgabe löschen",
        markPending: "Als offen markieren",
        markCompleted: "Als erledigt markieren",
        empty: "Keine Aufgaben vorhanden",
        loadFailed: "Aufgaben konnten nicht geöffnet werden. Die gespeicherte Datei bleibt unverändert.",
        saveFailed: "Änderungen konnten nicht gesichert werden. Deine bisherigen Aufgaben bleiben unverändert. Versuche es erneut.",
        retry: "Erneut versuchen",
        archive: "Archivieren", archived: "Archiviert", restore: "Wiederherstellen", archiveAfterDays: "Erledigte Aufgaben automatisch archivieren nach", archiveNever: "0 = Nie automatisch archivieren", days: "Tagen")
    static let fr = TodoStrings(
        title: "Tâches",
        caption: "Des tâches simples et privées, enregistrées sur ce Mac",
        open: "Ouvrir les tâches",
        newItem: "Nouvelle tâche",
        add: "Ajouter",
        filter: "Afficher les tâches",
        all: "Toutes",
        pending: "À faire",
        completed: "Terminées",
        edit: "Modifier",
        save: "Enregistrer",
        cancel: "Annuler",
        delete: "Supprimer la tâche",
        markPending: "Marquer comme à faire",
        markCompleted: "Marquer comme terminée",
        empty: "Aucune tâche ici",
        loadFailed: "Impossible d’ouvrir les tâches. Le fichier enregistré est inchangé.",
        saveFailed: "Impossible d’enregistrer les modifications. Vos tâches précédentes sont inchangées. Réessayez.",
        retry: "Réessayer",
        archive: "Archiver", archived: "Archivées", restore: "Restaurer", archiveAfterDays: "Archiver les tâches terminées après", archiveNever: "0 = Ne jamais archiver automatiquement", days: "jours")
    static let it = TodoStrings(
        title: "Attività",
        caption: "Attività semplici e private, salvate su questo Mac",
        open: "Apri attività",
        newItem: "Nuova attività",
        add: "Aggiungi",
        filter: "Mostra attività",
        all: "Tutte",
        pending: "Da completare",
        completed: "Completate",
        edit: "Modifica",
        save: "Salva",
        cancel: "Annulla",
        delete: "Elimina attività",
        markPending: "Segna da completare",
        markCompleted: "Segna come completata",
        empty: "Nessuna attività",
        loadFailed: "Impossibile aprire le attività. Il file salvato non è stato modificato.",
        saveFailed: "Impossibile salvare le modifiche. Le attività precedenti non sono cambiate. Riprova.",
        retry: "Riprova",
        archive: "Archivia", archived: "Archiviate", restore: "Ripristina", archiveAfterDays: "Archivia automaticamente le attività completate dopo", archiveNever: "0 = Non archiviare automaticamente", days: "giorni")
    static let ja = TodoStrings(
        title: "タスク",
        caption: "このMacだけに保存するシンプルな非公開タスク",
        open: "タスクを開く",
        newItem: "新しいタスク",
        add: "追加",
        filter: "タスクを表示",
        all: "すべて",
        pending: "未完了",
        completed: "完了",
        edit: "編集",
        save: "保存",
        cancel: "キャンセル",
        delete: "タスクを削除",
        markPending: "未完了にする",
        markCompleted: "完了にする",
        empty: "タスクはありません",
        loadFailed: "タスクを開けませんでした。保存済みのファイルは変更していません。",
        saveFailed: "変更を保存できませんでした。元のタスクは変更していません。もう一度お試しください。",
        retry: "再試行",
        archive: "アーカイブ", archived: "アーカイブ済み", restore: "復元", archiveAfterDays: "完了後に自動アーカイブ", archiveNever: "0 = 自動アーカイブしない", days: "日")
    static let ko = TodoStrings(
        title: "할 일",
        caption: "이 Mac에만 저장되는 간단한 개인 할 일",
        open: "할 일 열기",
        newItem: "새 할 일",
        add: "추가",
        filter: "할 일 표시",
        all: "전체",
        pending: "미완료",
        completed: "완료",
        edit: "편집",
        save: "저장",
        cancel: "취소",
        delete: "할 일 삭제",
        markPending: "미완료로 표시",
        markCompleted: "완료로 표시",
        empty: "할 일이 없습니다",
        loadFailed: "할 일을 열 수 없습니다. 저장된 파일은 변경되지 않았습니다.",
        saveFailed: "변경 사항을 저장할 수 없습니다. 이전 할 일은 그대로입니다. 다시 시도하세요.",
        retry: "다시 시도",
        archive: "보관", archived: "보관됨", restore: "복원", archiveAfterDays: "완료 후 자동 보관", archiveNever: "0 = 자동 보관 안 함", days: "일")
    static let uk = TodoStrings(
        title: "Завдання",
        caption: "Прості приватні завдання, збережені на цьому Mac",
        open: "Відкрити завдання",
        newItem: "Нове завдання",
        add: "Додати",
        filter: "Показати завдання",
        all: "Усі",
        pending: "Незавершені",
        completed: "Завершені",
        edit: "Змінити",
        save: "Зберегти",
        cancel: "Скасувати",
        delete: "Видалити завдання",
        markPending: "Позначити незавершеним",
        markCompleted: "Позначити завершеним",
        empty: "Завдань немає",
        loadFailed: "Не вдалося відкрити завдання. Збережений файл не змінено.",
        saveFailed: "Не вдалося зберегти зміни. Попередні завдання не змінено. Спробуйте ще раз.",
        retry: "Повторити",
        archive: "Архівувати", archived: "В архіві", restore: "Відновити", archiveAfterDays: "Автоматично архівувати завершені через", archiveNever: "0 = Не архівувати автоматично", days: "дн.")
    static let zhHK = zhTW
}

extension FeatureStrings {
    static func todo(_ language: AppLanguage) -> TodoStrings {
        switch language {
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .uk: return .uk
        }
    }
}
