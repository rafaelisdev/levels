# Levels

Маленькое приложение для строки меню macOS: громкость каждого приложения отдельно,
плюс общая громкость устройства вывода. Раньше называлось VolumeMixer («Микшер»).

Сайт: **https://getlevels.vercel.app** (код в [site/](site/), Next.js на Vercel).

```bash
brew install rafaelisdev/tap/levels
```

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelisdev/levels/main/install.sh | bash
```

- Запускается на macOS 11 Big Sur и новее, на Apple Silicon и Intel (universal).
- Громкость отдельных приложений работает с macOS 14.2: только там Apple дала
  Core Audio process taps. На более старых системах остаётся общая громкость, а
  панель объясняет почему. Драйверы и расширения не ставятся.
- Клик по иконке приложения выключает его звук, правый клик даёт «Сбросить до 100%».
- Громкость запоминается по приложению.
- Пока приложение не трогали, Levels его не перехватывает. После первого движения
  ползунка перехват остаётся и на 100%, пока приложение не закроют. Иначе на границе
  99% ↔ 100% звук прыгал при переключении между прямым выводом и перехватом.

## Сборка

```bash
./build.sh            # build/Levels.app
./build.sh install    # плюс копирует в /Applications и запускает
./build.sh release    # плюс build/Levels.zip и его sha256 для brew
```

Иконка рисуется кодом по брендборду Levels:
`swift scripts/make_icon.swift Resources/AppIcon.icns` (с `--light` даёт светлый вариант).
Символ для строки меню и панели рисуется в `Sources/Levels/LevelsSymbol.swift`.

## Публикация

- код: `rafaelisdev/levels`, архив `Levels.zip` прикреплён к GitHub Release `vX.Y`;
- cask: репозиторий `rafaelisdev/homebrew-tap`, файл `Casks/levels.rb` из шаблона
  [packaging/levels.rb](packaging/levels.rb). Старое имя `volumemixer` перенаправлено
  на `levels` через `cask_renames.json`, поэтому `brew upgrade` переводит
  пользователей сам;
- новая версия: поднять `CFBundleShortVersionString` в `Resources/Info.plist`,
  закоммитить и запустить `scripts/publish.sh`. Он соберёт архив, создаст релиз и
  обновит cask.

Приложение не нотаризовано Apple. macOS проверяет только файлы с флагом карантина:
его ставят браузеры и brew cask, а `curl` не ставит. Поэтому cask снимает флаг
после установки (`postflight_steps`), а `install.sh` скачивает через `curl`.
Разрешение «Только системное аудио» macOS всё равно спросит, это отдельный механизм.

### Официальный каталог Homebrew

Чтобы ставилось как `brew install --cask levels` без tap, нужно:

- Apple Developer Program ($99 в год), сертификат **Developer ID Application**;
- подпись и нотаризация:
  ```bash
  SIGN_IDENTITY="Developer ID Application: Имя (TEAMID)" ./build.sh release
  xcrun notarytool submit build/Levels.zip --keychain-profile notary --wait
  xcrun stapler staple build/Levels.app   # и заново упаковать zip
  ```
- известность проекта: Homebrew не принимает совсем новые репозитории без звёзд
  и пользователей.

С сентября 2026 Homebrew убирает из официального каталога неподписанные и
ненотаризованные приложения. Бонус от подписи Developer ID: разрешение
«Только системное аудио» перестаёт слетать после обновлений.

## Отладка

```bash
open /Applications/Levels.app --stdout /tmp/levels.log --args --debug
```

- `--debug`: раз в секунду пишет уровни звука по каждому перехвату (вход и выход).
- `--legacy`: ведёт себя как на macOS старше 14.2 (только общая громкость).
- `--open`: открывает панель сразу при запуске.

## Сайт

`site/` — Next.js 16, статическая страница на Vercel (проект `getlevels`).

```bash
cd site && npm install && npm run dev      # http://localhost:3210
npm run render                             # пересобрать 3D-рендеры в Blender (headless)
vercel deploy --prod                       # публикация
```

Там же `public/llms.txt` и `public/llms-full.txt` для LLM, `robots`, `sitemap`,
OpenGraph-картинка и JSON-LD (SoftwareApplication + FAQPage).
