// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DisplayConfigurationText: Int, CaseIterable {
    case title, caption, resolution, rate, main, makeMain, profile, factory, apply
    case keep, revert, confirmation, saved, name, save, restore, delete, noModes
    case lowerRate, failed, rollbackFailed, mirrored, rendered, noDisplays
}

enum DisplayConfigurationStrings {
    static func text(_ key: DisplayConfigurationText, _ language: AppLanguage) -> String {
        values(language)[key.rawValue]
    }

    /// Exhaustive locale coverage, in the same order as DisplayConfigurationText.
    static func values(_ language: AppLanguage) -> [String] {
        switch language {
        case .enUS: return [
            "Display configuration", "Choose an available HiDPI mode, refresh rate, main display and RGB color profile. Changes revert after 15 seconds unless kept.",
            "Resolution", "Refresh rate", "Main display", "Make main", "Color profile", "Display default", "Apply",
            "Keep changes", "Revert", "Keep these display settings? Reverting in %d seconds.", "Saved configurations", "Configuration name", "Save current", "Restore", "Delete", "No available mode for this HiDPI choice.",
            "This selection lowers the refresh rate.", "Could not apply the configuration. Check connected displays, available modes and color profile files.", "Automatic restore failed. Restore the display in macOS System Settings, or try Revert again.", "Turn off mirroring before changing this display configuration.", "Rendered pixels", "No active displays."]
        case .zhHans: return [
            "显示器配置", "选择可用的 HiDPI 模式、刷新率、主屏和 RGB 颜色配置文件。更改后须在 15 秒内确认保留，否则自动恢复。",
            "分辨率", "刷新率", "主显示器", "设为主屏", "颜色配置文件", "显示器默认", "应用",
            "保留更改", "恢复原设置", "%d 秒后自动恢复，是否保留显示设置？", "已保存的配置", "配置名称", "保存当前配置", "恢复", "删除", "此 HiDPI 选项没有可用模式。",
            "所选模式会降低刷新率。", "无法应用配置。请检查显示器连接、可用模式及颜色配置文件。", "自动恢复失败。请在 macOS 系统设置中恢复显示设置，或再次点击恢复。", "请先关闭镜像，再更改显示器配置。", "渲染像素", "没有活动显示器。"]
        case .zhTW, .zhHK: return [
            "顯示器設定", "選擇可用的 HiDPI 模式、更新率、主顯示器和 RGB 色彩描述檔。變更後須在 15 秒內確認保留，否則自動還原。",
            "解析度", "更新率", "主顯示器", "設為主顯示器", "色彩描述檔", "顯示器預設", "套用",
            "保留變更", "還原", "%d 秒後自動還原，是否保留顯示設定？", "已儲存的設定", "設定名稱", "儲存目前設定", "還原", "刪除", "此 HiDPI 選項沒有可用模式。",
            "所選模式會降低更新率。", "無法套用設定。請檢查顯示器連線、可用模式和色彩描述檔。", "自動還原失敗。請在 macOS 系統設定中還原，或再次按下還原。", "請先關閉鏡像輸出，再變更顯示設定。", "算繪像素", "沒有作用中的顯示器。"]
        case .ptBR: return [
            "Configuração de telas", "Escolha um modo HiDPI disponível, taxa, tela principal e perfil RGB. Confirme em 15 segundos para manter as alterações.",
            "Resolução", "Taxa de atualização", "Tela principal", "Tornar principal", "Perfil de cor", "Padrão da tela", "Aplicar",
            "Manter alterações", "Reverter", "Manter esta configuração? Revertendo em %d segundos.", "Configurações salvas", "Nome da configuração", "Salvar atual", "Restaurar", "Excluir", "Nenhum modo disponível para esta opção HiDPI.",
            "Esta seleção reduz a taxa de atualização.", "Não foi possível aplicar. Verifique as telas conectadas, os modos e os arquivos de perfil de cor.", "A restauração automática falhou. Use os Ajustes do Sistema do macOS ou tente Reverter novamente.", "Desative o espelhamento antes de alterar a configuração.", "Pixels renderizados", "Nenhuma tela ativa."]
        case .tr: return [
            "Ekran yapılandırması", "HiDPI modu, yenileme hızı, ana ekran ve RGB renk profili seçin. Değişiklikler 15 saniye içinde onaylanmazsa geri alınır.",
            "Çözünürlük", "Yenileme hızı", "Ana ekran", "Ana ekran yap", "Renk profili", "Ekran varsayılanı", "Uygula",
            "Değişiklikleri koru", "Geri al", "Bu ayarlar korunsun mu? %d saniye içinde geri alınacak.", "Kayıtlı yapılandırmalar", "Yapılandırma adı", "Geçerli ayarları kaydet", "Geri yükle", "Sil", "Bu HiDPI seçeneği için kullanılabilir mod yok.",
            "Bu seçim yenileme hızını düşürür.", "Uygulanamadı. Bağlı ekranları, modları ve renk profili dosyalarını kontrol edin.", "Otomatik geri yükleme başarısız. macOS Sistem Ayarları'nı kullanın veya yeniden Geri al'ı deneyin.", "Ekran yapılandırmasını değiştirmeden önce yansıtmayı kapatın.", "İşlenen pikseller", "Etkin ekran yok."]
        case .ru: return [
            "Настройка дисплеев", "Выберите режим HiDPI, частоту, основной дисплей и цветовой профиль RGB. Подтвердите изменения в течение 15 секунд.",
            "Разрешение", "Частота обновления", "Основной дисплей", "Сделать основным", "Цветовой профиль", "По умолчанию", "Применить",
            "Сохранить изменения", "Отменить", "Сохранить настройки? Возврат через %d с.", "Сохранённые настройки", "Название", "Сохранить текущие", "Восстановить", "Удалить", "Для этого варианта HiDPI нет доступного режима.",
            "Этот режим снижает частоту обновления.", "Не удалось применить настройки. Проверьте дисплеи, доступные режимы и файлы цветовых профилей.", "Автовосстановление не удалось. Используйте Системные настройки macOS или повторите отмену.", "Перед изменением настроек отключите видеоповтор.", "Пиксели рендеринга", "Нет активных дисплеев."]
        case .uk: return [
            "Налаштування дисплеїв", "Виберіть режим HiDPI, частоту, головний дисплей і колірний профіль RGB. Підтвердьте зміни протягом 15 секунд.",
            "Роздільність", "Частота оновлення", "Головний дисплей", "Зробити головним", "Колірний профіль", "Типовий профіль", "Застосувати",
            "Зберегти зміни", "Скасувати", "Зберегти налаштування? Відновлення через %d с.", "Збережені налаштування", "Назва", "Зберегти поточні", "Відновити", "Видалити", "Для цього варіанта HiDPI немає доступного режиму.",
            "Цей режим зменшує частоту оновлення.", "Не вдалося застосувати. Перевірте дисплеї, доступні режими й файли колірних профілів.", "Автовідновлення не вдалося. Скористайтеся Системними параметрами macOS або повторіть скасування.", "Перед зміною налаштувань вимкніть дублювання екранів.", "Пікселі рендерингу", "Немає активних дисплеїв."]
        case .es: return [
            "Configuración de pantallas", "Elige un modo HiDPI, frecuencia, pantalla principal y perfil RGB. Los cambios se revierten tras 15 segundos sin confirmar.",
            "Resolución", "Frecuencia", "Pantalla principal", "Hacer principal", "Perfil de color", "Predeterminado", "Aplicar",
            "Conservar cambios", "Revertir", "¿Conservar estos ajustes? Se revertirán en %d segundos.", "Configuraciones guardadas", "Nombre", "Guardar actual", "Restaurar", "Eliminar", "No hay un modo disponible para esta opción HiDPI.",
            "Esta selección reduce la frecuencia.", "No se pudo aplicar. Comprueba las pantallas, los modos y los archivos de perfiles de color.", "Falló la restauración automática. Usa Ajustes del Sistema de macOS o vuelve a pulsar Revertir.", "Desactiva la duplicación antes de cambiar esta configuración.", "Píxeles renderizados", "No hay pantallas activas."]
        case .sk: return [
            "Nastavenie displejov", "Vyberte režim HiDPI, frekvenciu, hlavný displej a profil RGB. Zmeny sa bez potvrdenia vrátia po 15 sekundách.",
            "Rozlíšenie", "Obnovovacia frekvencia", "Hlavný displej", "Nastaviť ako hlavný", "Farebný profil", "Predvolené", "Použiť",
            "Ponechať zmeny", "Vrátiť", "Ponechať nastavenia? Vrátenie o %d s.", "Uložené nastavenia", "Názov", "Uložiť aktuálne", "Obnoviť", "Odstrániť", "Pre túto voľbu HiDPI nie je dostupný režim.",
            "Táto voľba zníži obnovovaciu frekvenciu.", "Nastavenie sa nepodarilo použiť. Skontrolujte displeje, režimy a súbory farebných profilov.", "Automatická obnova zlyhala. Použite Systémové nastavenia macOS alebo skúste vrátenie znova.", "Pred zmenou nastavenia vypnite zrkadlenie.", "Vykreslené pixely", "Žiadne aktívne displeje."]
        case .de: return [
            "Displaykonfiguration", "HiDPI-Modus, Bildrate, Hauptdisplay und RGB-Farbprofil wählen. Änderungen werden nach 15 Sekunden ohne Bestätigung zurückgesetzt.",
            "Auflösung", "Bildwiederholrate", "Hauptdisplay", "Als Hauptdisplay", "Farbprofil", "Displaystandard", "Anwenden",
            "Änderungen behalten", "Zurücksetzen", "Einstellungen behalten? Zurücksetzen in %d Sekunden.", "Gespeicherte Konfigurationen", "Name", "Aktuelle speichern", "Wiederherstellen", "Löschen", "Kein Modus für diese HiDPI-Auswahl verfügbar.",
            "Diese Auswahl senkt die Bildwiederholrate.", "Anwendung fehlgeschlagen. Displays, verfügbare Modi und Farbprofildateien prüfen.", "Automatische Wiederherstellung fehlgeschlagen. macOS-Systemeinstellungen verwenden oder erneut zurücksetzen.", "Vor Änderungen die Bildschirmsynchronisierung deaktivieren.", "Gerenderte Pixel", "Keine aktiven Displays."]
        case .fr: return [
            "Configuration des écrans", "Choisissez un mode HiDPI, une fréquence, l’écran principal et un profil RVB. Confirmez sous 15 secondes pour garder les changements.",
            "Résolution", "Fréquence", "Écran principal", "Définir comme principal", "Profil de couleur", "Profil par défaut", "Appliquer",
            "Conserver", "Rétablir", "Conserver ces réglages ? Rétablissement dans %d secondes.", "Configurations enregistrées", "Nom", "Enregistrer l’actuelle", "Restaurer", "Supprimer", "Aucun mode disponible pour ce choix HiDPI.",
            "Ce choix réduit la fréquence.", "Application impossible. Vérifiez les écrans, les modes et les fichiers de profils de couleur.", "Échec du rétablissement automatique. Utilisez les Réglages Système de macOS ou réessayez.", "Désactivez la recopie vidéo avant de modifier la configuration.", "Pixels calculés", "Aucun écran actif."]
        case .it: return [
            "Configurazione schermi", "Scegli modalità HiDPI, frequenza, schermo principale e profilo RGB. Conferma entro 15 secondi per mantenere le modifiche.",
            "Risoluzione", "Frequenza", "Schermo principale", "Rendi principale", "Profilo colore", "Predefinito", "Applica",
            "Mantieni modifiche", "Ripristina", "Mantenere le impostazioni? Ripristino tra %d secondi.", "Configurazioni salvate", "Nome", "Salva attuale", "Ripristina", "Elimina", "Nessuna modalità disponibile per questa scelta HiDPI.",
            "Questa scelta riduce la frequenza.", "Impossibile applicare. Controlla schermi, modalità e file dei profili colore.", "Ripristino automatico non riuscito. Usa Impostazioni di Sistema di macOS o riprova.", "Disattiva la duplicazione prima di modificare la configurazione.", "Pixel renderizzati", "Nessuno schermo attivo."]
        case .ja: return [
            "ディスプレイ構成", "HiDPI、リフレッシュレート、メイン画面、RGBカラープロファイルを選択します。15秒以内に確定しない変更は元に戻ります。",
            "解像度", "リフレッシュレート", "メイン画面", "メインにする", "カラープロファイル", "ディスプレイの既定", "適用",
            "変更を保持", "元に戻す", "この設定を保持しますか？%d秒後に元に戻ります。", "保存済みの構成", "構成名", "現在の構成を保存", "復元", "削除", "このHiDPI設定に対応するモードがありません。",
            "この選択ではリフレッシュレートが下がります。", "適用できません。接続中の画面、対応モード、カラープロファイルを確認してください。", "自動復元に失敗しました。macOSのシステム設定で復元するか、もう一度元に戻してください。", "構成を変更する前にミラーリングを解除してください。", "描画ピクセル", "有効なディスプレイがありません。"]
        case .ko: return [
            "디스플레이 구성", "HiDPI 모드, 재생률, 주 디스플레이, RGB 색상 프로파일을 선택합니다. 15초 안에 확인하지 않으면 변경이 취소됩니다.",
            "해상도", "재생률", "주 디스플레이", "주 디스플레이로 설정", "색상 프로파일", "디스플레이 기본값", "적용",
            "변경 유지", "되돌리기", "설정을 유지할까요? %d초 후 되돌립니다.", "저장된 구성", "구성 이름", "현재 구성 저장", "복원", "삭제", "이 HiDPI 설정에 사용할 수 있는 모드가 없습니다.",
            "이 선택은 재생률을 낮춥니다.", "적용할 수 없습니다. 연결된 화면, 모드, 색상 프로파일 파일을 확인하세요.", "자동 복원에 실패했습니다. macOS 시스템 설정에서 복원하거나 다시 되돌려 보세요.", "구성을 변경하기 전에 미러링을 끄세요.", "렌더링 픽셀", "활성 디스플레이가 없습니다."]
        }
    }
}
