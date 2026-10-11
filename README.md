# Задачник: приложение для Android и Windows

Flutter-приложение с подключаемыми модулями. Аккаунт, база и шифрование те же, что у сайта: войдите той же почтой и паролем, и задачи появятся сразу.

- **Всегда на экране:** новая задача, календарь, «Сегодня», «Ближайшие 3 дня».
- **Модули (включаются галочкой):** сводка, все задачи, тренировки, талисман с гифкой, напоминания (Android), резервная копия.
- Порядок блоков меняется перетаскиванием: кнопка ⚙ «Блоки на экране» вверху.

Установщики собирает GitHub, ничего ставить на компьютер не нужно.

## 1. Репозиторий
1. На github.com создайте **новый** репозиторий, например `zadachnik-app`. Можно приватный: бесплатных минут сборки хватит с запасом.
2. **Add file → Upload files**, перетащите **всё содержимое** этой папки, включая папку `.github` → **Commit changes**.
   Если папка `.github` не загрузилась (в некоторых системах она скрыта), создайте файл вручную: **Add file → Create new file**, имя `.github/workflows/build.yml`, вставьте содержимое и сохраните.

## 2. Секреты (Settings → Secrets and variables → Actions → New repository secret)
| Имя | Что вставить |
|---|---|
| `SUPABASE_URL` | адрес проекта, как в `config.js` сайта: `https://….supabase.co` |
| `SUPABASE_ANON_KEY` | ключ anon / publishable, как в `config.js` |
| `ANDROID_KEYSTORE_BASE64` | содержимое файла `ANDROID_KEYSTORE_BASE64.txt` (из архива с ключом подписи) |
| `ANDROID_KEYSTORE_PASSWORD` | содержимое `ANDROID_KEYSTORE_PASSWORD.txt` |
| `ANDROID_KEY_ALIAS` | `zadachnik` |

Ключ подписи нужен, чтобы обновления APK ставились поверх старой версии без потери данных. Храните архив с ключом у себя и **не кладите его в репозиторий**.

## 3. Сборка
**Actions → «Сборка приложений» → Run workflow.** Android собирается около 10 минут, Windows около 15.
Готовые файлы лежат внизу страницы запуска, в разделе **Artifacts**:
- `Zadachnik-android`: внутри `Zadachnik-android.apk`;
- `Zadachnik-windows`: внутри `Zadachnik-Setup.exe` (установщик) и портативный zip.

Чтобы получить постоянные ссылки на скачивание: **Releases → Draft a new release** → тег `v1.0.0` → **Publish**. Через 15 минут файлы появятся в релизе.

## 4. Установка
- **Android:** скачайте APK на телефон и откройте. Разрешите «Установку из неизвестных источников» для браузера или файлового менеджера. После обновления данные сохраняются.
- **Windows:** запустите `Zadachnik-Setup.exe`. Установщик не подписан сертификатом, поэтому SmartScreen может предупредить: **Подробнее → Выполнить в любом случае**.

## Если сборка упала
Откройте упавший шаг в Actions, скопируйте последние 30–50 строк лога и пришлите их. Код писался без возможности собрать его заранее, так что первая сборка может потребовать правки.

## Как добавить свой модуль
1. Создайте `lib/modules/my_module.dart` с виджетом, обёрнутым в `Panel(...)` из `lib/widgets/common.dart`. Данные берите через `StoreScope.of(context)`.
2. Добавьте одну запись `AppModule(...)` в список `allModules` в `lib/modules/registry.dart`.

Модуль сам появится в «Блоках на экране».

## Устройство проекта
```
lib/
  main.dart                 запуск, тема, экран входа или главный
  core/crypto.dart          PBKDF2 + AES-GCM, совместимо с сайтом байт в байт
  core/store.dart           задачи, аккаунт, синхронизация с Supabase, офлайн-очередь
  core/layout.dart          какие блоки включены и в каком порядке
  core/notifications.dart   напоминания на Android (будильники прямо на телефоне)
  modules/                  блоки экрана, по файлу на модуль; registry.dart их список
  screens/                  вход, главный экран, настройка блоков
  widgets/                  общие элементы: панель, задача, форма
tool/patch_platforms.py     дописывает в Android/Windows-проект разрешения, подпись, иконку уведомлений
installer/zadachnik.iss     установщик Windows (Inno Setup)
.github/workflows/build.yml сборка APK и установщика
```
Папки `android/` и `windows/` в репозитории не хранятся: их создаёт `flutter create` при каждой сборке, а скрипт `patch_platforms.py` настраивает.

## Сборка на своём компьютере (необязательно)
Нужны Flutter 3.24.5, Android Studio (для APK) и Visual Studio 2022 с «Разработкой классических приложений на C++» (для Windows).
```
flutter create --platforms=android,windows --org ru.zadachnik --project-name zadachnik .
python tool/patch_platforms.py android
python tool/patch_platforms.py windows
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build windows --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
