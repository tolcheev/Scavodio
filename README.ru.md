<div align="center">

# Scavodio

**Извлечение аудио из любого видео. Один клик.**

[🇬🇧 Read in English](README.md)

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)](https://swift.org)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-blueviolet)](https://developer.apple.com/documentation/apple-silicon)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/tolcheev/Scavodio?color=brightgreen)](https://github.com/tolcheev/Scavodio/releases/latest)

[**Скачать DMG**](https://github.com/tolcheev/Scavodio/releases/latest) · [Сообщить об ошибке](https://github.com/tolcheev/Scavodio/issues) · [Предложить функцию](https://github.com/tolcheev/Scavodio/issues)

</div>

---

Scavodio — нативное macOS-приложение для извлечения аудиодорожек из видеофайлов через ffmpeg. Перетащи файл, выбери дорожку и формат — готово за секунды.

> *scavo* (итал.) — раскопки. Откопай звук.

---

## Возможности

- **Drag & drop** или выбор файла через диалог
- **Автоопределение всех аудиодорожек** через ffprobe — кодек, язык, битрейт, длительность
- **7 форматов экспорта:** MP3 · MKA · AAC · M4A · OGG · FLAC · Opus
- **Разбивка на части** — нарезай длинное аудио на куски: 30 мин · 1ч · 2ч · 3ч · 4ч · 6ч. Preview сразу показывает: `→ 3 части: 3ч + 3ч + 1ч`
- **Выбор папки вывода** — сохраняй куда угодно, не только рядом с источником
- **Установка ffmpeg в один клик** через Homebrew, с подтверждением
- **Отмена** извлечения в любой момент
- **Живой лог** — видно всё что делает ffmpeg
- **⌘R** — горячая клавиша для запуска
- Без Electron. Без Python. Без подписок. Только Swift.

---

## Поддерживаемые форматы

| Видео (вход) | Аудио (выход) |
|---|---|
| MKV · MP4 · MOV · AVI · WebM · M4V | **MP3** · MKA · AAC · M4A · OGG · FLAC · Opus |
| MTS · M2TS · TS · FLV · WMV · VOB · 3GP | |

---

## Установка

### Вариант А — Скачать DMG (рекомендуется)

1. Скачай DMG из [**Releases**](https://github.com/tolcheev/Scavodio/releases/latest) и открой его
2. Перетащи **Scavodio** в **Программы**
3. Открой ярлык **«Open Privacy Settings»** из DMG, или вручную:  
   **Системные настройки → Конфиденциальность и безопасность → Всё равно открыть**

Затем установи ffmpeg, если ещё нет:

```bash
brew install ffmpeg
```

Или нажми **Install ffmpeg** прямо в приложении.

> **Почему нужен лишний шаг?** Scavodio подписан ad-hoc, но не нотаризован Apple. macOS 13+ требует однократного разрешения в Системных настройках для приложений, распространяемых не через App Store. Это делается один раз.

### Вариант Б — Сборка из исходников

**Требования:** macOS 13+, Apple Silicon, Xcode Command Line Tools

```bash
xcode-select --install   # если ещё не установлено

git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio

./build.sh           # сборка в build/Scavodio.app
./build.sh install   # сборка + установка в /Applications
```

Скрипт компилирует через `swiftc`, записывает корректный `Info.plist`, копирует иконку и подписывает бандл. Xcode не нужен.

---

## Как это работает

```
Перетащи видео / выбери файл
        ↓
ffprobe → определяет аудиодорожки (кодек, язык, битрейт, длительность)
        ↓
Выбери дорожку + формат + папку вывода
        ↓
ffmpeg → извлекает аудио  [опционально: нарезает на части]
        ↓
Файл(ы) в выбранной папке
```

Аргументы subprocess передаются массивом, никогда строкой в шелл — **имена файлов с пробелами, Unicode и кириллицей работают корректно**.

---

## Структура проекта

```
Scavodio/
├── ScavodioApp.swift        — точка входа @main
├── ContentView.swift        — UI, drag & drop, обработка ошибок
├── AudioTrack.swift         — модель (кодек, язык, битрейт, длительность)
├── SupportedFormats.swift   — список форматов видео + UTType
├── FFmpegService.swift      — ffprobe · ffmpeg · разбивка · установка через brew
├── ProcessRunner.swift      — subprocess с таймаутом 30 с
├── OutputFileNamer.swift    — безопасное построение имён файлов, HFS+
├── SplitDuration.swift      — пресеты размера части при разбивке
├── AppIcon.icns             — иконка (включена для сборки из исходников)
├── Info.plist
└── Scavodio.entitlements

ScavodioTests/
├── ProcessRunnerTests.swift
├── OutputFileNamerTests.swift
├── FFmpegServiceTests.swift
└── SizeBudgetTests.swift

build.sh                     — скрипт сборки одной командой (без Xcode)
dmg_background.swift         — генератор фона для DMG
```

---

## Требования

| | |
|---|---|
| macOS | 13.0 Ventura или новее |
| Архитектура | Apple Silicon (arm64) |
| ffmpeg | через Homebrew (`brew install ffmpeg`) |
| Для сборки | Xcode Command Line Tools (`xcode-select --install`) |

---

## Безопасность

- Нет сетевого доступа — всё работает локально
- Нет app sandbox (нужен для запуска ffmpeg как subprocess)
- Hardened Runtime включён
- Аргументы subprocess — массивы, shell injection невозможен

---

## Вклад в проект

Pull request'ы приветствуются. Для крупных изменений — сначала открой issue.

```bash
git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio
open Scavodio.xcodeproj   # или: ./build.sh
```

Тесты: **⌘U** в Xcode.

---

## Лицензия

[MIT](LICENSE) — свободное использование, модификация и распространение.
