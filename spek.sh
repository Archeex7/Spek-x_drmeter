#!/bin/bash

# === НАСТРОЙКИ ===
WORK_DIR="/tmp/spek_appimage_build"
OUTPUT_APPIMAGE="$HOME/Рабочий стол/Spek_Silent_GTK_v44.AppImage"

# Простые функции вывода (ТОЛЬКО В ТЕРМИНАЛ, БЕЗ ФАЙЛОВ)
log() { echo -e "\n\033[1;32m[STEP] $1\033[0m"; }
error() { echo -e "\n\033[1;31m[ERROR] $1\033[0m"; exit 1; }

log "=== ЗАПУСК СБОРКИ SPEK (SILENT + GTK FIX) ==="
log "Рабочая директория: $WORK_DIR"

# 1. СРЕДА
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || error "Fail mkdir"

# Зависимости (добавлен gtk3 для плагина)
log "Установка зависимостей..."
DEPS="base-devel git wget cmake wxwidgets-gtk3 python python-pip libx11 patchelf fuse2 file libsndfile gtk3"
sudo pacman -S --needed --noconfirm $DEPS || error "Pacman fail"

# Python venv
log "Настройка Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install pyinstaller rich click rich-click numpy scipy soundfile || error "Pip fail"

# 2. ИНСТРУМЕНТЫ (LinuxDeploy + GTK Plugin)
log "Загрузка инструментов..."
wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

# Скачиваем плагин GTK для фикса интерфейса
wget -q https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
chmod +x linuxdeploy-plugin-gtk.sh

mkdir ffmpeg_static
cd ffmpeg_static
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar -xf ffmpeg-release-amd64-static.tar.xz --strip-components=1
cd ..

# 3. ANALYZER (Python)
log "Подготовка анализатора..."
git clone https://codeberg.org/janw/drmeter.git drmeter_src

# --- LAUNCHER.PY (ПОЛНАЯ ТИШИНА + КОРРЕКТНЫЙ АНАЛИЗ) ---
cat > launcher.py <<'EOF'
import sys, os, io, re, json, subprocess, datetime, multiprocessing
from contextlib import redirect_stdout, redirect_stderr

# Настройка путей (без логов)
if getattr(sys, 'frozen', False):
    BASE_DIR = os.path.dirname(sys.executable)
    FFPROBE_BIN = os.path.join(BASE_DIR, "ffprobe")
    os.environ["PATH"] = BASE_DIR + os.pathsep + os.environ["PATH"]
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    FFPROBE_BIN = "ffprobe"

def get_metadata(filepath):
    # Получение метаданных без вывода ошибок
    cmd = [FFPROBE_BIN, "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", filepath]
    try:
        res = subprocess.check_output(cmd, env=os.environ.copy())
        data = json.loads(res)
        audio = next((s for s in data.get('streams', []) if s['codec_type'] == 'audio'), {})
        if not audio: return None

        fmt = data.get('format', {})
        bits = audio.get('bits_per_raw_sample') or audio.get('bits_per_sample')
        if not bits or bits == '0':
            c = audio.get('codec_name', '')
            if 's16' in c: bits = 16
            elif 's24' in c: bits = 24
            elif 'f32' in c: bits = 32
            else: bits = "?"
        return {'rate': int(audio.get('sample_rate', 0)), 'ch': int(audio.get('channels', 0)), 'dur': float(fmt.get('duration', 0)), 'size': int(fmt.get('size', 0)), 'bits': bits}
    except:
        return None

def fmt_size(b):
    for u in ['B','KB','MB','GB']:
        if b < 1024: return f"{b:.2f}{u}"
        b /= 1024
    return f"{b:.2f}TB"

def append_report(filepath, meta, dr_stats):
    # Запись отчета ТОЛЬКО внутри папки с музыкой
    try:
        file_dir = os.path.dirname(filepath)
        report_path = os.path.join(file_dir, "spek", "_Analysis_Report.txt")
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        filename = os.path.basename(filepath)
        dur = str(datetime.timedelta(seconds=int(meta['dur'])))
        if dur.startswith("0:"): dur = dur[2:]
        fn_clean = (filename[:52] + "...") if len(filename) > 55 else filename
        fn_clean = fn_clean.ljust(55)

        TOP = "╭──────┬───────────┬───────────┬───────┬─────────┬───────┬────┬──────────┬─────────────────────────────────────────────────────────╮"
        MID = "├──────┼───────────┼───────────┼───────┼─────────┼───────┼────┼──────────┼─────────────────────────────────────────────────────────┤"
        BOT = "╰──────┴───────────┴───────────┴───────┴─────────┴───────┴────┴──────────┴─────────────────────────────────────────────────────────╯"
        HDR = "│ DR   │ Peak      │ RMS       │ Time  │ Rate    │ Bit   │ Ch │ Size     │ Filename                                                │"
        row = "│ {:<4} │ {:>9} │ {:>9} │ {:>5} │ {:>7} │ {:>5} │ {:>2} │ {:>8} │ {:<55} │".format(dr_stats['dr'], dr_stats['peak'], dr_stats['rms'], dur, f"{meta['rate']}Hz", f"{meta['bits']}bit", meta['ch'], fmt_size(meta['size']), fn_clean)

        mode = "a"
        if os.getenv("SPEK_CLEAN_REPORT") == "1":
            mode = "w"

        with open(report_path, mode, encoding="utf-8") as f:
            if f.tell() == 0:
                f.write(f"Analyzed: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\nFolder:   {file_dir}\n{TOP}\n{HDR}\n{MID}\n")
            f.write(row + "\n")
            if os.getenv("SPEK_IS_LAST") == "1":
                f.write(BOT + "\n\n")
    except:
        pass # Если не удалось записать отчет - молчим. Никаких логов на рабочий стол.

if __name__ == "__main__":
    multiprocessing.freeze_support()
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        if len(sys.argv) < 2: sys.exit(0)
        target = sys.argv[1]

        f_out = io.StringIO()
        f_err = io.StringIO()

        # Попытка точного анализа
        try:
            with redirect_stdout(f_out), redirect_stderr(f_err):
                from drmeter.cli import main
                sys.argv = [sys.argv[0], target]
                main()
        except:
            # Если drmeter упал (короткий файл), просто глушим ошибку.
            # Мы НЕ пишем лог. Мы просто идем дальше.
            pass

        output = f_out.getvalue() + f_err.getvalue()
        clean = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])').sub('', output)

        stats = {'dr': 'DR?', 'peak': '?', 'rms': '?'}
        m = re.search(r'(DR\d+)', clean);
        if m: stats['dr'] = m.group(1)
        vals = re.findall(r'([-\d\.]+\s+dB)', clean)
        if len(vals) >= 2: stats['peak'], stats['rms'] = vals[0], vals[1]

        print(f"{stats['dr']}|{stats['peak']}|{stats['rms']}")

        meta = get_metadata(target)
        if meta:
            append_report(target, meta, stats)

    except Exception:
        # Глобальный перехват: вывод заглушки, никаких файлов
        print("DR?|?|?")
EOF

cp -r drmeter_src/drmeter .
log "Компиляция Python..."
pyinstaller --clean --onefile --name spek-analyzer --collect-all rich launcher.py || error "PyInstaller fail"

# 4. SPEK C++
log "Сборка C++..."
git clone https://github.com/MikeWang000000/spek-X.git spek_src
cd spek_src

# --- ПАТЧЕР C++ ---
cat > patcher_appimage.py <<'EOF'
import sys, re, os
def read(p):
    with open(p) as f: return f.read()
def write(p, c):
    with open(p, 'w') as f: f.write(c)

# Header Inject
try:
    code = read("src/spek-spectrogram.cc")
    if '#include <stdlib.h>' not in code: code = "#include <stdlib.h>\n" + code
    ptn = re.compile(r'void\s+SpekSpectrogram::render\s*\([^{]*\{', re.MULTILINE)
    m = ptn.search(code)
    if m:
        start = m.end(); i=start; cnt=1
        while i<len(code) and cnt>0:
            if code[i]=='{': cnt+=1;
            elif code[i]=='}': cnt-=1;
            i+=1
        body = code[start:i].replace("this->desc", "fullDesc")
        inj = "\n    wxString stats = wxString::FromUTF8(getenv(\"SPEK_STATS\"));\n    wxString fullDesc = this->desc;\n    if (!stats.IsEmpty() && !fullDesc.Contains(\"RMS:\")) fullDesc += stats;\n"
        write("src/spek-spectrogram.cc", code[:start] + inj + body + code[i:])
except: pass

# Logic Loop
try:
    code = read("src/spek-window.cc")
    headers = r'''#include <wx/dir.h>
#include <wx/filename.h>
#include <wx/progdlg.h>
#include <wx/stdpaths.h>
#include <wx/utils.h>
#include <wx/tokenzr.h>

void CollectAudioFilesRecursive(const wxString& path, wxArrayString& list) {
    if (wxDirExists(path)) {
        wxDir dir(path);
        if (dir.IsOpened()) {
            wxString f; bool c = dir.GetFirst(&f, "", wxDIR_FILES | wxDIR_DIRS);
            while (c) { CollectAudioFilesRecursive(path + wxFileName::GetPathSeparator() + f, list); c = dir.GetNext(&f); }
        }
    } else if (wxFileExists(path)) {
        wxString ext = wxFileName(path).GetExt().Lower();
        if (ext == "mp3" || ext == "flac" || ext == "wav" || ext == "m4a" || ext == "aac" || ext == "ogg" || ext == "opus" || ext == "wma" || ext == "aiff") list.Add(path);
    }
}

wxString AnalyzeAudioStats(const wxString& path) {
    wxString binDir = wxFileName(wxStandardPaths::Get().GetExecutablePath()).GetPath();
    wxString cmd = "\"" + binDir + "/spek-analyzer\" \"" + path + "\"";
    wxArrayString out, err;
    wxExecute(cmd, out, err, wxEXEC_SYNC | wxEXEC_NODISABLE);
    if (out.GetCount() > 0) {
        wxStringTokenizer tk(out[0], "|");
        if (tk.CountTokens() >= 3) {
            wxString drVal = tk.GetNextToken();
            wxString peakVal = tk.GetNextToken();
            wxString rmsVal = tk.GetNextToken();
            return wxString::Format(" | %s | Peak: %s | RMS: %s", drVal, peakVal, rmsVal);
        }
    }
    return " | DR?";
}'''
    last_inc = list(re.finditer(r'#include\s+[<"].+[>"]', code))[-1].end()
    code = code[:last_inc] + "\n" + headers + "\n" + code[last_inc:]
    match = re.search(r'bool\s+(\w+::)?OnDropFiles\s*\(([^)]+)\)\s*\{', code)
    if match:
        start = match.end(); i=start; cnt=1
        while i<len(code) and cnt>0:
            if code[i]=='{': cnt+=1
            elif code[i]=='}': cnt-=1
            i+=1
        new_body = r'''
    wxArrayString allFiles;
    for (size_t i = 0; i < filenames.GetCount(); i++) CollectAudioFilesRecursive(filenames[i], allFiles);

    if (allFiles.IsEmpty()) return true;

    allFiles.Sort();

    wxProgressDialog bar("Spek Processing", "Analyzing...", allFiles.GetCount(), NULL, wxPD_APP_MODAL|wxPD_AUTO_HIDE|wxPD_REMAINING_TIME|wxPD_SMOOTH);
    wxString exe = wxStandardPaths::Get().GetExecutablePath();

    for (size_t i = 0; i < allFiles.GetCount(); i++) {
        wxString in = allFiles[i];

        bool isNewFolderSession = false;
        if (i == 0) {
            isNewFolderSession = true;
        } else {
            wxString currentDir = wxFileName(in).GetPath();
            wxString prevDir = wxFileName(allFiles[i-1]).GetPath();
            if (currentDir != prevDir) isNewFolderSession = true;
        }

        if (isNewFolderSession) wxSetEnv("SPEK_CLEAN_REPORT", "1");
        else wxUnsetEnv("SPEK_CLEAN_REPORT");

        bool closeTable = false;
        if (i == allFiles.GetCount() - 1) {
            closeTable = true;
        } else {
            wxString currentDir = wxFileName(in).GetPath();
            wxString nextDir = wxFileName(allFiles[i+1]).GetPath();
            if (currentDir != nextDir) closeTable = true;
        }

        if (closeTable) wxSetEnv("SPEK_IS_LAST", "1"); else wxUnsetEnv("SPEK_IS_LAST");

        wxSetEnv("SPEK_STATS", AnalyzeAudioStats(in));
        wxSetEnv("SPEK_CLI_MODE", "1");

        wxString outDir = wxFileName(in).GetPath() + "/spek";
        if (!wxDirExists(outDir)) wxFileName::Mkdir(outDir, 0777, wxPATH_MKDIR_FULL);
        wxString out = outDir + "/" + wxFileName(in).GetName() + ".png";

        if (!wxFileExists(out)) wxExecute(wxString::Format("\"%s\" \"%s\" \"%s\" 1920 1080", exe, in, out), wxEXEC_SYNC | wxEXEC_HIDE_CONSOLE);

        bar.Update(i + 1);
    }
    wxUnsetEnv("SPEK_IS_LAST");
    wxUnsetEnv("SPEK_CLEAN_REPORT");
    return true;'''
        write("src/spek-window.cc", code[:start] + new_body + "}\n" + code[i+1:])
except: pass
EOF
python3 patcher_appimage.py

mkdir -p m4
autopoint -f >/dev/null
autoreconf -vfi -I m4 >/dev/null
./configure --prefix=/usr >/dev/null
make -j$(nproc) >/dev/null

# 5. УПАКОВКА
log "Сборка AppDir..."
cd "$WORK_DIR"
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/scalable/apps
cd spek_src
make install DESTDIR="$WORK_DIR/AppDir" >/dev/null
cd "$WORK_DIR"

cp dist/spek-analyzer AppDir/usr/bin/
cp ffmpeg_static/ffmpeg AppDir/usr/bin/
cp ffmpeg_static/ffprobe AppDir/usr/bin/
chmod +x AppDir/usr/bin/*

wget -q -O AppDir/usr/share/icons/hicolor/scalable/apps/spek.svg https://raw.githubusercontent.com/alexkay/spek/master/data/icons/spek.svg
cat > AppDir/usr/share/applications/spek.desktop <<EOF
[Desktop Entry]
Name=Spek
GenericName=Spectrum Analyser
Comment=View spectrograms of your audio files
Exec=spek %f
Icon=spek
Type=Application
Categories=AudioVideo;Audio;
StartupNotify=true
EOF

log "Создание AppImage (GTK PLUGIN)..."
export NO_STRIP=true
export LINUXDEPLOY_ICON_FILE=AppDir/usr/share/icons/hicolor/scalable/apps/spek.svg

# Упаковываем с GTK плагином для автономности интерфейса
./linuxdeploy-x86_64.AppImage \
    --appdir AppDir \
    --plugin gtk \
    --output appimage \
    --desktop-file AppDir/usr/share/applications/spek.desktop \
    --icon-file AppDir/usr/share/icons/hicolor/scalable/apps/spek.svg \
    --executable AppDir/usr/bin/spek \
    || error "LinuxDeploy failed"

mv Spek*.AppImage "$OUTPUT_APPIMAGE"
log "=== ГОТОВО! Файл: $OUTPUT_APPIMAGE ==="
