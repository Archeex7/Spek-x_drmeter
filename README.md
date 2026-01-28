# Spek-x_drmeter
Перетащите аудио или папку в окно: программа автоматически сохранит спектрограмму и DR-отчёт рядом с файлами. / Drag &amp; drop audio or a folder into the window. The app auto-generates a spectrogram and DR report in the source directory.


Вот обновленная и расширенная версия README.md, включающая упоминание авторства скрипта, как ты и просил.
Spek-X: Auto-Analysis & DR Meter Edition

(RU) Усовершенствованная версия акустического анализатора Spek. Эта сборка автоматизирует процесс проверки качества аудиобиблиотек, добавляя пакетную обработку, расчет динамического диапазона (DR) и генерацию детальных отчетов. Поставляется в формате AppImage (работает на большинстве дистрибутивов Linux).

(EN) An enhanced version of the Spek acoustic analyzer. This build automates the quality check process for audio libraries by adding batch processing, Dynamic Range (DR) calculation, and detailed report generation. Distributed as an AppImage (runs on most Linux distributions).
🇷🇺 Основные возможности

Эта версия была модифицирована для тех, кто работает с большими коллекциями музыки и нуждается в быстром техническом анализе.

    Пакетная обработка (Drag & Drop): Просто перетащите папку с музыкой (или несколько файлов) в окно программы. Скрипт рекурсивно найдет все аудиофайлы внутри.

    Автоматическое создание спектрограмм: Программа автоматически сохранит изображение спектра (1920x1080) для каждого трека в подпапку spek рядом с оригинальными файлами.

    Анализ Dynamic Range (DR): Встроенный алгоритм drmeter вычисляет:

        DR (Dynamic Range)

        Peak dB (Пиковый уровень)

        RMS dB (Среднеквадратичный уровень)

    Текстовые отчеты: В папке назначения создается файл _Analysis_Report.txt с красивой таблицей, содержащей технические данные (битрейт, частота, битность, каналы) и результаты замеров DR для каждого трека.

    Интеграция в интерфейс: Данные DR/Peak/RMS также отображаются прямо на сгенерированной спектрограмме.

Как использовать

    Скачайте файл .AppImage.

    Сделайте его исполняемым: chmod +x Spek_Silent_GTK_v44.AppImage.

    Запустите программу.

    Перетащите папку с альбомом или отдельные файлы в окно.

    Дождитесь окончания процесса (прогресс-бар покажет статус).

    Зайдите в папку с вашей музыкой — там появится директория spek с результатами.

🇬🇧 Key Features

This version is modified for audiophiles and archivists who deal with large music collections and need rapid technical analysis.

    Batch Processing (Drag & Drop): Simply drag and drop a folder (or multiple files) into the application window. It recursively scans for all audio files inside.

    Auto-Spectrogram Generation: The app automatically saves a spectrogram image (1920x1080) for every track into a spek subfolder located in the source directory.

    Dynamic Range (DR) Analysis: The integrated drmeter algorithm calculates:

        DR (Dynamic Range)

        Peak dB

        RMS dB

    Text Reports: A detailed _Analysis_Report.txt is generated in the output folder. It features a formatted table containing technical specs (Bitrate, Sample Rate, Bit Depth, Channels) and DR measurements for each track.

    Visual Overlay: DR, Peak, and RMS values are also appended directly to the text description on the generated spectrogram image.

How to Use

    Download the .AppImage file.

    Make it executable: chmod +x Spek_Silent_GTK_v44.AppImage.

    Run the application.

    Drag and drop a folder or files into the window.

    Wait for the process to finish (a progress bar will indicate status).

    Check your music folder — a new spek directory will contain the results.

## 📊 Пример отчета / Report Example

Файл / File: `_Analysis_Report.txt`

```text
Analyzed: 202X-XX-XX 14:30:00
Folder:   /home/user/Music/Artist - Album
╭──────┬───────────┬───────────┬───────┬─────────┬───────┬────┬──────────┬──────────────────────────────────────────╮
│ DR   │ Peak      │ RMS       │ Time  │ Rate    │ Bit   │ Ch │ Size     │ Filename                                 │
├──────┼───────────┼───────────┼───────┼─────────┼───────┼────┼──────────┼──────────────────────────────────────────┤
│ DR11 │  -0.50 dB │ -14.20 dB │ 03:45 │ 44100Hz │ 16bit │ 2  │ 35.40MB  │ 01 - Track Name.flac                     │
│ DR12 │  -1.10 dB │ -16.05 dB │ 04:20 │ 44100Hz │ 16bit │ 2  │ 42.10MB  │ 02 - Another Track.flac                  │
╰──────┴───────────┴───────────┴───────┴─────────┴───────┴────┴──────────┴──────────────────────────────────────────╯

🙏 Credits / Благодарности

Этот проект является модификацией существующих Open Source инструментов. / This project is a modification of existing Open Source tools.

    Script & Modification Logic: Gemini v3 pro — Весь код сборочного скрипта (.sh) и логика автоматизации написаны ИИ Gemini v3 pro. / The entire build script (.sh) and automation logic were written by AI Gemini v3 pro.

    Original Spek Author: AlexKay

    Spek-X Fork: MikeWang000000

    DRMeter: janw
