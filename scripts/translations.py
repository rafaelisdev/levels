"""Single source of the app's translations. English text is the key.

  python3 scripts/translations.py   ->  Resources/Localizations/<lang>.lproj/{Localizable,InfoPlist}.strings

To add a string: use English in the Swift code, add a row here, run the script.
Avoid "%" in plain strings (SwiftUI may treat it as a format); use %@ / %d only
where the code passes arguments.
"""
import os

LANGS = ["ru", "de", "fr", "es", "ja", "zh-Hans", "ko", "pt"]

# key: [ru, de, fr, es, ja, zh-Hans, ko, pt]
STRINGS = {
    "Volume for every app": ["Громкость каждого приложения", "Lautstärke für jede App", "Un volume pour chaque app", "Volumen para cada app", "アプリごとの音量", "每个应用的音量", "앱별 볼륨", "Volume para cada app"],
    "Device volume": ["Громкость устройства", "Gerätelautstärke", "Volume de l’appareil", "Volumen del dispositivo", "デバイスの音量", "设备音量", "기기 볼륨", "Volume do dispositivo"],
    "Unmute": ["Включить звук", "Ton einschalten", "Réactiver le son", "Activar sonido", "消音を解除", "取消静音", "음소거 해제", "Ativar som"],
    "Mute": ["Выключить звук", "Stummschalten", "Couper le son", "Silenciar", "消音", "静音", "음소거", "Silenciar"],
    "This device has no volume control": ["У этого устройства громкость не регулируется", "Dieses Gerät hat keine Lautstärkeregelung", "Cet appareil n’a pas de réglage du volume", "Este dispositivo no tiene control de volumen", "このデバイスは音量を調整できません", "此设备无法调节音量", "이 기기는 볼륨을 조절할 수 없습니다", "Este dispositivo não tem controle de volume"],
    "Apps": ["Приложения", "Apps", "Apps", "Apps", "アプリ", "应用", "앱", "Apps"],
    "Nothing is playing right now": ["Сейчас ничего не играет", "Gerade wird nichts abgespielt", "Rien n’est en lecture", "No se está reproduciendo nada", "現在再生中のものはありません", "当前没有播放内容", "지금 재생 중인 항목이 없습니다", "Nada está tocando agora"],
    "Other apps with sound": ["Другие приложения со звуком", "Weitere Apps mit Ton", "Autres apps avec du son", "Otras apps con sonido", "サウンドを使う他のアプリ", "其他有声音的应用", "소리가 있는 다른 앱", "Outros apps com som"],
    "Launch at login": ["Запуск при входе", "Autostart", "Ouvrir à la connexion", "Abrir al iniciar sesión", "ログイン時に起動", "登录时启动", "로그인 시 실행", "Abrir ao iniciar sessão"],
    "Reset": ["Сбросить", "Zurücksetzen", "Réinitialiser", "Restablecer", "リセット", "重置", "재설정", "Redefinir"],
    "Set every app back to full volume": ["Вернуть всем приложениям полную громкость", "Alle Apps auf volle Lautstärke zurücksetzen", "Remettre toutes les apps au volume maximal", "Devolver todas las apps al volumen máximo", "すべてのアプリを最大音量に戻す", "将所有应用恢复为最大音量", "모든 앱을 최대 볼륨으로 되돌리기", "Voltar todos os apps ao volume máximo"],
    "Quit": ["Выйти", "Beenden", "Quitter", "Salir", "終了", "退出", "종료", "Sair"],
    "Reset to full volume": ["Вернуть полную громкость", "Auf volle Lautstärke zurücksetzen", "Remettre au volume maximal", "Volver al volumen máximo", "最大音量に戻す", "恢复为最大音量", "최대 볼륨으로 되돌리기", "Voltar ao volume máximo"],
    "Playing now": ["Сейчас играет", "Wird abgespielt", "En lecture", "Reproduciendo", "再生中", "正在播放", "재생 중", "Tocando agora"],
    "No apps with sound": ["Нет приложений со звуком", "Keine Apps mit Ton", "Aucune app avec du son", "No hay apps con sonido", "サウンドを使っているアプリはありません", "没有发出声音的应用", "소리가 나는 앱이 없습니다", "Nenhum app com som"],
    "Play music or a video and the app will show up here": ["Включите музыку или видео — приложение появится здесь", "Spiel Musik oder ein Video ab – die App erscheint dann hier", "Lancez de la musique ou une vidéo : l’app apparaîtra ici", "Reproduce música o un vídeo y la app aparecerá aquí", "音楽やビデオを再生すると、ここにアプリが表示されます", "播放音乐或视频后，应用会显示在这里", "음악이나 동영상을 재생하면 여기에 앱이 표시됩니다", "Toque uma música ou um vídeo e o app aparece aqui"],
    "Per-app volume needs macOS 14.2": ["Громкость приложений — с macOS 14.2", "Lautstärke pro App erfordert macOS 14.2", "Le volume par app nécessite macOS 14.2", "El volumen por app requiere macOS 14.2", "アプリごとの音量にはmacOS 14.2以降が必要です", "按应用调节音量需要 macOS 14.2", "앱별 볼륨에는 macOS 14.2 이상이 필요합니다", "Volume por app requer macOS 14.2"],
    "On macOS %@, apps can’t control each other’s sound. Device volume still works.": ["В macOS %@ приложения не могут управлять звуком друг друга. Общая громкость работает.", "Unter macOS %@ können Apps den Ton anderer Apps nicht steuern. Die Gerätelautstärke funktioniert trotzdem.", "Sous macOS %@, une app ne peut pas régler le son des autres. Le volume de l’appareil fonctionne.", "En macOS %@, las apps no pueden controlar el sonido de otras. El volumen del dispositivo sigue funcionando.", "macOS %@では、アプリが他のアプリの音を制御できません。デバイスの音量は調整できます。", "在 macOS %@ 上，应用无法控制其他应用的声音。设备音量仍可调节。", "macOS %@에서는 앱이 다른 앱의 소리를 제어할 수 없습니다. 기기 볼륨은 계속 조절할 수 있습니다.", "No macOS %@, apps não podem controlar o som de outros apps. O volume do dispositivo continua funcionando."],
    "No access to app audio": ["Нет доступа к звуку приложений", "Kein Zugriff auf den App-Ton", "Pas d’accès au son des apps", "Sin acceso al sonido de las apps", "アプリのオーディオにアクセスできません", "无法访问应用音频", "앱 오디오에 접근할 수 없습니다", "Sem acesso ao áudio dos apps"],
    "Levels needs access to app audio": ["Levels нужен доступ к звуку приложений", "Levels braucht Zugriff auf den App-Ton", "Levels a besoin d’accéder au son des apps", "Levels necesita acceso al sonido de las apps", "Levelsにはアプリのオーディオへのアクセスが必要です", "Levels 需要访问应用音频", "Levels에 앱 오디오 접근 권한이 필요합니다", "O Levels precisa de acesso ao áudio dos apps"],
    "Turn on Levels in System Settings → Privacy & Security → Screen & System Audio Recording.": [
        "Включите Levels в Системных настройках → Конфиденциальность и безопасность → Запись экрана и системного аудио.",
        "Aktiviere Levels in Systemeinstellungen → Datenschutz & Sicherheit → Bildschirm- & Systemaudioaufnahme.",
        "Activez Levels dans Réglages Système → Confidentialité et sécurité → Enregistrement de l’écran et de l’audio système.",
        "Activa Levels en Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla y audio del sistema.",
        "システム設定 → プライバシーとセキュリティ → 画面収録とシステムオーディオ録音 で Levels をオンにしてください。",
        "请在“系统设置 → 隐私与安全性 → 录屏与系统录音”中开启 Levels。",
        "시스템 설정 → 개인정보 보호 및 보안 → 화면 및 시스템 오디오 녹음에서 Levels를 켜세요.",
        "Ative o Levels em Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema."],
    "macOS will ask for “System Audio Recording Only” access. Audio stays on your Mac and is never recorded.": [
        "macOS попросит доступ «Только системное аудио». Звук остаётся на вашем Mac и никуда не записывается.",
        "macOS fragt nach dem Zugriff „Nur Systemaudio“. Der Ton bleibt auf deinem Mac und wird nie aufgezeichnet.",
        "macOS va demander l’accès « Audio système uniquement ». Le son reste sur votre Mac et n’est jamais enregistré.",
        "macOS pedirá acceso a «Solo audio del sistema». El sonido se queda en tu Mac y nunca se graba.",
        "macOSが「システムオーディオ録音のみ」へのアクセスを求めます。音声はMac内で処理され、録音されることはありません。",
        "macOS 会请求“仅系统录音”权限。音频只在你的 Mac 上处理，绝不会被录制。",
        "macOS가 '시스템 오디오 녹음만' 접근 권한을 요청합니다. 오디오는 Mac에서만 처리되며 녹음되지 않습니다.",
        "O macOS vai pedir acesso a “Somente Áudio do Sistema”. O áudio fica no seu Mac e nunca é gravado."],
    "Open System Settings": ["Открыть Системные настройки", "Systemeinstellungen öffnen", "Ouvrir Réglages Système", "Abrir Ajustes del Sistema", "システム設定を開く", "打开系统设置", "시스템 설정 열기", "Abrir Ajustes do Sistema"],
    "Allow": ["Разрешить", "Erlauben", "Autoriser", "Permitir", "許可", "允许", "허용", "Permitir"],
    "No output device": ["Нет устройства вывода", "Kein Ausgabegerät", "Aucun appareil de sortie", "Sin dispositivo de salida", "出力デバイスがありません", "无输出设备", "출력 기기 없음", "Nenhum dispositivo de saída"],
    "Launch at login: %@": ["Запуск при входе: %@", "Beim Anmelden starten: %@", "Ouverture à la connexion : %@", "Abrir al iniciar sesión: %@", "ログイン時に起動: %@", "登录时启动：%@", "로그인 시 실행: %@", "Abrir ao iniciar sessão: %@"],
    "Output": ["Выход", "Ausgang", "Sortie", "Salida", "出力", "输出", "출력", "Saída"],
    "Couldn’t %@ (error %d)": ["Не удалось %@ (ошибка %d)", "%@ fehlgeschlagen (Fehler %d)", "Impossible de %@ (erreur %d)", "No se pudo %@ (error %d)", "%@できませんでした（エラー %d）", "无法%@（错误 %d）", "%@ 실패(오류 %d)", "Não foi possível %@ (erro %d)"],
    "Outputs": ["Выходы", "Ausgänge", "Sorties", "Salidas", "出力", "输出", "출력", "Saídas"],
    "Lining up…": ["Выравниваю…", "Wird abgeglichen…", "Alignement…", "Alineando…", "調整中…", "正在对齐…", "맞추는 중…", "Alinhando…"],
    "Play on several outputs at once. Levels lines them up so they sound together.": [
        "Играйте сразу на нескольких выходах. Levels выравнивает их, чтобы они звучали вместе.",
        "Spiele auf mehreren Ausgängen gleichzeitig. Levels gleicht sie ab, damit sie zusammen klingen.",
        "Lisez sur plusieurs sorties à la fois. Levels les aligne pour qu’elles sonnent ensemble.",
        "Reproduce en varias salidas a la vez. Levels las alinea para que suenen juntas.",
        "複数の出力で同時に再生します。Levelsがタイミングをそろえて、同時に鳴るようにします。",
        "同时在多个输出上播放。Levels 会对齐它们，让声音同步。",
        "여러 출력에서 동시에 재생합니다. Levels가 타이밍을 맞춰 함께 들리게 합니다.",
        "Toque em várias saídas ao mesmo tempo. O Levels as alinha para soarem juntas."],
    "Play on": ["Играть на", "Wiedergabe auf", "Lire sur", "Reproducir en", "再生先", "播放到", "재생 위치", "Tocar em"],
    "Sync": ["Синхронизация", "Abgleich", "Synchronisation", "Sincronización", "同期", "同步", "동기화", "Sincronia"],
    "Play something with a clear beat and move a device until the echo is gone.": [
        "Включите что-нибудь с чётким ритмом и двигайте устройство, пока эхо не пропадёт.",
        "Spiel etwas mit klarem Beat ab und verschiebe ein Gerät, bis das Echo weg ist.",
        "Lancez un morceau au rythme marqué et déplacez un appareil jusqu’à ce que l’écho disparaisse.",
        "Reproduce algo con un ritmo claro y mueve un dispositivo hasta que desaparezca el eco.",
        "リズムがはっきりした音を再生し、エコーが消えるまでデバイスを調整してください。",
        "播放节奏清晰的内容，调整设备直到回声消失。",
        "박자가 뚜렷한 소리를 재생하고 메아리가 사라질 때까지 기기를 조정하세요.",
        "Toque algo com batida marcada e ajuste um dispositivo até o eco sumir."],
    "Default": ["Основной", "Standard", "Par défaut", "Predeterminado", "デフォルト", "默认", "기본", "Padrão"],
    "The default output always plays": ["Основной выход играет всегда", "Der Standardausgang spielt immer", "La sortie par défaut joue toujours", "La salida predeterminada siempre suena", "デフォルトの出力は常に再生されます", "默认输出始终播放", "기본 출력은 항상 재생됩니다", "A saída padrão sempre toca"],
    "Delay": ["Задержка", "Verzögerung", "Délai", "Retardo", "遅延", "延迟", "지연", "Atraso"],
    "slowest": ["самый медленный", "am langsamsten", "le plus lent", "el más lento", "最も遅い", "最慢", "가장 느림", "o mais lento"],
    "waits %lld ms": ["ждёт %lld мс", "wartet %lld ms", "attend %lld ms", "espera %lld ms", "%lld ms待機", "等待 %lld 毫秒", "%lld ms 대기", "espera %lld ms"],
    "macOS hid the Levels icon": ["macOS спрятала значок Levels", "macOS hat das Levels-Symbol ausgeblendet", "macOS a masqué l’icône de Levels", "macOS ocultó el icono de Levels", "macOSがLevelsのアイコンを隠しました", "macOS 隐藏了 Levels 图标", "macOS가 Levels 아이콘을 숨겼습니다", "O macOS ocultou o ícone do Levels"],
    "The menu bar is full, so the icon sits behind the camera notch. Hold ⌘ and drag icons to make room, or open Levels again from Spotlight to bring up this panel.": [
        "Строка меню заполнена, поэтому значок оказался за вырезом камеры. Перетащите значки с зажатой ⌘, чтобы освободить место, или снова откройте Levels через Spotlight — появится эта панель.",
        "Die Menüleiste ist voll, deshalb liegt das Symbol hinter der Kamera-Aussparung. Halte ⌘ gedrückt und ziehe Symbole, um Platz zu schaffen, oder öffne Levels erneut über Spotlight, um dieses Menü zu zeigen.",
        "La barre des menus est pleine : l’icône se trouve derrière l’encoche de la caméra. Maintenez ⌘ et faites glisser des icônes pour faire de la place, ou rouvrez Levels depuis Spotlight pour afficher ce panneau.",
        "La barra de menús está llena, así que el icono quedó detrás de la muesca de la cámara. Mantén ⌘ y arrastra iconos para hacer sitio, o vuelve a abrir Levels desde Spotlight para mostrar este panel.",
        "メニューバーがいっぱいのため、アイコンがカメラのノッチの裏に隠れています。⌘キーを押しながらアイコンをドラッグして場所を空けるか、SpotlightからLevelsをもう一度開くとこのパネルが表示されます。",
        "菜单栏已满，图标被摄像头刘海挡住了。按住 ⌘ 拖动图标腾出空间，或从聚焦搜索再次打开 Levels 以显示此面板。",
        "메뉴 막대가 가득 차서 아이콘이 카메라 노치 뒤에 있습니다. ⌘ 키를 누른 채 아이콘을 드래그해 공간을 만들거나, Spotlight에서 Levels를 다시 열면 이 패널이 나타납니다.",
        "A barra de menus está cheia, então o ícone ficou atrás do entalhe da câmera. Segure ⌘ e arraste ícones para abrir espaço, ou abra o Levels de novo pelo Spotlight para mostrar este painel."],
    "Levels %@ is available": ["Доступна Levels %@", "Levels %@ ist verfügbar", "Levels %@ est disponible", "Levels %@ está disponible", "Levels %@ が利用可能です", "Levels %@ 已可用", "Levels %@ 버전을 사용할 수 있습니다", "Levels %@ está disponível"],
    "Update": ["Обновить", "Aktualisieren", "Mettre à jour", "Actualizar", "アップデート", "更新", "업데이트", "Atualizar"],
    "Updating…": ["Обновляется…", "Wird aktualisiert…", "Mise à jour…", "Actualizando…", "アップデート中…", "正在更新…", "업데이트 중…", "Atualizando…"],
    "Couldn’t install the update. Download it instead.": ["Не удалось установить обновление. Скачайте его вручную.", "Das Update ließ sich nicht installieren. Lade es stattdessen herunter.", "Impossible d’installer la mise à jour. Téléchargez-la plutôt.", "No se pudo instalar la actualización. Descárgala manualmente.", "アップデートをインストールできませんでした。手動でダウンロードしてください。", "无法安装更新，请手动下载。", "업데이트를 설치할 수 없습니다. 직접 다운로드하세요.", "Não foi possível instalar a atualização. Baixe-a manualmente."],
    "Download": ["Скачать", "Herunterladen", "Télécharger", "Descargar", "ダウンロード", "下载", "다운로드", "Baixar"],
    "Got it": ["Понятно", "Verstanden", "Compris", "Entendido", "OK", "知道了", "확인", "Entendi"],
    "capture the app’s audio": ["перехватить звук приложения", "Aufnahme des App-Tons", "capter le son de l’app", "capturar el audio de la app", "アプリのオーディオを取得", "捕获应用音频", "앱 오디오 캡처", "capturar o áudio do app"],
    "read the audio format": ["прочитать формат звука", "Lesen des Audioformats", "lire le format audio", "leer el formato de audio", "オーディオ形式を読み取り", "读取音频格式", "오디오 형식 읽기", "ler o formato de áudio"],
    "create the audio device": ["создать аудиоустройство", "Erstellen des Audiogeräts", "créer le périphérique audio", "crear el dispositivo de audio", "オーディオデバイスを作成", "创建音频设备", "오디오 기기 생성", "criar o dispositivo de áudio"],
    "start audio processing": ["запустить обработку звука", "Starten der Audioverarbeitung", "démarrer le traitement audio", "iniciar el procesamiento de audio", "オーディオ処理を開始", "启动音频处理", "오디오 처리 시작", "iniciar o processamento de áudio"],
    "start the output": ["запустить вывод", "Starten der Ausgabe", "démarrer la sortie", "iniciar la salida", "出力を開始", "启动输出", "출력 시작", "iniciar a saída"],
}

AUDIO_USAGE_EN = "Levels needs access to app audio to change each app’s volume. Audio is processed on your Mac and is never recorded or sent anywhere."
AUDIO_USAGE = [
    "Levels нужен доступ к звуку приложений, чтобы менять их громкость. Звук обрабатывается на вашем Mac и никуда не записывается и не отправляется.",
    "Levels braucht Zugriff auf den App-Ton, um die Lautstärke jeder App zu ändern. Der Ton wird auf deinem Mac verarbeitet und nie aufgezeichnet oder gesendet.",
    "Levels a besoin d’accéder au son des apps pour régler le volume de chacune. Le son est traité sur votre Mac et n’est jamais enregistré ni envoyé.",
    "Levels necesita acceso al sonido de las apps para cambiar el volumen de cada una. El sonido se procesa en tu Mac y nunca se graba ni se envía.",
    "Levelsはアプリごとの音量を変えるために、アプリのオーディオへのアクセスが必要です。音声はMac内で処理され、録音や送信は一切行いません。",
    "Levels 需要访问应用音频才能调节每个应用的音量。音频只在你的 Mac 上处理，绝不会被录制或发送。",
    "Levels가 앱별 볼륨을 바꾸려면 앱 오디오에 접근해야 합니다. 오디오는 Mac에서만 처리되며 녹음하거나 전송하지 않습니다.",
    "O Levels precisa de acesso ao áudio dos apps para mudar o volume de cada um. O áudio é processado no seu Mac e nunca é gravado nem enviado.",
]


def q(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def write(lang: str, pairs: list[tuple[str, str]], usage: str) -> None:
    d = os.path.join(os.path.dirname(__file__), "..", "Resources", "Localizations", f"{lang}.lproj")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "Localizable.strings"), "w", encoding="utf-8") as f:
        f.write("/* Generated by scripts/translations.py, do not edit by hand. */\n")
        for k, v in pairs:
            f.write(f"{q(k)} = {q(v)};\n")
    with open(os.path.join(d, "InfoPlist.strings"), "w", encoding="utf-8") as f:
        f.write(f'"NSAudioCaptureUsageDescription" = {q(usage)};\n')


for key, values in STRINGS.items():
    assert len(values) == len(LANGS), key
    for v in values:  # every format specifier in the key must survive translation
        for spec in ("%@", "%d", "%lld"):
            assert key.count(spec) == v.count(spec), (key, v)

write("en", [], AUDIO_USAGE_EN)  # English = keys; the folder marks it as a supported language
for i, lang in enumerate(LANGS):
    write(lang, [(k, v[i]) for k, v in STRINGS.items()], AUDIO_USAGE[i])
print(f"{len(STRINGS)} strings x {len(LANGS)} languages")
