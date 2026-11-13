# Микшер (VolumeMixer)

Маленькое приложение для строки меню macOS: громкость каждого приложения отдельно,
плюс общая громкость устройства вывода.

- Запускается на macOS 11 Big Sur и новее, на Apple Silicon и Intel (universal).
- Громкость отдельных приложений работает с macOS 14.2: только там Apple дала
  Core Audio process taps. На более старых системах остаётся общая громкость, а
  панель объясняет почему. Драйверы и расширения не ставятся.
- Клик по иконке приложения выключает его звук, правый клик даёт «Сбросить до 100%».
- Громкость запоминается по приложению.
- Пока приложение не трогали, Микшер его не перехватывает. После первого движения
  ползунка перехват остаётся и на 100%, пока приложение не закроют. Иначе на границе
  99% ↔ 100% звук прыгал при переключении между прямым выводом и перехватом.

## Сборка

```bash
./build.sh            # build/VolumeMixer.app
./build.sh install    # плюс копирует в /Applications и запускает
./build.sh release    # плюс build/VolumeMixer-<версия>.zip и его sha256 для brew
```

Иконка рисуется кодом: `swift scripts/make_icon.swift Resources/AppIcon.icns`.

## Установка через brew

Homebrew ставит такие приложения как cask. Есть два пути.

### 1. Свой tap и скрипт установки (без нотаризации)

Установка для пользователей, любой из двух команд:

```bash
brew install rafaelisdev/tap/volumemixer
```

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelisdev/volumemixer/main/install.sh | bash
```

Как это устроено:

- код лежит в `rafaelisdev/volumemixer`, архив `VolumeMixer.zip` прикреплён к
  GitHub Release `vX.Y`;
- cask лежит в отдельном репозитории `rafaelisdev/homebrew-tap`, файл
  `Casks/volumemixer.rb`, собранный из шаблона
  [packaging/volumemixer.rb](packaging/volumemixer.rb);
- новая версия: поднять `CFBundleShortVersionString` в `Resources/Info.plist`,
  закоммитить и запустить `scripts/publish.sh`. Он соберёт архив, создаст релиз и
  обновит cask.

Приложение не нотаризовано Apple. macOS проверяет только файлы с флагом карантина:
его ставят браузеры и brew cask, а `curl` не ставит. Поэтому cask снимает флаг
после установки (`postflight`), а `install.sh` скачивает через `curl`. Разрешение
«Только системное аудио» macOS всё равно спросит, это отдельный механизм.

### 2. Официальный каталог Homebrew (`brew install --cask volumemixer` без tap)

Нужно:

- Apple Developer Program ($99 в год), сертификат **Developer ID Application**;
- подпись и нотаризация:
  ```bash
  SIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" ./build.sh release
  xcrun notarytool submit build/VolumeMixer-1.1.zip --keychain-profile notary --wait
  xcrun stapler staple build/VolumeMixer.app   # и заново упаковать zip
  ```
- нормальный bundle id вместо `local.volumemixer`, например `com.OWNER.volumemixer`;
- известность проекта: Homebrew не принимает совсем новые репозитории без звёзд
  и пользователей.

С сентября 2026 Homebrew убирает из официального каталога неподписанные и
ненотаризованные приложения, поэтому без подписи остаётся только свой tap.

Бонус от подписи Developer ID: разрешение «Только системное аудио» перестаёт
слетать после обновлений.

## Отладка

```bash
open /Applications/VolumeMixer.app --stdout /tmp/vm.log --args --debug
```

- `--debug`: раз в секунду пишет уровни звука по каждому перехвату (вход и выход).
- `--legacy`: ведёт себя как на macOS старше 14.2 (только общая громкость).
- `--open`: открывает панель сразу при запуске.
