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
        for spec in ("%@", "%d"):
            assert key.count(spec) == v.count(spec), (key, v)

write("en", [], AUDIO_USAGE_EN)  # English = keys; the folder marks it as a supported language
for i, lang in enumerate(LANGS):
    write(lang, [(k, v[i]) for k, v in STRINGS.items()], AUDIO_USAGE[i])
print(f"{len(STRINGS)} strings x {len(LANGS)} languages")
