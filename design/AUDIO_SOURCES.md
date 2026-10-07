# Аудио Frontier Kingdoms — 6 октября 2026

Две оригинальные композиции и восемь эффектов созданы процедурным синтезом в `tools/compose_audio.py`. Записи не используют чужие семплы или готовые мелодии. WAV находятся в `assets/audio/original`, копии для прослушивания — в `audio-site/dist/audio`. Формат: stereo PCM, 32 kHz, 16 bit.

| Ключ для подключения | Файл | Назначение |
| --- | --- | --- |
| Menu | menu.wav | Frontier Dawn: меню, редактор, подготовка |
| Battle | battle.wav | March of the Banners: бой |
| Click | click.wav | Кнопки интерфейса |
| Select | select.wav | Выбор здания или войск |
| Order | order.wav | Отправка войск |
| Place | place.wav | Изменение карты |
| Error | error.wav | Ошибка действия |
| Chest | chest.wav | Получение результата кейса |
| Victory | victory.wav | Победа |
| Defeat | defeat.wav | Поражение |

Сейчас все оригинальные `Id` в `src/AudioCatalog.luau` равны **0**. Игра выбирает временные Roblox-ассеты; оригиналы пока доступны только как WAV и на сайте. Вход в Creator Hub нужен для загрузки WAV в аккаунт владельца игры и получения ID, поскольку локальный файл не является Roblox audio asset. Для каждой записи требуется предоставить игре доступ к загруженному ассету. Инструкции Roblox: [Audio assets](https://create.roblox.com/docs/audio/assets).

Временные источники:

- Меню: [Medieval Market d OL — APM Music](https://create.roblox.com/store/asset/1847223666/Medieval-Market-d-OL), ID `1847223666`.
- Бой: [Flame a — APM Music](https://create.roblox.com/store/asset/9045862008/Flame-a), ID `9045862008`.
- Интерфейс: [UI Click 1 — 0FFZ3TI](https://create.roblox.com/store/asset/113397864512278/UI-Click-1), ID `113397864512278`. Для разных действий временно изменяется скорость и громкость одной записи.
- Дополнительный прежний запасной трек: `Medieval_Ambient_Lute`, ID `93176902923482`, автор DistrokidOfficial. Его доступность в опубликованной игре отдельно не подтверждена.

## Что сейчас блокирует запуск опубликованной игры

В настоящем Studio обнаружена ошибка `EditableMesh is not accessible. Go to Security Tab...`. В Security переключатель доступа был недоступен; интерфейс показывал `You must be 13+ ID verified to access this API`. Из-за этой ошибки модели не загружались, а кнопка Play оставалась недоступной. Это отдельная проблема от подключения аудио. Позже пользователь сообщил, что проверка аккаунта завершена; доступ API после этого ещё не подтверждён. Нужно повторно открыть Studio, проверить переключатель Mesh / Image APIs и запуск. Проверку аккаунта выполняет сам владелец. Эти сведения описывают наблюдённое состояние конкретного аккаунта.

## Как подключить загруженные оригиналы

1. Загрузить десять WAV в Creator Hub от владельца игры, дождаться готовности ассетов и предоставить игре права использования. Скопировать именно числовой Asset ID каждой записи.
2. Запустить `tools/connect_audio.py` с десятью явными ID. Команда ниже — пример формы; значения `123` нужно заменить настоящими ID. Сначала добавить `--dry-run`, чтобы проверить значения без записи.

```powershell
python tools/connect_audio.py --dry-run `
  --id Menu=123 --id Battle=123 --id Click=123 --id Select=123 `
  --id Order=123 --id Place=123 --id Error=123 --id Chest=123 `
  --id Victory=123 --id Defeat=123
```

3. Убрать `--dry-run` и повторить команду. Скрипт изменит только ID в `src/AudioCatalog.luau`, `assets/audio/original/manifest.json` и, если она существует, `audio-site/dist/manifest.json`. Он не загружает файлы, не публикует игру или сайт и не проверяет права Roblox по сети.
4. Выполнить `python tools/sync_place.py`, затем `python tools/check_english.py` и `python tools/run_local_qa.py`. Закрыть старую вкладку Studio и открыть обновлённый `inex.rbxl`, убедиться, что открыт нужный облачный place, затем опубликовать обновление через Studio.
5. Проверить музыку меню/боя и эффекты в Roblox; отдельно убедиться, что доступ к аудио предоставлен этой игре. Проверку локального звука выполнить с двумя игроками. Подмена ID в файле без синхронизации и публикации не изменит уже опубликованную версию.

Не запускать `tools/compose_audio.py` после подключения ID без сохранения этих значений: генератор заново записывает manifest с `robloxAssetId=0`.
