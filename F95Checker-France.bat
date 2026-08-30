@echo off
setlocal EnableExtensions
cd /d "%~dp0"

REM Mise a jour auto depuis Gist (laisser vide pour desactiver) :
REM set "GIST_RAW_URL=https://gist.githubusercontent.com/Hunteraulo1/a80374e7e352735b91b1709fc17d57f0/raw/84ca3878db75d666483a421b4411095bf2a8ce3e/gistfile1.bat"
set "GIST_RAW_URL="

if /i "%~1"=="--no-update" shift
if defined GIST_RAW_URL call :gist_update
if errorlevel 1 exit /b 0

set "RUNTIME=%~dp0._f95_france_cache"
set "SRCDIR=%~dp0F95Checker-src"
set "EXTRA="
set "DO_LAUNCH=1"
if /i "%~1"=="reconfigure" set "EXTRA=--reconfigure" & set "DO_LAUNCH=0"
if /i "%~1"=="--reconfigure" set "EXTRA=--reconfigure" & set "DO_LAUNCH=0"
if /i "%~1"=="setup-only" set "EXTRA=--setup-only" & set "DO_LAUNCH=0"

set "PY=python"
py -3.12 --version >nul 2>&1 && set "PY=py -3.12"
if errorlevel 1 py -3 --version >nul 2>&1 && set "PY=py -3"

%PY% --version >nul 2>&1
if errorlevel 1 (
    echo Python 3.11+ requis : https://www.python.org/downloads/
    pause
    exit /b 1
)

if not exist "%RUNTIME%" mkdir "%RUNTIME%"
call :extract_embedded || (
    echo Echec extraction des scripts integres.
    pause
    exit /b 1
)

echo.
echo === F95Checker France ===
echo.

%PY% "%RUNTIME%\setup_france.py" %EXTRA%
if errorlevel 1 (
    pause
    exit /b 1
)

if "%DO_LAUNCH%"=="0" exit /b 0

for /f "delims=" %%W in ('%PY% -c "import sys, pathlib; p=pathlib.Path(sys.executable); w=p.with_name('pythonw.exe'); print(w if w.is_file() else p)"') do set "PYW=%%W"
if not exist "%SRCDIR%\main.py" (
    echo F95Checker-src manquant. Relancez le .bat avec Internet/Git.
    pause
    exit /b 1
)
%PY% -m py_compile "%SRCDIR%\modules\gui.py" 2>nul
if errorlevel 1 (
    echo gui.py invalide. Relancez le .bat pour reparer le patch.
    pause
    exit /b 1
)
echo.
echo Lancement de F95Checker...
start "" /D "%SRCDIR%" "%PYW%" main.py
echo F95Checker demarre (fenetre separee, sans console).
echo.
REM Fermer cette console si le .bat a ete ouvert par double-clic
echo %CMDCMDLINE% | findstr /I /C:"/c" >nul && exit
exit /b 0

:extract_embedded
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $bat='%~f0'; $rt='%RUNTIME%'; [IO.Directory]::CreateDirectory($rt)|Out-Null; $lines=[IO.File]::ReadAllLines($bat,[Text.Encoding]::UTF8); $blocks=@(@('@@BEGIN_SETUP_FRANCE@@','setup_france.py'),@('@@BEGIN_FRANCE_LABELS@@','france_labels.py'),@('@@BEGIN_FRANCE_ICON@@','france_icon.py'),@('@@BEGIN_LC_GAMES@@','lc_games.py'),@('@@BEGIN_SILENT_LAUNCHER@@','silent_launch.vbs')); foreach($pair in $blocks){ $b=@(); $in=$false; foreach($l in $lines){ if($l -eq $pair[0]){$in=$true; continue}; $end=$pair[0] -replace 'BEGIN','END'; if($l -eq $end){break}; if($in){$b+=$l}}; if(-not $b.Count){ throw ('Bloc '+$pair[0]+' introuvable') }; [IO.File]::WriteAllLines((Join-Path $rt $pair[1]),$b,[Text.UTF8Encoding]::new($false)) } }"
exit /b %ERRORLEVEL%

:gist_update
if not exist "%~dp0._f95_france_cache" mkdir "%~dp0._f95_france_cache"
set "GIST_TMP=%~dp0._f95_france_cache\F95Checker-France.gist.bat"
set "GIST_HELPER=%~dp0._f95_france_cache\apply_gist_update.cmd"
set "F95_RELUNCH_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri $env:GIST_RAW_URL -OutFile $env:GIST_TMP -UseBasicParsing -TimeoutSec 30; exit 0 } catch { exit 2 }"
if errorlevel 1 exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=(Get-FileHash -Algorithm SHA256 $env:GIST_TMP).Hash; $b=(Get-FileHash -Algorithm SHA256 '%~f0').Hash; if($a -eq $b){exit 1}else{exit 0}"
if errorlevel 1 exit /b 0
echo.
echo Mise a jour depuis Gist...
(
echo @echo off
echo ping -n 2 127.0.0.1 ^>nul
echo copy /y "%GIST_TMP%" "%~f0" ^>nul
echo del "%GIST_TMP%" 2^>nul
echo start "" "%~f0" %F95_RELUNCH_ARGS%
echo del "%%~f0"
) > "%GIST_HELPER%"
start "" /min cmd /c "%GIST_HELPER%"
exit /b 1

goto :eof
@@BEGIN_SETUP_FRANCE@@
#!/usr/bin/env python3
"""Installation du patch F95-France + lancement F95Checker."""

from __future__ import annotations

import argparse
import configparser
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCH_DIR = Path(__file__).resolve().parent
CACHE_DIR = ROOT / "._f95_france_cache"
SRC = ROOT / "F95Checker-src"
INI = CACHE_DIR / "france_labels.ini"
REPO = "https://github.com/WillyJL/F95Checker.git"
BROKEN_MARKER = CACHE_DIR / "broken_commit.txt"
PATCHED_FILES_TO_VERIFY = (
    "main.py",
    "modules/gui.py",
    "modules/api.py",
    "modules/callbacks.py",
    "modules/globals.py",
    "modules/rpc_thread.py",
    "common/structs.py",
    "modules/wine.py",
)

GUI_IMPORT_OLD = """from modules import (
    api,
    callbacks,
    colors,
    db,
    globals,"""

GUI_IMPORT_NEW = """from modules import (
    api,
    callbacks,
    colors,
    db,
    france_labels,
    globals,"""

GUI_SNIPPET = '''
        if draw_settings_section("F95 France"):
            draw_settings_label("Synchronisation via F95-France")
            imgui.table_next_row()
            imgui.table_next_column()
            imgui.table_next_column()
            france_btn_disabled = france_labels.is_busy()
            if france_btn_disabled:
                imgui.push_disabled()
            if imgui.button("Sync", width=right_width):
                async_thread.run(france_labels.sync_from_gui())
            if france_btn_disabled:
                imgui.pop_disabled()
            if france_labels.last_result():
                draw_settings_label(france_labels.last_result())
            imgui.text("")
            imgui.spacing()
            imgui.end_table()

'''

GUI_ANCHOR = """            imgui.end_table()
            imgui.spacing()

        if draw_settings_section("Manage"):"""

GUI_ANCHOR_REPLACEMENT = """            imgui.end_table()
            imgui.spacing()
""" + GUI_SNIPPET + """
        if draw_settings_section("Manage"):"""


def find_python() -> list[str]:
    for cmd in (["py", "-3.12"], ["py", "-3"], ["python"]):
        try:
            subprocess.run([*cmd, "--version"], check=True, capture_output=True)
            return cmd
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
    return []


def ensure_src() -> None:
    if (SRC / "main.py").is_file():
        return
    print("Telechargement de F95Checker (git clone)...")
    if shutil.which("git"):
        subprocess.run(["git", "clone", "--depth", "1", REPO, str(SRC)], check=True, cwd=ROOT)
        return
    raise SystemExit(
        "F95Checker-src introuvable et Git non installe.\n"
        "Installez Git : https://git-scm.com/download/win"
    )


def _verify_patched_files_compile() -> None:
    import py_compile
    for rel in PATCHED_FILES_TO_VERIFY:
        py_compile.compile(str(SRC / rel), doraise=True)


def auto_update_upstream() -> None:
    """Recupere les nouveaux commits de F95Checker et reapplique nos patches.

    Si un patch ne correspond plus (ancre changee/supprimee en amont), revient
    automatiquement a la derniere version qui fonctionnait, sans jamais bloquer
    le lancement. Ne reessaie pas un commit deja identifie comme casse tant
    qu'un nouveau commit n'est pas disponible.
    """
    if not shutil.which("git") or not (SRC / ".git").is_dir():
        return
    try:
        subprocess.run(
            ["git", "fetch", "origin", "main"],
            check=True, cwd=SRC, capture_output=True, timeout=30,
        )
        local = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            check=True, cwd=SRC, capture_output=True, text=True,
        ).stdout.strip()
        remote = subprocess.run(
            ["git", "rev-parse", "origin/main"],
            check=True, cwd=SRC, capture_output=True, text=True,
        ).stdout.strip()
    except Exception:
        return  # Pas de connexion ou souci git : on continue avec la version actuelle

    if local == remote:
        return  # Deja a jour

    broken = BROKEN_MARKER.read_text(encoding="utf-8").strip() if BROKEN_MARKER.is_file() else ""
    if remote == broken:
        return  # Deja tente et incompatible, on ne reessaie pas a chaque lancement

    print(f"Mise a jour F95Checker disponible ({local[:7]} -> {remote[:7]})...")
    subprocess.run(["git", "reset", "--hard", "origin/main"], check=True, cwd=SRC, capture_output=True)
    (SRC / ".deps_ok").unlink(missing_ok=True)
    try:
        apply_patches()
        _verify_patched_files_compile()
    except (Exception, SystemExit) as exc:
        print(f"Mise a jour incompatible avec nos patches ({exc}).")
        print("Retour a la version precedente en attendant un correctif.")
        subprocess.run(["git", "reset", "--hard", local], check=True, cwd=SRC, capture_output=True)
        (SRC / ".deps_ok").unlink(missing_ok=True)
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        BROKEN_MARKER.write_text(remote, encoding="utf-8")
        return  # main() rappelle apply_patches() juste apres, sur la version restauree

    if BROKEN_MARKER.is_file():
        BROKEN_MARKER.unlink()
    print("Mise a jour appliquee avec succes.")


def repair_gui(text: str) -> str:
    """Corrige une ancienne injection qui cassait la syntaxe de gui.py."""
    import re

    fixed = 'draw_settings_label("Labels traduits via l\'API F95-France.")'
    return re.sub(
        r'draw_settings_label\(\s*"Ajoute ou retire le label traduit.*?F95-France\.\s*"\s*\)',
        fixed,
        text,
        flags=re.DOTALL,
    )


def verify_gui() -> None:
    import py_compile
    py_compile.compile(str(SRC / "modules" / "gui.py"), doraise=True)


MAIN_ICON_OLD = """def _start():
    patches.apply()

    if "-c" in sys.argv:"""

MAIN_ICON_NEW = """def _start():
    patches.apply()
    if sys.platform == "win32":
        try:
            from modules import france_icon
            france_icon.apply_process_branding()
        except Exception:
            pass

    if "-c" in sys.argv:"""

STRUCTS_GODOT_ANCHOR = """    ("Flash",      (4,  {"color": colors.hex_to_rgba_0_1("#616161"), "category": Category.Games})),"""

STRUCTS_GODOT_PATCHED = """    ("Flash",      (4,  {"color": colors.hex_to_rgba_0_1("#616161"), "category": Category.Games})),
    ("Godot",      (31, {"color": colors.hex_to_rgba_0_1("#478CBF"), "category": Category.Games})),"""

GUI_ICON_OLD = """        glfw.set_window_icon(self.window, 1, Image.open(globals.self_path / "resources/icons/icon.png"))

        # Window callbacks"""

GUI_ICON_NEW = """        glfw.set_window_icon(self.window, 1, Image.open(globals.self_path / "resources/icons/icon.png"))
        if sys.platform == "win32":
            try:
                from modules import france_icon
                france_icon.apply_glfw_window_icon(self.window)
            except Exception:
                pass

        # Window callbacks"""


RPC_ADD_OLD = """                        case "/games/add":
                            urls = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                            if matches := utils.extract_thread_matches("\\n".join(urls)):
                                if not globals.settings.ext_background_add:
                                    globals.gui.show()
                                async def _add_game():
                                    await asyncio.sleep(0.1)
                                    await callbacks.add_games(*matches)
                                async_thread.run(_add_game())"""

RPC_ADD_NEW = """                        case "/games/add":
                            urls = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                            from modules import lc_games
                            lc_urls = [u for u in urls if lc_games.is_lc_url(u)]
                            other_urls = [u for u in urls if not lc_games.is_lc_url(u)]
                            matches = utils.extract_thread_matches("\\n".join(other_urls))
                            if matches or lc_urls:
                                if not globals.settings.ext_background_add:
                                    globals.gui.show()
                                async def _add_game():
                                    await asyncio.sleep(0.1)
                                    if matches:
                                        await callbacks.add_games(*matches)
                                    if lc_urls:
                                        await lc_games.add_lc_games(lc_urls)
                                async_thread.run(_add_game())"""

CHROME_MANIFEST_OLD = """    "web_accessible_resources": [
        {
            "resources": [
                "fonts/mdi-webfont.ttf"
            ],
            "matches": [
                "https://f95zone.to/*"
            ],
            "use_dynamic_url": true
        }
    ],
    "host_permissions": [
        "*://*.f95zone.to/*"
    ]"""

CHROME_MANIFEST_NEW = """    "web_accessible_resources": [
        {
            "resources": [
                "fonts/mdi-webfont.ttf"
            ],
            "matches": [
                "https://f95zone.to/*",
                "https://lewdcorner.com/*"
            ],
            "use_dynamic_url": true
        }
    ],
    "host_permissions": [
        "*://*.f95zone.to/*",
        "*://*.lewdcorner.com/*"
    ]"""

FIREFOX_MANIFEST_OLD = """    "permissions": [
        "scripting",
        "activeTab",
        "contextMenus",
        "webNavigation",
        "*://*.f95zone.to/*"
    ]"""

FIREFOX_MANIFEST_NEW = """    "permissions": [
        "scripting",
        "activeTab",
        "contextMenus",
        "webNavigation",
        "*://*.f95zone.to/*",
        "*://*.lewdcorner.com/*"
    ]"""

EXT_NAV_OLD = "    { url: [{ hostSuffix: 'f95zone.to' }] }"
EXT_NAV_NEW = "    { url: [{ hostSuffix: 'f95zone.to' }, { hostSuffix: 'lewdcorner.com' }] }"

EXT_MENU_OLD = """    documentUrlPatterns: ['*://*.f95zone.to/threads/*'],
});
chrome.contextMenus.create({
    id: `add-link-to-f95checker`,
    title: `Add this link to F95Checker`,
    contexts: ['link'],
    targetUrlPatterns: ['*://*.f95zone.to/threads/*'],
});"""

EXT_MENU_NEW = """    documentUrlPatterns: ['*://*.f95zone.to/threads/*', '*://*.lewdcorner.com/threads/*'],
});
chrome.contextMenus.create({
    id: `add-link-to-f95checker`,
    title: `Add this link to F95Checker`,
    contexts: ['link'],
    targetUrlPatterns: ['*://*.f95zone.to/threads/*', '*://*.lewdcorner.com/threads/*'],
});"""

GUI_ADD_BOX_OLD = "                async_thread.run(callbacks.add_games(*utils.extract_thread_matches(self.add_box_text)))"

GUI_ADD_BOX_NEW = """                from modules import lc_games
                lc_urls, other_text = lc_games.split_add_box_text(self.add_box_text)
                matches = utils.extract_thread_matches(other_text)
                if matches:
                    async_thread.run(callbacks.add_games(*matches))
                if lc_urls:
                    async_thread.run(lc_games.add_lc_games(lc_urls))"""

GUI_LC_IMPORT_OLD = """    france_labels,
    globals,"""

GUI_LC_IMPORT_NEW = """    france_labels,
    globals,
    lc_games,"""

GUI_LC_SECTION_ANCHOR = """        if draw_settings_section("Manage"):"""

GUI_LC_SECTION_NEW = '''
        if draw_settings_section("LewdCorner"):
            draw_settings_label(
                "Connexion LewdCorner",
                "Necessaire pour scraper les threads prives/reserves aux membres.\\n"
                "Sans connexion, seuls les threads publics seront correctement suivis."
            )
            imgui.table_next_row()
            imgui.table_next_column()
            imgui.table_next_column()
            if imgui.button(("Se reconnecter" if lc_games.is_lc_logged_in() else "Se connecter"), width=right_width):
                async_thread.run(lc_games.lc_login())
            imgui.text("")
            imgui.spacing()
            imgui.end_table()

''' + GUI_LC_SECTION_ANCHOR

GUI_RECHECK_OLD = """    def draw_game_recheck_button(self, game: Game, label="", selectable=False):
        if game and game.custom:
            imgui.push_disabled()
        if selectable:
            clicked = imgui.selectable(label, False)[0]
        else:
            clicked = imgui.button(label)
        if clicked:
            games = [game] if game else list(filter(lambda g: g.selected, globals.games.values()))
            for g in games:
                g.add_timeline_event(TimelineEventType.RecheckUserReq)
            utils.start_refresh_task(api.refresh(*games, full=True, notifs=False))
        if game and game.custom:
            imgui.pop_disabled()"""

GUI_RECHECK_NEW = """    def draw_game_recheck_button(self, game: Game, label="", selectable=False):
        disable_recheck = game and game.custom and not lc_games.is_lc_url(game.url)
        if disable_recheck:
            imgui.push_disabled()
        if selectable:
            clicked = imgui.selectable(label, False)[0]
        else:
            clicked = imgui.button(label)
        if clicked:
            games = [game] if game else list(filter(lambda g: g.selected, globals.games.values()))
            for g in games:
                g.add_timeline_event(TimelineEventType.RecheckUserReq)
            utils.start_refresh_task(api.refresh(*games, full=True, notifs=False))
        if disable_recheck:
            imgui.pop_disabled()"""

GLOBALS_STARTCMD_OLD = """    if os is Os.Windows:
        import winreg
        start_cmd = " ".join(f'"{split}"' for split in start_cmd)
        autostart = pathlib.Path("SOFTWARE\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run\\\\F95Checker")"""

GLOBALS_STARTCMD_NEW = """    if os is Os.Windows:
        import winreg
        _france_root = pathlib.Path(__file__).resolve().parents[2]
        _france_bat = _france_root / "F95Checker-France.bat"
        _france_vbs = _france_root / "._f95_france_cache" / "silent_launch.vbs"
        if _france_bat.is_file() and _france_vbs.is_file():
            start_cmd = f'wscript.exe //B "{_france_vbs}" "{_france_bat}"'
        else:
            start_cmd = " ".join(f'"{split}"' for split in start_cmd)
        autostart = pathlib.Path("SOFTWARE\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run\\\\F95Checker")"""

CALLBACKS_FUZZY_OLD = """def _fuzzy_match_subdir(where: pathlib.Path, match: str, best_partial_match: bool):
    clean_dir = utils.clean_str(match)
    if (where / clean_dir).is_dir():
        where /= clean_dir
    else:
        try:
            dirs = [node.name for node in where.iterdir() if node.is_dir()]
            clean_dir_lower = clean_dir.lower()
            if best_partial_match:
                match_dirs = [d for d in dirs if clean_dir_lower in d.lower()]
            else:
                match_dirs = []
            if len(match_dirs) == 1:
                where /= match_dirs[0]
            else:
                ratio = lambda a, b: difflib.SequenceMatcher(None, a.lower(), b.lower()).quick_ratio()
                similarity = {d: ratio(d, match) for d in dirs}
                best_match = max(similarity.keys())
                if similarity[best_match] > 0.85:
                    where /= best_match
        except Exception:
            pass
    return where"""

CALLBACKS_FUZZY_NEW = """def _fuzzy_match_subdir(where: pathlib.Path, match: str, best_partial_match: bool) -> tuple[pathlib.Path, bool]:
    if not match:
        return where, False
    clean_dir = utils.clean_str(match)
    if (where / clean_dir).is_dir():
        return where / clean_dir, True
    try:
        dirs = [node.name for node in where.iterdir() if node.is_dir()]
    except Exception:
        return where, False
    clean_dir_lower = clean_dir.lower()
    if best_partial_match:
        match_dirs = [
            d for d in dirs
            if clean_dir_lower in d.lower() or (len(d) >= 4 and d.lower() in clean_dir_lower)
        ]
        if len(match_dirs) == 1:
            return where / match_dirs[0], True
        if not match_dirs:
            # Repli : compare sans espaces/tirets/points (ex: "crimesofslaves-0.3-pc")
            compact_target = re.sub(r"[^a-z0-9]", "", clean_dir_lower)
            if compact_target:
                compact_map = {d: re.sub(r"[^a-z0-9]", "", d.lower()) for d in dirs}
                compact_dirs = [
                    d for d, compact_d in compact_map.items()
                    if compact_d and (
                        compact_target in compact_d or
                        (len(compact_d) >= 4 and compact_d in compact_target)
                    )
                ]
                if len(compact_dirs) == 1:
                    return where / compact_dirs[0], True
    if not dirs:
        return where, False
    ratio = lambda a, b: difflib.SequenceMatcher(None, a.lower(), b.lower()).quick_ratio()
    similarity = {d: ratio(d, match) for d in dirs}
    best_match = max(similarity, key=similarity.get)
    if similarity[best_match] > 0.85:
        return where / best_match, True
    return where, False


def _find_game_dir(start_dir: pathlib.Path, game: Game) -> pathlib.Path:
    \"\"\"Cherche le dossier du jeu en essayant plusieurs structures de rangement
    possibles (a plat, par developpeur, par type de moteur), plutot que de
    supposer une seule arborescence rigide. Garde le meilleur essai partiel
    si aucune chaine ne trouve le dossier final du jeu.\"\"\"
    names = [game.name]
    if game.name.lower().endswith(" collection"):
        names.append(game.name[:-len(" collection")])

    chains: list[list[tuple[str, bool]]] = []
    for name in names:
        chains.append([(name, True)])
        if game.developer:
            chains.append([(game.developer, False), (name, True)])
        chains.append([(game.type.name, False), (name, True)])
        if game.developer:
            chains.append([(game.type.name, False), (game.developer, False), (name, True)])

    best_dir = start_dir
    best_depth = -1
    for chain in chains:
        where = start_dir
        depth = 0
        matched_final = False
        for i, (subdir, best_partial_match) in enumerate(chain):
            where, found = _fuzzy_match_subdir(where, subdir, best_partial_match)
            if not found:
                break
            depth += 1
            if i == len(chain) - 1:
                matched_final = True
        if matched_final:
            return where
        if depth > best_depth:
            best_depth = depth
            best_dir = where
    return best_dir"""

CALLBACKS_STARTDIR_OLD = """    start_dir = globals.settings.default_exe_dir.get(globals.os)
    if start_dir:
        start_dir = pathlib.Path(start_dir)
        try_subdirs = [(game.type.name, False), (game.developer, False), (game.name, True)]
        if game.name.lower().endswith(" collection"):
            try_subdirs.append((game.name[:-len(" collection")], True))
        for subdir, best_partial_match in try_subdirs:
            start_dir = _fuzzy_match_subdir(start_dir, subdir, best_partial_match)"""

CALLBACKS_STARTDIR_NEW = """    start_dir = globals.settings.default_exe_dir.get(globals.os)
    if start_dir:
        start_dir = _find_game_dir(pathlib.Path(start_dir), game)"""


API_REFRESH_OLD = """async def refresh(*games: list[Game], full=False, notifs=True, force_archived=False, force_completed=False):
    fast_queue: list[list[Game]] = [[]]
    for game in (games or globals.games.values()):
        if game.custom:
            continue
        if not games:
            if game.archived and not globals.settings.refresh_archived_games and not force_archived:
                continue
            if not game.image.missing:
                if game.status is Status.Completed and not globals.settings.refresh_completed_games and not force_completed:
                    continue
        if len(fast_queue[-1]) == api_fast_check_max_ids:
            fast_queue.append([])
        fast_queue[-1].append(game)

    notifs = notifs and globals.settings.check_notifs
    globals.refresh_progress += 1
    globals.refresh_total += sum(len(chunk) for chunk in fast_queue) + bool(notifs)

    global fast_checks_sem, full_checks_sem, fast_checks_counter
    fast_checks_sem = asyncio.Semaphore(1)
    full_checks_sem = asyncio.Semaphore(globals.settings.max_connections)
    fast_checks_counter = 0
    tasks: list[asyncio.Task] = []
    try:
        tasks = [asyncio.create_task(fast_check(chunk, full=full)) for chunk in fast_queue]
        await asyncio.gather(*tasks)
    except Exception:
        for task in tasks:
            task.cancel()
        fast_checks_sem = None
        full_checks_sem = None
        fast_checks_counter = 0
        raise
    fast_checks_sem = None
    full_checks_sem = None
    fast_checks_counter = 0

    if notifs:
        await check_notifs(standalone=False)

    if not games:
        globals.settings.last_successful_refresh.update(time.time())
        await db.update_settings("last_successful_refresh")"""

API_REFRESH_NEW = """async def refresh(*games: list[Game], full=False, notifs=True, force_archived=False, force_completed=False):
    from modules import lc_games
    fast_queue: list[list[Game]] = [[]]
    lc_queue: list[Game] = []
    for game in (games or globals.games.values()):
        if game.custom:
            if lc_games.is_lc_url(game.url):
                if not games:
                    if game.archived and not globals.settings.refresh_archived_games and not force_archived:
                        continue
                    if not game.image.missing:
                        if game.status is Status.Completed and not globals.settings.refresh_completed_games and not force_completed:
                            continue
                lc_queue.append(game)
            continue
        if not games:
            if game.archived and not globals.settings.refresh_archived_games and not force_archived:
                continue
            if not game.image.missing:
                if game.status is Status.Completed and not globals.settings.refresh_completed_games and not force_completed:
                    continue
        if len(fast_queue[-1]) == api_fast_check_max_ids:
            fast_queue.append([])
        fast_queue[-1].append(game)

    notifs = notifs and globals.settings.check_notifs
    globals.refresh_progress += 1
    globals.refresh_total += sum(len(chunk) for chunk in fast_queue) + bool(notifs) + len(lc_queue)

    global fast_checks_sem, full_checks_sem, fast_checks_counter
    fast_checks_sem = asyncio.Semaphore(1)
    full_checks_sem = asyncio.Semaphore(globals.settings.max_connections)
    fast_checks_counter = 0
    tasks: list[asyncio.Task] = []
    try:
        tasks = [asyncio.create_task(fast_check(chunk, full=full)) for chunk in fast_queue]
        tasks += [asyncio.create_task(lc_games.refresh_lc_game(game)) for game in lc_queue]
        await asyncio.gather(*tasks)
    except Exception:
        for task in tasks:
            task.cancel()
        fast_checks_sem = None
        full_checks_sem = None
        fast_checks_counter = 0
        raise
    fast_checks_sem = None
    full_checks_sem = None
    fast_checks_counter = 0

    if notifs:
        await check_notifs(standalone=False)

    if not games:
        globals.settings.last_successful_refresh.update(time.time())
        await db.update_settings("last_successful_refresh")"""


WINE_DISCOVER_OLD = """def discover():
    found: dict[str, pathlib.Path] = {}
    if system_wine := shutil.which("wine"):
        found["System Wine"] = pathlib.Path(system_wine)
    if system_proton_ge := shutil.which("proton-ge"):
        found["System Proton-GE"] = pathlib.Path(system_proton_ge)"""

WINE_DISCOVER_NEW = """def discover():
    found: dict[str, pathlib.Path] = {}
    if system_wine := shutil.which("wine"):
        found["System Wine"] = pathlib.Path(system_wine)
    if system_proton_ge := shutil.which("proton-ge"):
        found["System Proton-GE"] = pathlib.Path(system_proton_ge)
    if system_umu := shutil.which("umu-run"):
        found["umu-launcher"] = pathlib.Path(system_umu)"""

WINE_BUILD_WRAPPER_OLD = """    elif runner.name in ("proton", "proton-ge"):
        steam_root = pathlib.Path.home() / ".steam/root"
        return shlex.join([
            "env",
            f"WINEPREFIX={prefix}",
            f"STEAM_COMPAT_DATA_PATH={prefix}",
            f"STEAM_COMPAT_CLIENT_INSTALL_PATH={steam_root}",
            str(runner),
            "run",
            "%command%"
        ])
    else:
        return "%command%\""""

WINE_BUILD_WRAPPER_NEW = """    elif runner.name in ("proton", "proton-ge"):
        steam_root = pathlib.Path.home() / ".steam/root"
        return shlex.join([
            "env",
            f"WINEPREFIX={prefix}",
            f"STEAM_COMPAT_DATA_PATH={prefix}",
            f"STEAM_COMPAT_CLIENT_INSTALL_PATH={steam_root}",
            str(runner),
            "run",
            "%command%"
        ])
    elif runner.name == "umu-run":
        return shlex.join([
            "env",
            f"WINEPREFIX={prefix}",
            "GAMEID=umu-default",
            str(runner),
            "%command%",
        ])
    else:
        return "%command%\""""


def _patch_text(path: Path, old: str, new: str, marker: str, label: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if marker in text:
        return False
    if old not in text:
        print(f"ATTENTION : {path.name} a change, patch {label} impossible.")
        return False
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    return True


def _rezip(folder: Path, zip_path: Path) -> None:
    import zipfile
    if not folder.is_dir():
        return
    if zip_path.is_file():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(folder.rglob("*")):
            if file.is_file():
                zf.write(file, file.relative_to(folder))


def apply_lc_patches() -> None:
    lc_module = SRC / "modules" / "lc_games.py"
    shutil.copy2(PATCH_DIR / "lc_games.py", lc_module)
    print("Module lc_games.py installe.")

    rpc = SRC / "modules" / "rpc_thread.py"
    rpc_text = rpc.read_text(encoding="utf-8")
    if "lc_games" not in rpc_text:
        if RPC_ADD_OLD not in rpc_text:
            raise SystemExit("rpc_thread.py a change : patch LewdCorner impossible.")
        rpc.write_text(rpc_text.replace(RPC_ADD_OLD, RPC_ADD_NEW, 1), encoding="utf-8")
        print("Route /games/add compatible LewdCorner (rpc_thread.py).")

    browser = SRC / "browser"
    changed = False
    changed |= _patch_text(browser / "chrome" / "manifest.json", CHROME_MANIFEST_OLD, CHROME_MANIFEST_NEW, "lewdcorner.com", "manifest Chrome")
    changed |= _patch_text(browser / "firefox" / "manifest.json", FIREFOX_MANIFEST_OLD, FIREFOX_MANIFEST_NEW, "lewdcorner.com", "manifest Firefox")
    for folder in ("chrome", "firefox"):
        ext = browser / folder / "extension.js"
        changed |= _patch_text(ext, EXT_NAV_OLD, EXT_NAV_NEW, "lewdcorner.com'", f"navigation {folder}")
        changed |= _patch_text(ext, EXT_MENU_OLD, EXT_MENU_NEW, "lewdcorner.com/threads", f"menu {folder}")

    gui = SRC / "modules" / "gui.py"
    gui_text = gui.read_text(encoding="utf-8")
    if "lc_games" not in gui_text:
        if GUI_ADD_BOX_OLD not in gui_text:
            raise SystemExit("gui.py a change : patch barre d'ajout LewdCorner impossible.")
        if GUI_LC_IMPORT_OLD not in gui_text:
            raise SystemExit("gui.py a change : import lc_games impossible.")
        if GUI_LC_SECTION_ANCHOR not in gui_text:
            raise SystemExit("gui.py a change : section LewdCorner impossible.")
        if GUI_RECHECK_OLD not in gui_text:
            raise SystemExit("gui.py a change : patch bouton Recheck impossible.")
        gui_text = gui_text.replace(GUI_ADD_BOX_OLD, GUI_ADD_BOX_NEW, 1)
        gui_text = gui_text.replace(GUI_LC_IMPORT_OLD, GUI_LC_IMPORT_NEW, 1)
        gui_text = gui_text.replace(GUI_LC_SECTION_ANCHOR, GUI_LC_SECTION_NEW, 1)
        gui_text = gui_text.replace(GUI_RECHECK_OLD, GUI_RECHECK_NEW, 1)
        gui.write_text(gui_text, encoding="utf-8")
        verify_gui()
        print("Barre d'ajout, import, section Connexion et bouton Recheck LewdCorner ajoutes (gui.py).")

    api_module = SRC / "modules" / "api.py"
    api_text = api_module.read_text(encoding="utf-8")
    if "lc_games" not in api_text:
        if API_REFRESH_OLD not in api_text:
            raise SystemExit("api.py a change : patch refresh() LewdCorner impossible.")
        api_module.write_text(api_text.replace(API_REFRESH_OLD, API_REFRESH_NEW, 1), encoding="utf-8")
        import py_compile
        py_compile.compile(str(api_module), doraise=True)
        print("Suivi des mises a jour LewdCorner branche sur refresh() (api.py).")

    globals_module = SRC / "modules" / "globals.py"
    globals_text = globals_module.read_text(encoding="utf-8")
    if "_france_bat" not in globals_text:
        if GLOBALS_STARTCMD_OLD not in globals_text:
            raise SystemExit("globals.py a change : patch Start with System impossible.")
        globals_module.write_text(globals_text.replace(GLOBALS_STARTCMD_OLD, GLOBALS_STARTCMD_NEW, 1), encoding="utf-8")
        import py_compile
        py_compile.compile(str(globals_module), doraise=True)
        print("Start with System redirige via le .bat (globals.py).")

    callbacks_module = SRC / "modules" / "callbacks.py"
    callbacks_text = callbacks_module.read_text(encoding="utf-8")
    if "_find_game_dir" not in callbacks_text:
        if CALLBACKS_FUZZY_OLD not in callbacks_text:
            raise SystemExit("callbacks.py a change : patch detection dossier exe impossible.")
        if CALLBACKS_STARTDIR_OLD not in callbacks_text:
            raise SystemExit("callbacks.py a change : patch start_dir exe impossible.")
        callbacks_text = callbacks_text.replace(CALLBACKS_FUZZY_OLD, CALLBACKS_FUZZY_NEW, 1)
        callbacks_text = callbacks_text.replace(CALLBACKS_STARTDIR_OLD, CALLBACKS_STARTDIR_NEW, 1)
        callbacks_module.write_text(callbacks_text, encoding="utf-8")
        import py_compile
        py_compile.compile(str(callbacks_module), doraise=True)
        print("Detection du dossier d'executable amelioree (callbacks.py).")

    if changed:
        _rezip(browser / "chrome", browser / "chrome.zip")
        _rezip(browser / "firefox", browser / "firefox.zip")
        print("Extensions navigateur (chrome.zip / firefox.zip) mises a jour pour LewdCorner.")


def apply_patches() -> None:
    shutil.copy2(PATCH_DIR / "france_labels.py", SRC / "modules" / "france_labels.py")
    print("Module france_labels.py installe.")
    if (PATCH_DIR / "france_icon.py").is_file():
        shutil.copy2(PATCH_DIR / "france_icon.py", SRC / "modules" / "france_icon.py")
        print("Module france_icon.py installe.")
    main = SRC / "main.py"
    main_text = main.read_text(encoding="utf-8")
    if "france_icon.apply_process_branding" not in main_text:
        if MAIN_ICON_OLD not in main_text:
            raise SystemExit("main.py a change : patch icone impossible.")
        main.write_text(main_text.replace(MAIN_ICON_OLD, MAIN_ICON_NEW, 1), encoding="utf-8")
        print("Icone processus F95Checker (main.py).")
    gui = SRC / "modules" / "gui.py"
    text = gui.read_text(encoding="utf-8")
    text = repair_gui(text)
    if 'draw_settings_section("F95 France")' not in text:
        if GUI_ANCHOR not in text:
            raise SystemExit("gui.py a change : mise a jour F95Checker non compatible.")
        text = text.replace(GUI_ANCHOR, GUI_ANCHOR_REPLACEMENT, 1)
        print("Bouton F95-France ajoute dans la sidebar.")
    if "france_labels," not in text:
        if GUI_IMPORT_OLD not in text:
            raise SystemExit("Import france_labels impossible dans gui.py.")
        text = text.replace(GUI_IMPORT_OLD, GUI_IMPORT_NEW, 1)
    if "france_icon.apply_glfw_window_icon" not in text:
        if GUI_ICON_OLD not in text:
            raise SystemExit("gui.py a change : patch icone fenetre impossible.")
        text = text.replace(GUI_ICON_OLD, GUI_ICON_NEW, 1)
        print("Icone fenetre F95Checker (gui.py).")
    gui.write_text(text, encoding="utf-8")
    verify_gui()
    structs = SRC / "common" / "structs.py"
    structs_text = structs.read_text(encoding="utf-8")
    if '"Godot"' not in structs_text:
        if STRUCTS_GODOT_ANCHOR not in structs_text:
            print("ATTENTION : structs.py a change, patch Godot (type 31) impossible.")
        else:
            structs_text = structs_text.replace(STRUCTS_GODOT_ANCHOR, STRUCTS_GODOT_PATCHED, 1)
            structs.write_text(structs_text, encoding="utf-8")
            print("Type Godot (31) ajoute dans structs.py.")
    wine_module = SRC / "modules" / "wine.py"
    wine_text = wine_module.read_text(encoding="utf-8")
    if "umu-launcher" not in wine_text:
        if WINE_DISCOVER_OLD not in wine_text:
            raise SystemExit("wine.py a change : patch detection umu-launcher impossible.")
        if WINE_BUILD_WRAPPER_OLD not in wine_text:
            raise SystemExit("wine.py a change : patch wrapper umu-launcher impossible.")
        wine_text = wine_text.replace(WINE_DISCOVER_OLD, WINE_DISCOVER_NEW, 1)
        wine_text = wine_text.replace(WINE_BUILD_WRAPPER_OLD, WINE_BUILD_WRAPPER_NEW, 1)
        wine_module.write_text(wine_text, encoding="utf-8")
        import py_compile
        py_compile.compile(str(wine_module), doraise=True)
        print("Support umu-launcher ajoute (wine.py).")
    apply_lc_patches()


def migrate_ini() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    old = ROOT / "france_labels.ini"
    if old.is_file() and not INI.is_file():
        shutil.move(str(old), str(INI))
        print(f"Ancienne config deplacee vers {INI}")


def write_ini(api_key: str) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cfg = configparser.ConfigParser()
    cfg["france"] = {
        "api_key": api_key.strip(),
        "auth_mode": "bearer",
        "api_url": "https://f95france.site/api/games",
        "ignore_ids": "71058",
    }
    with INI.open("w", encoding="utf-8") as f:
        cfg.write(f)
    print(f"Config : {INI}")


def read_api_key() -> str:
    if not INI.is_file():
        return ""
    cfg = configparser.ConfigParser()
    cfg.read(INI, encoding="utf-8")
    return cfg.get("france", "api_key", fallback="").strip()


def test_api_key(api_key: str) -> int:
    sys.path.insert(0, str(SRC))
    from modules.france_labels import fetch_france_catalog
    ids_f95z, ids_lc = fetch_france_catalog(api_key)
    print(f"Cle OK : {len(ids_f95z)} F95z, {len(ids_lc)} LC ({len(ids_f95z) + len(ids_lc)} traduits).")
    return len(ids_f95z)


def prompt_api_key() -> str:
    print()
    print("Cle API : https://f95france.site (format f95ext_...)")
    print()
    while True:
        key = input("Collez votre cle API : ").strip()
        if not key:
            continue
        try:
            ensure_src()
            apply_patches()
            test_api_key(key)
        except Exception as exc:
            print(f"Echec : {exc}")
            if input("Reessayer ? (O/n) : ").strip().lower() in ("n", "non", "no"):
                raise SystemExit(1) from exc
            continue
        return key


def ensure_config(force: bool = False) -> None:
    migrate_ini()
    key = read_api_key()
    if key and not force:
        ensure_src()
        try:
            test_api_key(key)
            return
        except Exception as exc:
            print(f"Cle invalide : {exc}")
    write_ini(prompt_api_key())


def ensure_deps(py_cmd: list[str]) -> None:
    marker = SRC / ".deps_ok"
    if marker.is_file():
        return
    print("Dependances (une fois, patientez)...")
    subprocess.run(
        [*py_cmd, "-m", "pip", "install", "-q", "-U", "-r", "requirements.txt"],
        check=True,
        cwd=SRC,
    )
    marker.write_text("ok", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reconfigure", action="store_true")
    parser.add_argument("--setup-only", action="store_true")
    args = parser.parse_args()
    py_cmd = find_python()
    if not py_cmd:
        print("Python 3.11+ introuvable.")
        return 1
    ensure_src()
    auto_update_upstream()
    apply_patches()
    ensure_config(force=args.reconfigure)
    if args.setup_only or args.reconfigure:
        return 0
    ensure_deps(py_cmd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
@@END_SETUP_FRANCE@@
@@BEGIN_FRANCE_LABELS@@
"""Synchronisation labels traduits via API F95-France."""

from __future__ import annotations

import asyncio
import configparser
import json
import sqlite3
import sys
import urllib.error
import urllib.request
from pathlib import Path

from common.structs import Label

API_URL = "https://f95france.site/api/games"
LC_HOST_MARKER = "lewdcorner.com"
FRANCE_LABEL_NAME = "F95France"
FRANCE_LABEL_COLOR_HEX = "#4CAF50"
DEFAULT_IGNORE_IDS = (71058,)
_HTTP_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/131.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json",
}

_busy = False
_last_result = ""


def _appdata_dir() -> Path:
    home = Path.home()
    if sys.platform.startswith("win"):
        return home / "AppData" / "Roaming" / "f95checker"
    if sys.platform.startswith("linux"):
        return home / ".config" / "f95checker"
    if sys.platform.startswith("darwin"):
        return home / "Library" / "Application Support" / "f95checker"
    raise ValueError("Systeme non supporte.")


def _config_paths() -> list[Path]:
    root = Path(__file__).resolve().parents[2]
    return [root / "._f95_france_cache" / "france_labels.ini"]


def load_config() -> configparser.ConfigParser:
    cfg = configparser.ConfigParser()
    cfg.read_dict({
        "france": {
            "api_key": "",
            "auth_mode": "bearer",
            "api_url": API_URL,
            "ignore_ids": ",".join(str(i) for i in DEFAULT_IGNORE_IDS),
        }
    })
    for path in _config_paths():
        if path.is_file():
            cfg.read(path, encoding="utf-8")
            break
    return cfg


def _parse_ignore_ids(raw: str) -> set[int]:
    return {int(p.strip()) for p in (raw or "").split(",") if p.strip()}


def _api_error_message(status: int, body: bytes) -> str:
    text = body.decode("utf-8", errors="replace").strip()
    if b"1010" in body or "error code: 1010" in text:
        return "Cloudflare bloque la requete (1010)."
    try:
        payload = json.loads(text)
        if isinstance(payload, dict) and (err := payload.get("error")):
            return str(err)
    except json.JSONDecodeError:
        pass
    if status == 401:
        return "Cle API invalide. Generez-en une sur f95france.site."
    return f"Erreur HTTP {status}"


def _request_headers(api_key: str, auth_mode: str) -> dict[str, str]:
    headers = dict(_HTTP_HEADERS)
    key = api_key.strip()
    mode = (auth_mode or "bearer").strip().lower()
    if mode in ("x-api-key", "x_api_key", "apikey"):
        headers["X-Api-Key"] = key
    else:
        headers["Authorization"] = f"Bearer {key}"
    return headers


def _resolve_api_url(cfg: configparser.ConfigParser) -> str:
    raw = cfg["france"].get("api_url", API_URL).strip() or API_URL
    return raw.split("?", 1)[0]


def fetch_france_catalog(
    api_key: str, auth_mode: str = "bearer"
) -> tuple[set[int], set[int]]:
    """Une requete API ; repartition par champ website (f95z / lc)."""
    if not api_key.strip():
        raise ValueError("Cle API manquante dans france_labels.ini.")
    cfg = load_config()
    url = _resolve_api_url(cfg)
    auth_mode = cfg["france"].get("auth_mode", auth_mode)
    req = urllib.request.Request(url, headers=_request_headers(api_key, auth_mode))
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ValueError(_api_error_message(exc.code, exc.read())) from exc
    except urllib.error.URLError as exc:
        raise ValueError(f"Reseau : {exc.reason}") from exc
    if not isinstance(data, list):
        raise ValueError("Reponse API inattendue.")
    f95z_ids: set[int] = set()
    lc_ids: set[int] = set()
    for g in data:
        if not isinstance(g, dict):
            continue
        thread_id = g.get("threadId")
        if not isinstance(thread_id, (int, float)):
            continue
        tid = int(thread_id)
        website = str(g.get("website") or "").lower()
        if website == "f95z":
            f95z_ids.add(tid)
        elif website == "lc":
            lc_ids.add(tid)
    return f95z_ids, lc_ids


def _is_lc_thread_url(url: str) -> bool:
    return bool(url) and LC_HOST_MARKER in url.lower()


def _thread_id_from_url(url: str) -> int | None:
    from modules import utils

    matches = utils.extract_thread_matches(url)
    return matches[0].id if matches else None


def _game_in_french_catalog(game, f95z_ids: set[int], lc_ids: set[int]) -> bool:
    if game.custom:
        if not _is_lc_thread_url(game.url):
            return False
        thread_id = _thread_id_from_url(game.url)
        return thread_id is not None and thread_id in lc_ids
    return game.id in f95z_ids


def _france_label_display_name() -> str:
    from modules import icons

    icon = getattr(icons, "translate", "")
    return f"{icon}{FRANCE_LABEL_NAME}" if icon else FRANCE_LABEL_NAME


def _france_label_color() -> tuple[float, float, float, float]:
    from modules import colors

    return colors.hex_to_rgba_0_1(FRANCE_LABEL_COLOR_HEX)


def _is_france_label(label: Label) -> bool:
    return (
        label.name == FRANCE_LABEL_NAME
        or label.name.endswith(FRANCE_LABEL_NAME)
        or label.name.endswith(f" {FRANCE_LABEL_NAME}")
    )


def _find_france_label() -> Label | None:
    for label in Label.instances:
        if _is_france_label(label):
            return label
    return None


def _rgb_close(a: tuple[float, ...], b: tuple[float, ...]) -> bool:
    return all(abs(x - y) < 0.02 for x, y in zip(a[:3], b[:3]))


async def _apply_france_label_style(label: Label) -> None:
    from modules import db

    display = _france_label_display_name()
    color = _france_label_color()
    updates: list[str] = []
    if label.name != display:
        label.name = display
        updates.append("name")
    if not _rgb_close(label.color, color):
        label.color = color
        updates.append("color")
    for key in updates:
        await db.update_label(label, key)


async def ensure_france_label() -> tuple[Label, bool]:
    from modules import db, globals

    label = _find_france_label()
    created = label is None
    if created:
        label = await db.create_label()
    await _apply_france_label_style(label)
    if globals.gui:
        globals.gui.recalculate_ids = True
    return label, created


def sync_in_memory(label: Label) -> tuple[int, int]:
    from modules import globals

    cfg = load_config()
    section = cfg["france"]
    api_key = section.get("api_key", "")
    f95z_ids, lc_ids = fetch_france_catalog(api_key)
    ignore_ids = _parse_ignore_ids(section.get("ignore_ids", ""))
    added = removed = 0
    for game in globals.games.values():
        if game.id in ignore_ids:
            continue
        if game.custom and not _is_lc_thread_url(game.url):
            continue
        if game.custom and _thread_id_from_url(game.url) is None:
            continue
        if _game_in_french_catalog(game, f95z_ids, lc_ids):
            if label not in game.labels:
                game.add_label(label)
                added += 1
        elif label in game.labels:
            game.remove_label(label)
            removed += 1
    if globals.gui:
        globals.gui.recalculate_ids = True
    return added, removed


def is_busy() -> bool:
    return _busy


def last_result() -> str:
    return _last_result


async def sync_from_gui() -> None:
    from common.structs import MsgBox
    from external import error
    from modules import msgbox, utils
    global _busy, _last_result
    if _busy:
        return
    _busy = True
    _last_result = "Synchronisation..."
    try:
        label, created = await ensure_france_label()
        loop = asyncio.get_event_loop()
        added, removed = await loop.run_in_executor(None, sync_in_memory, label)
        _last_result = f"Dernier sync : +{added} / -{removed}"
        msg = (
            f"Labels mis a jour : {added} ajout(s), {removed} retrait(s)."
            if added or removed
            else "Rien a mettre a jour."
        )
        if created:
            msg = f'Label « {FRANCE_LABEL_NAME} » cree.\n{msg}'
        utils.push_popup(msgbox.msgbox, "F95-France", msg, MsgBox.info)
    except ValueError as exc:
        _last_result = str(exc)
        utils.push_popup(msgbox.msgbox, "F95-France", str(exc), MsgBox.error)
    except Exception:
        _last_result = "Erreur"
        utils.push_popup(
            msgbox.msgbox, "F95-France", error.text(), MsgBox.error, more=error.traceback()
        )
    finally:
        _busy = False
@@END_FRANCE_LABELS@@
@@BEGIN_FRANCE_ICON@@
"""Icone F95Checker sous Windows (pythonw affiche sinon l'icone Python)."""

from __future__ import annotations

import sys
from pathlib import Path

APP_USER_MODEL_ID = "WillyJL.F95Checker"
ICON_REL = Path("resources/icons/icon.ico")


def _icon_path() -> Path | None:
    from modules import globals

    path = globals.self_path / ICON_REL
    return path if path.is_file() else None


def apply_process_branding() -> None:
    if sys.platform != "win32":
        return
    import ctypes

    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID)
    except Exception:
        pass


def apply_glfw_window_icon(window) -> None:
    if sys.platform != "win32":
        return
    icon = _icon_path()
    if not icon:
        return
    import glfw
    import win32con
    import win32gui

    hwnd = glfw.get_win32_window(window)
    if not hwnd:
        return
    big = win32gui.LoadImage(
        0,
        str(icon),
        win32con.IMAGE_ICON,
        0,
        0,
        win32con.LR_LOADFROMFILE | win32con.LR_DEFAULTSIZE,
    )
    small = win32gui.LoadImage(
        0,
        str(icon),
        win32con.IMAGE_ICON,
        16,
        16,
        win32con.LR_LOADFROMFILE,
    )
    if big:
        win32gui.SendMessage(hwnd, win32con.WM_SETICON, win32con.ICON_BIG, big)
    if small:
        win32gui.SendMessage(hwnd, win32con.WM_SETICON, win32con.ICON_SMALL, small)
@@END_FRANCE_ICON@@
@@BEGIN_LC_GAMES@@
"""Ajout et suivi de jeux LewdCorner (jeux custom) via l'extension navigateur F95Checker.

LewdCorner n'a pas d'indexeur centralise comme F95zone : chaque ajout et chaque
rafraichissement re-scrape en direct la page du thread avec le parseur HTML
generique de F95Checker (common/parser.py), qui cible la structure XenForo
standard (LewdCorner utilise aussi XenForo). C'est donc plus lent et plus
fragile qu'un vrai F95zone (une requete HTTP par jeu a chaque refresh, et ca
peut casser si LewdCorner change son theme), mais ca donne un vrai suivi de
version/statut/tags/image, avec les memes evenements de timeline que F95zone.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

LC_HOST_MARKER = "lewdcorner.com"
_THREAD_RE = re.compile(r"threads/(?:([^./]*)\.)?(\d+)")
_LC_URL_RE = re.compile(r"\S*lewdcorner\.com/threads/(?:[^./\s]*\.)?\d+\S*", re.IGNORECASE)


def is_lc_url(url: str) -> bool:
    return bool(url) and LC_HOST_MARKER in url.lower()


def _cookies_path() -> Path:
    root = Path(__file__).resolve().parents[2]
    return root / "._f95_france_cache" / "lc_cookies.json"


def _load_lc_cookies() -> dict[str, str]:
    path = _cookies_path()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_lc_cookies(cookies: dict[str, str]) -> None:
    path = _cookies_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cookies), encoding="utf-8")


def is_lc_logged_in() -> bool:
    return "xf_user" in _load_lc_cookies()


async def lc_login() -> bool:
    """Ouvre une mini-fenetre de connexion LewdCorner et capture les cookies de session.

    Suppose que LewdCorner utilise le cookie XenForo standard 'xf_user' pour la
    session (comme F95zone). Si ce n'est pas le cas, cette fonction attendra
    indefiniment que l'utilisateur ferme la fenetre.
    """
    from modules import webview

    new_cookies: dict[str, str] = {}
    try:
        with await webview.start(
            "cookies", f"https://{LC_HOST_MARKER}/login/",
            title="F95Checker: Connexion a LewdCorner",
            size=(500, 720),
            use_f95_cookies=False,
            pipe=True,
        ) as pipe:
            while True:
                key, value = await pipe.get_async()
                new_cookies[key] = value
                if "xf_user" in new_cookies:
                    break
    except Exception:
        return False
    if not new_cookies:
        return False
    _save_lc_cookies(new_cookies)
    return True


def split_add_box_text(text: str) -> tuple[list[str], str]:
    """Separe les liens LewdCorner du reste du texte colle dans la barre d'ajout."""
    lc_urls = _LC_URL_RE.findall(text or "")
    remainder = _LC_URL_RE.sub(" ", text or "")
    return lc_urls, remainder


def _thread_id(url: str) -> int | None:
    match = _THREAD_RE.search(url)
    return int(match.group(2)) if match else None


def _canonical_url(url: str, thread_id: int) -> str:
    match = _THREAD_RE.search(url)
    slug = match.group(1) if match else None
    path = f"threads/{slug}.{thread_id}/" if slug else f"threads/{thread_id}/"
    return f"https://{LC_HOST_MARKER}/{path}"


def _find_existing(thread_id: int):
    from modules import globals

    for game in globals.games.values():
        if game.custom and is_lc_url(game.url) and _thread_id(game.url) == thread_id:
            return game
    return None


_LC_BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    ),
}


async def _fetch_page(url: str) -> tuple[bytes | None, str | None]:
    """Recuperation asynchrone (ne bloque pas la boucle asyncio partagee). Renvoie (contenu, erreur).

    Envoie un User-Agent de navigateur : la session HTTP globale de F95Checker
    s'identifie comme 'F95Checker/x.y aiohttp/z' (sans souci pour F95zone, qui
    passe par le service d'indexation du developpeur plutot que par du scraping
    direct), ce que le pare-feu/anti-bot de LewdCorner bloque probablement pour
    du HTML brut. N'attache les cookies de session LewdCorner que si l'URL
    cible est bien lewdcorner.com, pour ne jamais les envoyer a un hote tiers.
    """
    from modules import api

    cookies = _load_lc_cookies() if is_lc_url(url) else False
    try:
        async with api.request("GET", url, cookies=cookies, timeout=30, headers=_LC_BROWSER_HEADERS) as (res, req):
            if req.status >= 400:
                return None, f"HTTP {req.status}"
            return res, None
    except Exception as exc:
        return None, (f"{type(exc).__name__}: {exc}" if str(exc) else type(exc).__name__)


_LC_ALIAS_TAGS = {
    "femdom": "femaledomination",
    "maledom": "maledomination",
    "netorare": "ntr",
    "futa": "futa-trans",
    "futa/trans": "futa-trans",
    "trans": "futa-trans",
    "point and click": "point-click",
}


def _match_lc_tag(name: str):
    from common.structs import Tag

    key = name.strip().lower()
    for tag in Tag:
        if tag.text.lower() == key:
            return tag
    slug = re.sub(r"[^a-z0-9]+", "-", key).strip("-")
    if slug in Tag._member_map_:
        return Tag[slug]
    alias = _LC_ALIAS_TAGS.get(key) or _LC_ALIAS_TAGS.get(slug)
    if alias and alias in Tag._member_map_:
        return Tag[alias]
    return None


_LC_PREFIX_TYPES = [
    ("Cheat Mod", "Cheat Mod"), ("Mod", "Mod"), ("Tool", "Tool"),
    ("READ ME", "README"), ("READ ME", "READ ME"), ("Request", "Request"), ("Tutorial", "Tutorial"),
    ("SiteRip", "SiteRip"), ("Collection", "Collection"), ("Manga", "Manga"),
    ("Comics", "Comics"), ("Video", "Video"), ("GIF", "GIF"), ("Pinup", "Pinup"),
    ("CG", "CG"), ("ADRIFT", "ADRIFT"), ("Flash", "Flash"), ("HTML", "HTML"),
    ("Java", "Java"), ("Others", "Others"), ("Other", "Others"), ("QSP", "QSP"), ("RAGS", "RAGS"),
    ("RPGM", "RPGM"), ("Ren'Py", "RenPy"), ("Tads", "Tads"), ("Unity", "Unity"),
    ("Unreal Engine", "Unreal Eng"), ("WebGL", "WebGL"), ("Wolf RPG", "Wolf RPG"),
]


def _detect_lc_type_status(head):
    from common.structs import Status, Type

    def has_prefix(text):
        return head.find("span", string=text) is not None

    type_ = Type.Misc
    for label, member in _LC_PREFIX_TYPES:
        if member in Type._member_map_ and has_prefix(label):
            type_ = Type[member]
            break

    if has_prefix("Completed") or has_prefix("Complete"):
        status = Status.Completed
    elif has_prefix("Onhold") or has_prefix("On Hold") or has_prefix("On-Hold"):
        status = Status.OnHold
    elif has_prefix("Abandoned") or has_prefix("Dropped"):
        status = Status.Abandoned
    else:
        status = Status.Normal
    return type_, status


def _parse_lc_date(text: str) -> int:
    import datetime as dt
    from common.parser import datestamp

    text = (text or "").strip()
    if not text:
        return 0
    try:
        parsed = dt.datetime.strptime(text, "%b %d, %Y")
    except ValueError:
        return 0
    return datestamp(parsed.replace(tzinfo=dt.timezone.utc).timestamp())


async def _parse_page(html: bytes, url: str = ""):
    """Parseur dedie LewdCorner.

    LewdCorner tourne sous XenForo comme F95zone mais sa mise en page differe
    trop pour reutiliser common/parser.py::thread() (pas de classe
    'message-threadStarterPost' sur le 1er post, infos dans des balises
    <dl data-field=...> plutot qu'en texte libre, dates au format texte).
    On s'appuie a la place sur le JSON-LD (schema.org) que LewdCorner integre
    sur chaque thread, plus fiable et stable qu'un parsing HTML fragile.
    """
    import json as _json
    from types import SimpleNamespace
    from common import parser as f95_parser

    soup = f95_parser.html(html)

    ld_thread = None
    ld_rating = None
    for tag in soup.find_all("script", type="application/ld+json"):
        try:
            data = _json.loads(tag.get_text())
        except Exception:
            continue
        if isinstance(data, dict):
            if isinstance(data.get("mainEntity"), dict) and ld_thread is None:
                ld_thread = data["mainEntity"]
            if data.get("@context") == "http://schema.org/" and "aggregateRating" in data and ld_rating is None:
                ld_rating = data["aggregateRating"]

    if ld_thread is None:
        return None, "Donnees structurees (JSON-LD) introuvables sur la page."

    headline = str(ld_thread.get("headline") or "").strip()
    if not headline:
        return None, "Titre introuvable dans les donnees de la page."

    head = soup.find(f95_parser.is_class("p-body-header"))
    post = soup.find(f95_parser.is_class("message-threadStarterPost")) or soup.find(f95_parser.is_class("message--post"))

    title_match = re.match(r"^(.*?)((?:\s*\[[^\[\]]*\])*)\s*$", headline)
    name = (title_match.group(1) if title_match else headline).strip()
    bracket_groups = re.findall(r"\[([^\[\]]*)\]", title_match.group(2)) if title_match else []

    version_from_title = ""
    developer_from_title = ""
    if bracket_groups:
        if re.match(r"^v[\d.]", bracket_groups[0], re.IGNORECASE):
            version_from_title = bracket_groups[0]
            if len(bracket_groups) > 1:
                developer_from_title = bracket_groups[-1]
        else:
            developer_from_title = bracket_groups[-1]

    def field(name_attr: str) -> str:
        el = soup.select_one(f'dl[data-field="{name_attr}"] dd')
        return el.get_text(strip=True) if el else ""

    version = field("version") or version_from_title or "N/A"
    developer = field("Developer") or developer_from_title
    last_updated = _parse_lc_date(field("dateversionrelease")) or _parse_lc_date(field("dategamerelease"))

    from common.structs import Status, Type
    type_, status = (Type.Misc, Status.Normal)
    if head is not None:
        type_, status = _detect_lc_type_status(head)

    tags = []
    unknown_tags = []
    keywords = str(ld_thread.get("keywords") or "")
    for raw in keywords.split(","):
        raw = raw.strip()
        if not raw:
            continue
        tag = _match_lc_tag(raw)
        if tag is not None:
            tags.append(tag)
        else:
            unknown_tags.append(raw)
    tags = tuple(sorted(set(tags), key=lambda t: t.name))

    score = 0.0
    votes = 0
    if ld_rating:
        try:
            score = float(ld_rating.get("ratingValue") or 0)
            votes = int(ld_rating.get("ratingCount") or 0)
        except Exception:
            pass

    description = str(ld_thread.get("text") or "")
    if "Overview:" in description:
        description = description.split("Overview:", 1)[1].lstrip("\n").lstrip()
    if "\nDOWNLOAD\n" in description:
        description = description.split("\nDOWNLOAD\n", 1)[0].rstrip()
    description = f95_parser.fixed_spaces(f95_parser.sanitize_whitespace(description)) if description else ""

    image_url = "missing"
    if post is not None:
        img = post.find(lambda elem: elem.name == "img" and "bbImage" in (elem.get("class") or []))
        if img:
            image_url = img.get("data-src") or img.get("src") or "missing"

    parsed = SimpleNamespace(
        name=name, thread_version=version, developer=developer, type=type_, status=status,
        last_updated=last_updated, score=score, votes=votes, description=description,
        changelog="", tags=tags, unknown_tags=tuple(unknown_tags), image_url=image_url,
        previews_urls=[], downloads=(),
    )
    return parsed, None


async def _scrape_and_apply(game) -> tuple[bool, str]:
    """Recupere + parse la page du thread LC et met a jour le jeu. Renvoie (succes, erreur)."""
    from common.structs import OldGame, Status, TimelineEventType
    from modules import globals

    html, fetch_err = await _fetch_page(game.url)
    if html is None:
        return False, f"Recuperation de la page impossible ({fetch_err})."
    parsed, parse_err = await _parse_page(html, game.url)
    if parsed is None:
        return False, (
            f"Page recuperee mais non reconnue ({parse_err}). "
            "Le thread necessite peut-etre une connexion (bouton Se connecter dans la "
            "sidebar LewdCorner), ou sa mise en page differe de celle attendue."
        )

    old_name = game.name
    old_version = game.version
    old_status = game.status
    version = parsed.thread_version or "N/A"

    if old_status is not Status.Unchecked:
        if game.tags != parsed.tags:
            if difference := [tag.text for tag in parsed.tags if tag not in game.tags]:
                game.add_timeline_event(TimelineEventType.TagsAdded, ", ".join(difference))
            if difference := [tag.text for tag in game.tags if tag not in parsed.tags]:
                game.add_timeline_event(TimelineEventType.TagsRemoved, ", ".join(difference))
        if game.score != parsed.score:
            if game.score < parsed.score:
                game.add_timeline_event(TimelineEventType.ScoreIncreased, game.score, game.votes, parsed.score, parsed.votes)
            else:
                game.add_timeline_event(TimelineEventType.ScoreDecreased, game.score, game.votes, parsed.score, parsed.votes)

    updated = game.updated
    if old_status is Status.Unchecked:
        old_version = version  # Premier scrape : pas de popup de mise a jour
    elif version != old_version and not game.archived:
        updated = True

    fetch_image = game.image.missing or (game.image_url != "custom" and parsed.image_url != game.image_url)
    image_bytes = None
    if fetch_image and parsed.image_url and parsed.image_url.startswith("http"):
        image_bytes, _ = await _fetch_page(parsed.image_url)

    game.name = parsed.name or old_name
    game.version = version
    game.developer = parsed.developer
    game.type = parsed.type
    game.status = parsed.status
    game.last_updated = parsed.last_updated
    game.score = parsed.score
    game.votes = parsed.votes
    game.updated = updated
    game.description = parsed.description
    game.changelog = parsed.changelog
    game.tags = parsed.tags
    game.unknown_tags = tuple(parsed.unknown_tags)
    if image_bytes:
        await game.set_image_async(image_bytes)
        game.image_url = parsed.image_url

    changed_name = game.name != old_name
    changed_status = parsed.status != old_status
    changed_version = version != old_version

    if old_status is not Status.Unchecked:
        if changed_name:
            game.add_timeline_event(TimelineEventType.ChangedName, old_name, game.name)
        if changed_status:
            game.add_timeline_event(TimelineEventType.ChangedStatus, old_status.name, game.status.name)
        if changed_version:
            game.add_timeline_event(TimelineEventType.ChangedVersion, old_version, game.version)

    if not game.archived and old_status is not Status.Unchecked and (changed_name or changed_status or changed_version):
        globals.new_updated_games[game.id] = OldGame(
            id=game.id,
            name=old_name,
            version=old_version,
            status=old_status,
        )

    return True, ""


async def refresh_lc_game(game) -> None:
    """Point d'entree appele depuis api.refresh() pour les jeux custom LewdCorner."""
    from common.structs import MsgBox
    from modules import globals, msgbox, utils

    try:
        success, error_msg = await _scrape_and_apply(game)
        if not success:
            utils.push_popup(
                msgbox.msgbox, "LewdCorner",
                f'Echec de la verification pour "{game.name}" :\n{error_msg}',
                MsgBox.warn,
            )
    except Exception:
        from external import error
        utils.push_popup(
            msgbox.msgbox, "LewdCorner",
            f'Erreur inattendue en verifiant "{game.name}".',
            MsgBox.error,
            more=error.traceback(),
        )
    finally:
        globals.refresh_progress += 1


async def add_lc_game(url: str) -> tuple[str, bool]:
    """Ajoute (ou retrouve) un jeu LewdCorner comme jeu custom. Renvoie (nom, cree)."""
    from modules import db, globals

    thread_id = _thread_id(url)
    if thread_id is None:
        raise ValueError(f"URL LewdCorner invalide : {url}")

    existing = _find_existing(thread_id)
    if existing is not None:
        return existing.name, False

    canonical = _canonical_url(url, thread_id)
    game_id = await db.create_game(custom=True)
    await db.load_games(game_id)
    game = globals.games[game_id]
    game.url = canonical
    success, _ = await _scrape_and_apply(game)
    if not success:
        game.name = f"LewdCorner ({thread_id})"
    if globals.settings.mark_installed_after_add:
        game.installed = game.version
    if globals.settings.select_executable_after_add:
        from modules import callbacks

        callbacks.add_game_exe(game)
    if globals.gui:
        globals.gui.recalculate_ids = True
    return game.name, True


async def add_lc_games(urls: list[str]) -> None:
    from common.structs import MsgBox
    from modules import msgbox, utils

    added: list[str] = []
    dupes: list[str] = []
    errors: list[str] = []
    for url in urls:
        try:
            name, created = await add_lc_game(url)
            (added if created else dupes).append(name)
        except Exception as exc:
            errors.append(str(exc))

    if not (added or dupes or errors):
        return

    lines = []
    if added:
        lines.append(f"{len(added)} jeu(x) LewdCorner ajoute(s) :\n - " + "\n - ".join(added))
    if dupes:
        lines.append(f"{len(dupes)} deja present(s) :\n - " + "\n - ".join(dupes))
    if errors:
        lines.append(f"{len(errors)} erreur(s) :\n - " + "\n - ".join(errors))

    utils.push_popup(
        msgbox.msgbox, "LewdCorner",
        "\n\n".join(lines),
        MsgBox.warn if errors else MsgBox.info,
    )
@@END_LC_GAMES@@
@@BEGIN_SILENT_LAUNCHER@@
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """" & WScript.Arguments(0) & """ --no-update", 0, False
@@END_SILENT_LAUNCHER@@
