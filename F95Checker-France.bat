@echo off
setlocal EnableExtensions
cd /d "%~dp0"

REM Mise a jour auto du launcher (.bat + .sh) depuis GitHub (laisser vide pour la desactiver) :
set "UPDATE_REPO_RAW=https://raw.githubusercontent.com/Hunteraulo1/f95list-f95checker/main"

if /i "%~1"=="--no-update" (
    shift
    set "UPDATE_REPO_RAW="
)
REM Demarrage avec Windows : on demande avant de mettre a jour le launcher.
REM La console est cachee : un "pause" bloquerait indefiniment sans que personne le voie.
set "PAUSE_CMD=pause"
if /i "%~1"=="--startup" (
    shift
    set "UPDATE_PROMPT=1"
    set "PAUSE_CMD=call"
)
REM Equivalent de F95Checker-Debug.exe : console ouverte et mode debug
if /i "%~1"=="debug" (
    shift
    set "DEBUG_MODE=1"
)
if defined UPDATE_REPO_RAW call :self_update
if errorlevel 1 exit /b 0

set "RUNTIME=%~dp0._f95_france_cache"
set "SRCDIR=%~dp0F95Checker-src"
set "PRIVATE_PY_DIR=%RUNTIME%\python312"
set "PRIVATE_PY=%PRIVATE_PY_DIR%\python.exe"
REM Dossier partage (dual boot) : Git le refuserait comme "dubious ownership"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=*"
set "EXTRA="
set "DO_LAUNCH=1"
if /i "%~1"=="reconfigure" set "EXTRA=--reconfigure" & set "DO_LAUNCH=0"
if /i "%~1"=="--reconfigure" set "EXTRA=--reconfigure" & set "DO_LAUNCH=0"
if /i "%~1"=="setup-only" set "EXTRA=--setup-only" & set "DO_LAUNCH=0"

REM Pas de "py -3" : il prend la version la plus recente (ex. 3.14), incompatible
set "PY="
for %%V in (3.12 3.11) do if not defined PY py -%%V --version >nul 2>&1 && set "PY=py -%%V"
if not defined PY python -c "import sys; sys.exit(sys.version_info[:2] not in ((3, 12), (3, 11)))" >nul 2>&1 && set "PY=python"
if not defined PY if exist "%PRIVATE_PY%" set PY="%PRIVATE_PY%"
if not defined PY call :install_python
if not defined PY (
    echo Installation automatique de Python impossible. Verifiez votre connexion et relancez.
    echo Vous pouvez aussi installer Python 3.12 via https://www.python.org/downloads/
    %PAUSE_CMD%
    exit /b 1
)

if not exist "%RUNTIME%" mkdir "%RUNTIME%"
call :extract_embedded || (
    echo Echec extraction des scripts integres.
    %PAUSE_CMD%
    exit /b 1
)

echo.
echo === F95Checker France ===
echo.

%PY% "%RUNTIME%\setup_france.py" %EXTRA%
if errorlevel 1 (
    %PAUSE_CMD%
    exit /b 1
)

if "%DO_LAUNCH%"=="0" exit /b 0

REM MinGit installe par setup_france.py : F95Checker en a besoin aussi (bouton Verifier, watermark)
if exist "%RUNTIME%\mingit\cmd\git.exe" set "PATH=%RUNTIME%\mingit\cmd;%PATH%"
REM "call" : sinon for /f retire les guillemets d'un chemin Python contenant des espaces
for /f "delims=" %%W in ('call %PY% -c "import sys, pathlib; p=pathlib.Path(sys.executable); w=p.with_name('pythonw.exe'); print(w if w.is_file() else p)"') do set "PYW=%%W"
if not exist "%SRCDIR%\main.py" (
    echo F95Checker-src manquant. Relancez le .bat avec Internet.
    %PAUSE_CMD%
    exit /b 1
)
%PY% -m py_compile "%SRCDIR%\modules\gui.py" 2>nul
if errorlevel 1 (
    echo gui.py invalide. Relancez le .bat pour reparer le patch.
    %PAUSE_CMD%
    exit /b 1
)
if defined DEBUG_MODE goto :launch_debug
echo.
echo Lancement de F95Checker...
start "" /D "%SRCDIR%" "%PYW%" main.py
echo F95Checker demarre (fenetre separee, sans console).
echo.
REM Fermer cette console si le .bat a ete ouvert par double-clic
echo %CMDCMDLINE% | findstr /I /C:"/c" >nul && exit
exit /b 0

:launch_debug
echo.
echo Lancement de F95Checker en mode debug...
echo Si F95Checker tourne deja, fermez-le d'abord : sinon cette console ne suivra pas l'application.
echo.
cd /d "%SRCDIR%"
%PY% main-debug.py
echo.
echo F95Checker s'est arrete (code %ERRORLEVEL%).
pause
exit /b 0

:install_python
REM Python prive au launcher, installe pour l'utilisateur courant (sans droits admin)
if defined UPDATE_PROMPT exit /b 0
echo Installation de Python 3.12, une seule fois, patientez...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [IO.Directory]::CreateDirectory($env:RUNTIME)|Out-Null; $dest=Join-Path $env:RUNTIME 'python-installer.exe'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe' -OutFile $dest -UseBasicParsing -TimeoutSec 300; if((Get-FileHash -Algorithm SHA256 $dest).Hash -ne '67b5635e80ea51072b87941312d00ec8927c4db9ba18938f7ad2d27b328b95fb'){ Remove-Item $dest; throw 'Empreinte de l''installateur Python invalide' }; $opts='/quiet InstallAllUsers=0 Include_launcher=0 Include_test=0 Include_doc=0 Include_tcltk=0 Shortcuts=0 AssociateFiles=0 PrependPath=0 TargetDir='+[char]34+$env:PRIVATE_PY_DIR+[char]34; $proc=Start-Process -FilePath $dest -ArgumentList $opts -Wait -PassThru; Remove-Item $dest -ErrorAction SilentlyContinue; if($proc.ExitCode -ne 0){ throw ('Installateur Python : code '+$proc.ExitCode) } }"
if exist "%PRIVATE_PY%" set PY="%PRIVATE_PY%"
exit /b 0

:extract_embedded
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $bat='%~f0'; $rt='%RUNTIME%'; [IO.Directory]::CreateDirectory($rt)|Out-Null; $lines=[IO.File]::ReadAllLines($bat,[Text.Encoding]::UTF8); $blocks=@(@('@@BEGIN_SETUP_FRANCE@@','setup_france.py'),@('@@BEGIN_FRANCE_LABELS@@','france_labels.py'),@('@@BEGIN_FRANCE_ICON@@','france_icon.py'),@('@@BEGIN_LC_GAMES@@','lc_games.py'),@('@@BEGIN_SILENT_LAUNCHER@@','silent_launch.vbs')); foreach($pair in $blocks){ $b=@(); $in=$false; foreach($l in $lines){ if($l -eq $pair[0]){$in=$true; continue}; $end=$pair[0] -replace 'BEGIN','END'; if($l -eq $end){break}; if($in){$b+=$l}}; if(-not $b.Count){ throw ('Bloc '+$pair[0]+' introuvable') }; [IO.File]::WriteAllLines((Join-Path $rt $pair[1]),$b,[Text.UTF8Encoding]::new($false)) } }"
exit /b %ERRORLEVEL%

:self_update
REM Met a jour les DEUX scripts (.bat et .sh), meme lance depuis le .bat :
REM la plupart des autres utilisateurs ne lancent que le .bat, donc c'est le
REM seul moyen pour eux de recevoir aussi les correctifs du .sh sans passer par git.
if not exist "%~dp0._f95_france_cache" mkdir "%~dp0._f95_france_cache"
set "UPDATE_TMP=%~dp0._f95_france_cache\F95Checker-France.update.bat"
set "UPDATE_HELPER=%~dp0._f95_france_cache\apply_self_update.cmd"
set "SH_TARGET=%~dp0F95Checker-France.sh"
set "SELF_BAT=%~f0"
set "F95_RELUNCH_ARGS=%*"
if defined UPDATE_PROMPT set "F95_RELUNCH_ARGS=--no-update"
if defined DEBUG_MODE set "F95_RELUNCH_ARGS=debug"
set "UPDATE_DECLINED=%~dp0._f95_france_cache\declined_launcher_update.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop'; $base=$env:UPDATE_REPO_RAW; $batChanged=$false; try { Invoke-WebRequest -Uri ($base+'/F95Checker-France.bat') -OutFile $env:UPDATE_TMP -UseBasicParsing -TimeoutSec 30; $a=(Get-FileHash -Algorithm SHA256 $env:UPDATE_TMP).Hash; $b=(Get-FileHash -Algorithm SHA256 $env:SELF_BAT).Hash; if($a -ne $b){ $batChanged=$true } else { Remove-Item $env:UPDATE_TMP -ErrorAction SilentlyContinue } } catch { $batChanged=$false }; if($batChanged -and $env:UPDATE_PROMPT){ if((Test-Path $env:UPDATE_DECLINED) -and ((Get-Content $env:UPDATE_DECLINED -Raw).Trim() -eq $a)){ Remove-Item $env:UPDATE_TMP -ErrorAction SilentlyContinue; exit 0 }; Add-Type -AssemblyName System.Windows.Forms; $owner=New-Object System.Windows.Forms.Form -Property @{TopMost=$true}; $answer=[System.Windows.Forms.MessageBox]::Show($owner,'Une nouvelle version du launcher F95Checker France est disponible. Mettre a jour maintenant ?','F95Checker France',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question); if($answer -ne [System.Windows.Forms.DialogResult]::Yes){ Set-Content -Path $env:UPDATE_DECLINED -Value $a; Remove-Item $env:UPDATE_TMP -ErrorAction SilentlyContinue; exit 0 } }; try { $tmpSh=[IO.Path]::GetTempFileName(); Invoke-WebRequest -Uri ($base+'/F95Checker-France.sh') -OutFile $tmpSh -UseBasicParsing -TimeoutSec 30; $needSh=$true; if(Test-Path $env:SH_TARGET){ $c=(Get-FileHash -Algorithm SHA256 $tmpSh).Hash; $d=(Get-FileHash -Algorithm SHA256 $env:SH_TARGET).Hash; $needSh=($c -ne $d) }; if($needSh){ Copy-Item $tmpSh $env:SH_TARGET -Force; Write-Host 'F95Checker-France.sh mis a jour (pour tes utilisateurs Linux).' }; Remove-Item $tmpSh -ErrorAction SilentlyContinue } catch {}; if($batChanged){ exit 1 } else { exit 0 } }"
if errorlevel 1 goto :self_update_apply_bat
goto :eof

:self_update_apply_bat
echo.
echo Mise a jour du launcher disponible, installation...
(
echo @echo off
echo ping -n 2 127.0.0.1 ^>nul
echo copy /y "%UPDATE_TMP%" "%SELF_BAT%" ^>nul
echo del "%UPDATE_TMP%" 2^>nul
echo start "" "%SELF_BAT%" %F95_RELUNCH_ARGS%
echo del "%%~f0"
) > "%UPDATE_HELPER%"
start "" /min cmd /c "%UPDATE_HELPER%"
exit /b 1

goto :eof
@@BEGIN_SETUP_FRANCE@@
#!/usr/bin/env python3
"""Installation du patch F95-France + lancement F95Checker."""

from __future__ import annotations

import argparse
import configparser
import ctypes
import hashlib
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCH_DIR = Path(__file__).resolve().parent
CACHE_DIR = ROOT / "._f95_france_cache"
SRC = ROOT / "F95Checker-src"
INI = CACHE_DIR / "france_labels.ini"
REPO = "https://github.com/WillyJL/F95Checker.git"
BROKEN_MARKER = CACHE_DIR / "broken_commit.txt"
MINGIT_URL = "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip"
MINGIT_SHA256 = "e3bf78351fe777fba47ddee5950082f8a98bb0f02604fdc7ba3ee2cb68ffa877"
MINGIT_DIR = CACHE_DIR / "mingit"
# Wheels Windows compilees par .github/workflows/windows-wheels.yml
WHEELS_RELEASE_API = "https://api.github.com/repos/Hunteraulo1/f95list-f95checker/releases/tags/windows-wheels"
PATCHED_FILES_TO_VERIFY = (
    "main.py",
    "modules/gui.py",
    "modules/api.py",
    "modules/callbacks.py",
    "modules/globals.py",
    "modules/rpc_thread.py",
    "common/structs.py",
    "common/meta.py",
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

GUI_STATUS_OLD = """                        elif globals.last_update_check is None:
                            text = "Checking for updates..."
"""

GUI_STATUS_NEW = """                        elif lc_status := lc_games.status_text():
                            text = lc_status
                        elif france_labels.is_busy():
                            text = "Synchronisation F95-France..."
                        elif france_labels.is_checking_updates():
                            text = "Verification des mises a jour..."
""" + GUI_STATUS_OLD

GUI_UPDATE_CHECK_OLD = """            if france_labels.last_result():
                draw_settings_label(france_labels.last_result())"""

GUI_UPDATE_CHECK_NEW = GUI_UPDATE_CHECK_OLD + """
            draw_settings_label("Mises a jour")
            update_check_disabled = france_labels.is_checking_updates()
            if update_check_disabled:
                imgui.push_disabled()
            if imgui.button("Verifier", width=right_width):
                async_thread.run(france_labels.check_updates_from_gui())
            if update_check_disabled:
                imgui.pop_disabled()
            if france_labels.last_update_result():
                draw_settings_label(france_labels.last_update_result())"""

GUI_TR_CLEANUP_OLD = """            if france_labels.last_update_result():
                draw_settings_label(france_labels.last_update_result())"""

GUI_TR_CLEANUP_NEW = GUI_TR_CLEANUP_OLD + """
            for tr_key, tr_label, tr_tip in (
                ("tr_delete_archive", "Traductions : supprimer l'archive",
                 "Supprime le .zip / .rar telecharge une fois la traduction installee.\\n"
                 "Garde-la si tu veux pouvoir reinstaller la traduction apres une mise a jour du jeu."),
                ("tr_delete_extracted", "Traductions : supprimer le dossier decompresse",
                 "Supprime le dossier decompresse une fois la traduction installee\\n"
                 "(les fichiers sont deja copies dans le jeu)."),
            ):"""

GUI_TR_CLEANUP_LOOP_BODY = """
                draw_settings_label(tr_label, tr_tip)
                imgui.set_cursor_pos_x(imgui.get_cursor_pos_x() + checkbox_offset)
                tr_changed, tr_value = imgui.checkbox(f"###{tr_key}", france_labels.tr_cleanup_setting(tr_key))
                if tr_changed:
                    france_labels.set_tr_cleanup_setting(tr_key, tr_value)"""

# Version precedente (2 reglages) : remplacee a la volee pour les sources deja patchees
GUI_TR_CLEANUP_V1 = GUI_TR_CLEANUP_NEW + GUI_TR_CLEANUP_LOOP_BODY
GUI_TR_CLEANUP_NEW = GUI_TR_CLEANUP_NEW[:-len("\n            ):")] + """
                ("game_delete_archive", "Jeux (Donor DDL) : supprimer l'archive",
                 "Supprime l'archive du jeu telechargee via Donor DDL une fois\\n"
                 "son extraction reussie (option \\"Extract downloads\\" activee)."),
            ):""" + GUI_TR_CLEANUP_LOOP_BODY

GUI_REORG_NEW = GUI_TR_CLEANUP_NEW + """
            france_labels.draw_reorganize_settings(draw_settings_label, right_width)"""

GUI_DDL_OPEN_OLD = """                    if not errored:
                        if imgui.button(icons.open_in_app):
                            async_thread.run(callbacks.default_open(download.path))"""

GUI_DDL_OPEN_NEW = """                    if not errored:
                        if download.path.exists() and imgui.button(icons.open_in_app):  # archive peut-etre supprimee
                            async_thread.run(callbacks.default_open(download.path))"""

GUI_ANCHOR = """            imgui.end_table()
            imgui.spacing()

        if draw_settings_section("Manage"):"""

GUI_ANCHOR_REPLACEMENT = """            imgui.end_table()
            imgui.spacing()
""" + GUI_SNIPPET + """
        if draw_settings_section("Manage"):"""


def find_python() -> list[str]:
    # Le launcher (.bat/.sh) a deja choisi l'interpreteur qui execute ce script
    if sys.version_info[:2] in ((3, 12), (3, 11)):
        return [sys.executable]
    return []


def use_bundled_certificates() -> None:
    """Windows recent : les certificats racines ne sont mis en cache qu'a la demande, Python
    les trouve donc absents (CERTIFICATE_VERIFY_FAILED). On utilise ceux fournis avec pip."""
    try:
        from pip._vendor import certifi
        context = ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return
    urllib.request.install_opener(urllib.request.build_opener(urllib.request.HTTPSHandler(context=context)))


def _download_mingit() -> None:
    archive = CACHE_DIR / "mingit.zip"
    extracted = CACHE_DIR / "mingit.tmp"
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(extracted, ignore_errors=True)
    urllib.request.urlretrieve(MINGIT_URL, archive)
    try:
        if hashlib.sha256(archive.read_bytes()).hexdigest() != MINGIT_SHA256:
            raise ValueError("empreinte de l'archive invalide")
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(extracted)
        extracted.rename(MINGIT_DIR)
    finally:
        archive.unlink(missing_ok=True)


def ensure_git() -> None:
    """Windows sans Git : installe MinGit dans le cache, sans droits admin ni PATH systeme."""
    if sys.platform != "win32" or shutil.which("git"):
        return
    git_dir = MINGIT_DIR / "cmd"
    if not (git_dir / "git.exe").is_file():
        if os.environ.get("UPDATE_PROMPT"):
            return  # Demarrage avec Windows : pas d'installation sans fenetre visible
        print("Installation de Git (une seule fois, patientez)...")
        try:
            _download_mingit()
        except Exception as exc:
            msg = f"Installation de Git impossible ({exc}).\nLes mises a jour de F95Checker sont indisponibles."
            print(msg)
            ctypes.windll.user32.MessageBoxW(0, msg, "F95Checker France", 0x40030)
            return
    os.environ["PATH"] = f"{git_dir}{os.pathsep}{os.environ['PATH']}"


def ensure_src() -> None:
    if (SRC / "main.py").is_file():
        return
    print("Telechargement de F95Checker (git clone)...")
    if shutil.which("git"):
        subprocess.run(["git", "clone", "--depth", "1", REPO, str(SRC)], check=True, cwd=ROOT)
        return
    raise SystemExit(
        "F95Checker-src introuvable et Git indisponible.\n"
        "Verifiez votre connexion puis relancez."
    )


def _verify_patched_files_compile() -> None:
    import py_compile
    for rel in PATCHED_FILES_TO_VERIFY:
        py_compile.compile(str(SRC / rel), doraise=True)


def _broken_marker_value(commit: str) -> str:
    """Commit casse + empreinte de nos scripts de patch : un launcher corrige
    invalide le marqueur et retente la mise a jour, meme sans nouveau commit amont."""
    import hashlib
    digest = hashlib.sha256()
    for name in ("setup_france.py", "lc_games.py", "france_labels.py", "france_icon.py"):
        path = PATCH_DIR / name
        if path.is_file():
            digest.update(path.read_bytes())
    return f"{commit} {digest.hexdigest()[:12]}"


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
    except Exception as exc:
        print(f"Mise a jour de F95Checker non verifiee ({exc}).")
        return  # Pas de connexion ou souci git : on continue avec la version actuelle

    if local == remote:
        return  # Deja a jour

    broken = BROKEN_MARKER.read_text(encoding="utf-8").strip() if BROKEN_MARKER.is_file() else ""
    if broken == _broken_marker_value(remote):
        print(
            f"Une mise a jour de F95Checker est disponible ({local[:7]} -> {remote[:7]}) "
            "mais reste incompatible avec nos patches. Le lancement se poursuit avec la "
            "version actuellement installee."
        )
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
        BROKEN_MARKER.write_text(_broken_marker_value(remote), encoding="utf-8")
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

GUI_ADD_BOX_OLD = "                async_thread.run(callbacks.add_games(*utils.extract_thread_matches(self.add_box_text), open_duplicate=True))"

GUI_ADD_BOX_NEW = """                from modules import lc_games
                lc_urls, other_text = lc_games.split_add_box_text(self.add_box_text)
                matches = utils.extract_thread_matches(other_text)
                if matches:
                    async_thread.run(callbacks.add_games(*matches, open_duplicate=True))
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

GLOBALS_STARTCMD_PREVIOUS = """    if os is Os.Windows:
        import winreg
        _france_root = pathlib.Path(__file__).resolve().parents[2]
        _france_bat = _france_root / "F95Checker-France.bat"
        _france_vbs = _france_root / "._f95_france_cache" / "silent_launch.vbs"
        if _france_bat.is_file() and _france_vbs.is_file():
            start_cmd = f'wscript.exe //B "{_france_vbs}" "{_france_bat}"'
        else:
            start_cmd = " ".join(f'"{split}"' for split in start_cmd)
        autostart = pathlib.Path("SOFTWARE\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run\\\\F95Checker")"""

# Le .vbs ne transmet pas d'arguments : les sous-processus (webview, notifications)
# doivent lancer main.py directement, sinon ils relancent juste le .bat.
GLOBALS_STARTCMD_NEW = """    if os is Os.Windows:
        import winreg
        start_cmd = " ".join(f'"{split}"' for split in start_cmd)
        daemon_cmd = start_cmd
        _france_root = pathlib.Path(__file__).resolve().parents[2]
        _france_bat = _france_root / "F95Checker-France.bat"
        _france_vbs = _france_root / "._f95_france_cache" / "silent_launch.vbs"
        if _france_bat.is_file() and _france_vbs.is_file():
            start_cmd = f'wscript.exe //B "{_france_vbs}" "{_france_bat}"'
        autostart = pathlib.Path("SOFTWARE\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run\\\\F95Checker")"""

GLOBALS_DAEMONCMD_OLD = """start_cmd = None
autostart = None
start_with_system = None
def _():
    global start_cmd, autostart, start_with_system"""

GLOBALS_DAEMONCMD_NEW = """start_cmd = None
daemon_cmd = None
autostart = None
start_with_system = None
def _():
    global start_cmd, daemon_cmd, autostart, start_with_system"""

DAEMON_SPAWN_OLD = "*shlex.split(globals.start_cmd),"
DAEMON_SPAWN_NEW = "*shlex.split(globals.daemon_cmd or globals.start_cmd),"

# Apercus LewdCorner : passer par lc_games._fetch_page plutot que api.download_image,
# qui enverrait les cookies de session F95zone a lewdcorner.com
STRUCTS_PREVIEW_OLD = """                    data, _ = await api.download_image(url)"""

STRUCTS_PREVIEW_NEW = """                    if "lewdcorner.com" in url:
                        from modules import lc_games
                        data, _ = await lc_games._fetch_page(url)
                    else:
                        data, _ = await api.download_image(url)"""

# Le sous-processus webview ne connait que les fonctions de webview.py
WEBVIEW_LC_BROWSER = """

def lc_browser(**kwargs):
    from modules import lc_games
    lc_games.browser_daemon(**kwargs)
"""

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


API_LC_QUEUE_OLD = """    fast_queue: list[list[Game]] = [[]]
    for game in (games or globals.games.values()):
        if game.custom:
            continue
"""

API_LC_QUEUE_NEW = """    from modules import lc_games
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
"""

API_LC_TOTAL_OLD = """    globals.refresh_total += sum(len(chunk) for chunk in fast_queue) + bool(notifs)
"""

API_LC_TOTAL_NEW = """    globals.refresh_total += sum(len(chunk) for chunk in fast_queue) + bool(notifs) + len(lc_queue)
"""

API_LC_TASKS_OLD = """        await asyncio.gather(*tasks)
"""

# @UPDATES@ : dict local "updates" des versions upstream recentes, sinon None
# (lc_games retombe alors sur l'ancien globals.new_updated_games)
API_LC_TASKS_NEW = """        tasks += await lc_games.start_refresh(lc_queue, @UPDATES@, full=full, selection=bool(games))
        await asyncio.gather(*tasks)
"""

API_LC_REPORT_OLD = """    if notifs:
        await check_notifs(standalone=False)
"""

API_LC_REPORT_NEW = """    lc_games.report_session_expired()

    if notifs:
        await check_notifs(standalone=False)
"""

# Refresh LC (clic droit sur Refresh) : refresh normal limite aux jeux LewdCorner,
# sans toucher aux jeux F95zone ni a la date du dernier refresh complet
API_LC_ONLY_PATCHES = (
    (
        "async def refresh(*games: Game, full=False, notifs=True, force_archived=False, force_completed=False):",
        "async def refresh(*games: Game, full=False, notifs=True, force_archived=False, force_completed=False, lc_only=False):",
        "signature",
    ),
    (
        "                lc_queue.append(game)\n            continue\n",
        "                lc_queue.append(game)\n            continue\n        if lc_only:\n            continue\n",
        "file d'attente",
    ),
    (
        "    notifs = notifs and globals.settings.check_notifs\n",
        "    notifs = notifs and not lc_only and globals.settings.check_notifs\n",
        "notifs",
    ),
    (
        "    if not games:\n        globals.settings.last_successful_refresh.update(time.time())\n",
        "    if not games and not lc_only:\n        globals.settings.last_successful_refresh.update(time.time())\n",
        "dernier refresh",
    ),
)

GUI_LC_REFRESH_OLD = """                if imgui.selectable(f"{icons.reload_alert} Full Refresh", False)[0]:
                    utils.start_refresh_task(api.refresh(full=True))
"""

GUI_LC_REFRESH_NEW = """                if imgui.selectable(f"{icons.refresh} Refresh LC", False)[0]:
                    utils.start_refresh_task(api.refresh(notifs=False, lc_only=True))
""" + GUI_LC_REFRESH_OLD


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


META_VERSION_OLD = '''build_number = 0
version_name = f"{version}{'' if release else ' beta'}{'' if release or not build_number else ' ' + str(build_number)}"'''

META_VERSION_NEW = '''build_number = 0


def _france_git_commit() -> str:
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=pathlib.Path(__file__).resolve().parent,
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""


build_commit = "" if release or build_number else _france_git_commit()
version_name = f"{version}{'' if release else ' beta'}{'' if release or not build_number else ' ' + str(build_number)}{'' if release or build_number or not build_commit else ' (' + build_commit + ')'}"'''


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


def _patch_api_refresh(text: str) -> str:
    """Branche LewdCorner dans api.refresh() via de petites ancres, limitees au corps
    de la fonction, plutot que de remplacer la fonction entiere : survit aux
    changements upstream qui ne touchent pas ces lignes precises."""
    start = text.find("\nasync def refresh(")
    if start == -1:
        raise SystemExit("api.py a change : fonction refresh() introuvable.")
    ends = [i for i in (text.find("\nasync def ", start + 1), text.find("\ndef ", start + 1)) if i != -1]
    end = min(ends) if ends else len(text)
    func = text[start:end]
    updates_arg = "updates" if "    updates: dict[int, OldGame] = {}\n" in func else "None"
    for old, new, label in (
        (API_LC_QUEUE_OLD, API_LC_QUEUE_NEW, "file d'attente"),
        (API_LC_TOTAL_OLD, API_LC_TOTAL_NEW, "progression"),
        (API_LC_TASKS_OLD, API_LC_TASKS_NEW.replace("@UPDATES@", updates_arg), "taches"),
        (API_LC_REPORT_OLD, API_LC_REPORT_NEW, "rapport session"),
    ):
        if func.count(old) != 1:
            raise SystemExit(f"api.py a change : patch refresh() LewdCorner impossible ({label}).")
        func = func.replace(old, new, 1)
    return text[:start] + func + text[end:]


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

    gui_text = gui.read_text(encoding="utf-8")
    if "lc_games.status_text" not in gui_text:
        if GUI_STATUS_OLD not in gui_text:
            raise SystemExit("gui.py a change : patch texte de progression impossible.")
        gui.write_text(gui_text.replace(GUI_STATUS_OLD, GUI_STATUS_NEW, 1), encoding="utf-8")
        verify_gui()
        print("Progression LewdCorner affichee en bas de fenetre (gui.py).")

    gui_text = gui.read_text(encoding="utf-8")
    if "lc_only=True" not in gui_text:
        if GUI_LC_REFRESH_OLD not in gui_text:
            raise SystemExit("gui.py a change : patch Refresh LC impossible.")
        gui.write_text(gui_text.replace(GUI_LC_REFRESH_OLD, GUI_LC_REFRESH_NEW, 1), encoding="utf-8")
        verify_gui()
        print("Refresh LC ajoute au clic droit sur Refresh (gui.py).")

    api_module = SRC / "modules" / "api.py"
    api_original = api_module.read_text(encoding="utf-8")
    api_text = api_original
    if "lc_games" not in api_text:
        api_text = _patch_api_refresh(api_text)
    elif "selection=bool(games)" not in api_text:
        # Installations patchees avant le suivi des dernieres mises a jour
        api_text, count = re.subn(
            r"lc_games\.start_refresh\(lc_queue, (\w+)\)",
            r"lc_games.start_refresh(lc_queue, \1, full=full, selection=bool(games))",
            api_text,
        )
        if count != 1:
            raise SystemExit("api.py a change : patch suivi des mises a jour LewdCorner impossible.")
    if "lc_only" not in api_text:
        for old, new, label in API_LC_ONLY_PATCHES:
            if api_text.count(old) != 1:
                raise SystemExit(f"api.py a change : patch Refresh LC impossible ({label}).")
            api_text = api_text.replace(old, new, 1)
    if api_text != api_original:
        api_module.write_text(api_text, encoding="utf-8")
        import py_compile
        py_compile.compile(str(api_module), doraise=True)
        print("Suivi des mises a jour LewdCorner branche sur refresh() (api.py).")

    globals_module = SRC / "modules" / "globals.py"
    globals_text = globals_module.read_text(encoding="utf-8")
    if "daemon_cmd" not in globals_text:
        # PREVIOUS : installations deja patchees avant l'ajout de daemon_cmd
        startcmd_old = GLOBALS_STARTCMD_PREVIOUS if GLOBALS_STARTCMD_PREVIOUS in globals_text else GLOBALS_STARTCMD_OLD
        if startcmd_old not in globals_text or GLOBALS_DAEMONCMD_OLD not in globals_text:
            raise SystemExit("globals.py a change : patch Start with System impossible.")
        globals_text = globals_text.replace(startcmd_old, GLOBALS_STARTCMD_NEW, 1)
        globals_module.write_text(globals_text.replace(GLOBALS_DAEMONCMD_OLD, GLOBALS_DAEMONCMD_NEW, 1), encoding="utf-8")
        import py_compile
        py_compile.compile(str(globals_module), doraise=True)
        print("Start with System redirige via le .bat (globals.py).")

    for daemon_module in (SRC / "modules" / "webview.py", SRC / "modules" / "notification_proc.py"):
        daemon_text = daemon_module.read_text(encoding="utf-8")
        if DAEMON_SPAWN_NEW not in daemon_text:
            if DAEMON_SPAWN_OLD not in daemon_text:
                raise SystemExit(f"{daemon_module.name} a change : patch sous-processus impossible.")
            daemon_module.write_text(daemon_text.replace(DAEMON_SPAWN_OLD, DAEMON_SPAWN_NEW, 1), encoding="utf-8")
            print(f"Sous-processus lances sans le .bat ({daemon_module.name}).")

    webview_module = SRC / "modules" / "webview.py"
    webview_text = webview_module.read_text(encoding="utf-8")
    if "def lc_browser" not in webview_text:
        webview_module.write_text(webview_text.rstrip("\n") + "\n" + WEBVIEW_LC_BROWSER, encoding="utf-8")
        print("Navigateur LewdCorner en arriere-plan ajoute (webview.py).")

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

    structs_module = SRC / "common" / "structs.py"
    structs_text = structs_module.read_text(encoding="utf-8")
    if "lc_games" not in structs_text:
        if STRUCTS_PREVIEW_OLD not in structs_text:
            raise SystemExit("structs.py a change : patch apercus LewdCorner impossible.")
        structs_module.write_text(structs_text.replace(STRUCTS_PREVIEW_OLD, STRUCTS_PREVIEW_NEW, 1), encoding="utf-8")
        import py_compile
        py_compile.compile(str(structs_module), doraise=True)
        print("Apercus LewdCorner telecharges avec les cookies LewdCorner (structs.py).")

    if changed:
        _rezip(browser / "chrome", browser / "chrome.zip")
        _rezip(browser / "firefox", browser / "firefox.zip")
        print("Extensions navigateur (chrome.zip / firefox.zip) mises a jour pour LewdCorner.")


DDL_STRUCTS_OLD = """    total: int = None

    class State(enum.IntEnum):"""

DDL_STRUCTS_NEW = """    total: int = None
    game_id: int = None

    class State(enum.IntEnum):"""

DDL_CALL_OLD = """download = FileDownload(file.filename, total=file.size, checksum=("sha1", file.sha1))"""

DDL_CALL_NEW = """download = FileDownload(file.filename, total=file.size, checksum=("sha1", file.sha1), game_id=game.id)"""

DDL_EXTRACT_OLD = """            download.extracted = download.path.with_suffix("")
            await asyncio.get_event_loop().run_in_executor(
                None,
                shutil.unpack_archive,
                download.path,
                download.extracted,
                archive_format,
            )"""

DDL_EXTRACT_NEW = """            download.extracted = await asyncio.get_event_loop().run_in_executor(
                None,
                smart_extract,
                download.path,
                archive_format,
            )
            try:
                await auto_add_executables(download)
            except Exception:
                pass  # Never fail a successful download because of exe detection"""

DDL_DELETE_ARCHIVE_OLD = """                await auto_add_executables(download)
            except Exception:
                pass  # Never fail a successful download because of exe detection"""

DDL_DELETE_ARCHIVE_NEW = DDL_DELETE_ARCHIVE_OLD + """
            try:
                from modules import france_labels
                if france_labels.tr_cleanup_setting("game_delete_archive"):
                    download.path.unlink(missing_ok=True)  # Extraction reussie : l'archive n'est plus utile
            except Exception:
                pass"""

DDL_DOWNLOAD_ANCHOR = "async def download_file(download: FileDownload):"

DDL_HELPERS = r'''_extract_junk_names = {"__macosx", ".ds_store", "thumbs.db", "desktop.ini"}


def _archive_stem(archive: pathlib.Path) -> str:
    # Strip the full archive extension (handles .tar.gz, .tar.bz2, ...)
    name = archive.name
    lower = name.lower()
    for _, extensions, _ in shutil.get_unpack_formats():
        for ext in sorted(extensions, key=len, reverse=True):
            if lower.endswith(ext) and len(name) > len(ext):
                return name[:-len(ext)].rstrip(" .") or name
    return archive.stem


def _merge_move(src: pathlib.Path, dst: pathlib.Path):
    # Move src into dst, merging directories and overwriting files
    if src.is_dir() and not src.is_symlink() and dst.is_dir() and not dst.is_symlink():
        for child in list(src.iterdir()):
            _merge_move(child, dst / child.name)
        src.rmdir()
        return
    if dst.is_symlink() or dst.is_file():
        dst.unlink()
    elif dst.is_dir():
        shutil.rmtree(dst)
    shutil.move(str(src), str(dst))


def smart_extract(archive: pathlib.Path, archive_format: str) -> pathlib.Path:
    """
    Extract archive next to itself into a folder named after the archive,
    without the redundant "Game/Game/..." nesting: if the archive only contains
    a single wrapper folder (ignoring OS junk like __MACOSX), its contents are
    used directly. Returns the final extracted folder.
    """
    archive = pathlib.Path(archive)
    target = archive.parent / _archive_stem(archive)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix=".extracting-", dir=archive.parent))
    try:
        shutil.unpack_archive(archive, tmp, archive_format)

        # Remove OS junk at the top level
        for child in list(tmp.iterdir()):
            if child.name.lower() in _extract_junk_names:
                if child.is_dir() and not child.is_symlink():
                    shutil.rmtree(child, ignore_errors=True)
                else:
                    child.unlink(missing_ok=True)

        # Descend through single-folder wrappers (Game/Game-1.0-pc/...)
        root = tmp
        while True:
            children = [c for c in root.iterdir() if c.name.lower() not in _extract_junk_names]
            if (
                len(children) == 1
                and children[0].is_dir()
                and not children[0].is_symlink()
                and children[0].suffix.lower() != ".app"  # Keep macOS app bundles intact
            ):
                root = children[0]
            else:
                break

        if not target.exists():
            root.rename(target)
        else:
            # Re-extract / update over an existing folder: merge contents
            target.mkdir(parents=True, exist_ok=True)
            for child in list(root.iterdir()):
                _merge_move(child, target / child.name)
        return target
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# Executables shipped alongside games that are never the game itself
_exe_blacklist = re.compile(
    r"^(?:"
    r"unitycrashhandler.*|unins\d*|uninstall.*|setup|vc_?redist.*|vcredist.*|dxsetup|dxwebsetup|oalinst|"
    r"directx.*|dotnet.*|ndp\d+.*|physx.*|xnafx.*|"
    r"python[w\d.]*|pythonw|zsync.*|ffmpeg|ffprobe|ffplay|7z.*|unrar|"
    r"notification_helper|nwjc|payload|crashpad_handler|createdump|chromedriver|"
    r"qtwebengineprocess|cefsharp\..*|.*crashreport.*|.*crash_?handler.*|"
    r"renpy|lib|rpatool|unrpyc|un\.rpyc"
    r")$",
    re.IGNORECASE,
)


def _norm_name(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def find_game_executables(folder: pathlib.Path, game_name: str = "") -> list[pathlib.Path]:
    """
    Find the most likely launcher(s) for the current OS in an extracted game folder.
    Returns the best candidates (several only when they are equally likely).
    """
    if globals.os is Os.Windows:
        def is_candidate(p: pathlib.Path):
            return p.is_file() and p.suffix.lower() == ".exe"
    elif globals.os is Os.MacOS:
        def is_candidate(p: pathlib.Path):
            return p.is_dir() and p.suffix.lower() == ".app"
    else:
        def is_candidate(p: pathlib.Path):
            return p.is_file() and (
                p.suffix.lower() in (".sh", ".x86_64", ".x86", ".appimage")
                or (not p.suffix and os.access(p, os.X_OK))
            )

    game_key = _norm_name(game_name)
    folder_key = _norm_name(folder.name)
    best: list[pathlib.Path] = []
    best_score = None
    # Look at the root first, only go deeper if nothing usable is found there
    dirs = [folder]
    for depth in range(3):
        candidates = []
        for d in dirs:
            try:
                candidates.extend(c for c in d.iterdir() if is_candidate(c))
            except OSError:
                pass
        candidates = [c for c in candidates if not _exe_blacklist.match(c.stem)]
        for exe in candidates:
            stem = exe.stem
            key = _norm_name(stem)
            siblings = {s.name.lower() for s in exe.parent.iterdir()}
            score = 0
            if f"{stem.lower()}.py" in siblings and "renpy" in siblings:
                score += 100  # Ren'Py launcher
            if f"{stem.lower()}_data" in siblings:
                score += 100  # Unity player
            if "package.nw" in siblings or "www" in siblings:
                score += 20  # RPG Maker MV/MZ / NW.js
            if game_key and key and (key in game_key or game_key in key):
                score += 30
            if folder_key and key and key in folder_key:
                score += 10
            if re.search(r"(?:-32|32bit|x86|_32)$", stem, re.IGNORECASE):
                score -= 15  # Prefer 64 bit builds
            if re.search(r"config|settings|launcher|editor|server|patch|update|mod", stem, re.IGNORECASE):
                score -= 10
            score -= depth * 5
            if best_score is None or score > best_score:
                best, best_score = [exe], score
            elif score == best_score:
                best.append(exe)
        if best:
            break
        next_dirs = []
        for d in dirs:
            try:
                next_dirs.extend(
                    c for c in d.iterdir()
                    if c.is_dir() and not c.is_symlink() and c.suffix.lower() != ".app"
                    and c.name.lower() not in ("renpy", "lib", "game", "www", "__macosx")
                    and not c.name.lower().endswith("_data")
                )
            except OSError:
                pass
        dirs = next_dirs
    # Too many equally likely candidates means we can't tell, let the user pick
    if len(best) > 3:
        return []
    return sorted(best)


async def auto_add_executables(download: FileDownload):
    if not download.extracted or download.game_id is None:
        return
    game = globals.games.get(download.game_id)
    if not game:
        return
    exes = await asyncio.get_event_loop().run_in_executor(
        None, find_game_executables, download.extracted, game.name
    )
    if not exes:
        return

    # Drop executables of previous versions downloaded in the same game folder
    downloads_root = download.path.parent.resolve()
    base = globals.settings.default_exe_dir.get(globals.os)
    for executable in list(game.executables):
        if utils.is_uri(executable):
            continue
        exe = pathlib.Path(executable)
        if not exe.is_absolute() and base:
            exe = pathlib.Path(base) / exe
        try:
            exe = exe.resolve()
        except OSError:
            continue
        if downloads_root in exe.parents and download.extracted.resolve() not in exe.parents:
            game.remove_executable(executable)

    for exe in exes:
        game.add_executable(str(exe))


'''


def apply_ddl_patches() -> None:
    """Donor DDL : extraction sans dossier en double + ajout automatique de l'exe au jeu.
    Optionnel : si l'amont a change, on previent sans bloquer le lancement."""
    structs_module = SRC / "common" / "structs.py"
    api_module = SRC / "modules" / "api.py"
    structs_text = structs_module.read_text(encoding="utf-8")
    api_text = api_module.read_text(encoding="utf-8")
    if "def smart_extract(" in api_text and "game_id: int = None" in structs_text:
        _apply_ddl_delete_archive_patch(api_module, api_text)
        return
    if (
        structs_text.count(DDL_STRUCTS_OLD) != 1
        or api_text.count(DDL_CALL_OLD) != 1
        or api_text.count(DDL_EXTRACT_OLD) != 1
        or api_text.count(DDL_DOWNLOAD_ANCHOR) != 1
    ):
        print("ATTENTION : api.py/structs.py a change, patch extraction Donor DDL impossible.")
        return
    structs_text = structs_text.replace(DDL_STRUCTS_OLD, DDL_STRUCTS_NEW, 1)
    api_text = api_text.replace(DDL_CALL_OLD, DDL_CALL_NEW, 1)
    api_text = api_text.replace(DDL_EXTRACT_OLD, DDL_EXTRACT_NEW, 1)
    api_text = api_text.replace(DDL_DOWNLOAD_ANCHOR, DDL_HELPERS + DDL_DOWNLOAD_ANCHOR, 1)
    structs_module.write_text(structs_text, encoding="utf-8")
    api_module.write_text(api_text, encoding="utf-8")
    import py_compile
    py_compile.compile(str(structs_module), doraise=True)
    py_compile.compile(str(api_module), doraise=True)
    print("Extraction Donor DDL intelligente + ajout auto de l'exe (api.py, structs.py).")
    _apply_ddl_delete_archive_patch(api_module, api_text)


def _apply_ddl_delete_archive_patch(api_module: Path, api_text: str) -> None:
    if "game_delete_archive" in api_text:
        return
    if api_text.count(DDL_DELETE_ARCHIVE_OLD) != 1:
        print("ATTENTION : api.py a change, suppression de l'archive Donor DDL impossible.")
        return
    api_module.write_text(api_text.replace(DDL_DELETE_ARCHIVE_OLD, DDL_DELETE_ARCHIVE_NEW, 1), encoding="utf-8")
    import py_compile
    py_compile.compile(str(api_module), doraise=True)
    print("Suppression optionnelle de l'archive apres extraction Donor DDL (api.py).")


GUI_TR_TAB_OLD = """                if imgui.begin_tab_item((
                    icons.draw_pen if game.notes else"""

GUI_TR_TAB_NEW = """                france_labels.draw_translations_tab(game)

""" + GUI_TR_TAB_OLD

WEBVIEW_FR_DOWNLOAD = """

def fr_download(*args, **kwargs):
    from modules import france_labels
    france_labels.browser_download_daemon(*args, **kwargs)
"""


def apply_translation_patches() -> None:
    """Onglet "F95 France" (traductions) dans la fiche d'un jeu + telechargement via navigateur.
    Optionnel : si l'amont a change, on previent sans bloquer le lancement."""
    gui = SRC / "modules" / "gui.py"
    gui_text = gui.read_text(encoding="utf-8")
    if "draw_translations_tab" not in gui_text:
        if gui_text.count(GUI_TR_TAB_OLD) != 1:
            print("ATTENTION : gui.py a change, onglet traductions F95 France impossible.")
        else:
            gui.write_text(gui_text.replace(GUI_TR_TAB_OLD, GUI_TR_TAB_NEW, 1), encoding="utf-8")
            verify_gui()
            print("Onglet traductions F95 France ajoute (gui.py).")
    webview_module = SRC / "modules" / "webview.py"
    webview_text = webview_module.read_text(encoding="utf-8")
    if "def fr_download" not in webview_text:
        webview_module.write_text(webview_text.rstrip("\n") + "\n" + WEBVIEW_FR_DOWNLOAD, encoding="utf-8")
        print("Telechargement de traductions via navigateur ajoute (webview.py).")


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
    if "check_updates_from_gui" not in text:
        if GUI_UPDATE_CHECK_OLD not in text:
            raise SystemExit("gui.py a change : patch bouton mises a jour impossible.")
        text = text.replace(GUI_UPDATE_CHECK_OLD, GUI_UPDATE_CHECK_NEW, 1)
        print("Bouton de verification des mises a jour ajoute (gui.py).")
    if "game_delete_archive" not in text:
        if GUI_TR_CLEANUP_V1 in text:
            text = text.replace(GUI_TR_CLEANUP_V1, GUI_TR_CLEANUP_NEW, 1)
        elif "tr_cleanup_setting" not in text and GUI_TR_CLEANUP_OLD in text:
            text = text.replace(GUI_TR_CLEANUP_OLD, GUI_TR_CLEANUP_NEW, 1)
        else:
            raise SystemExit("gui.py a change : patch reglages de nettoyage impossible.")
        print("Reglages de nettoyage des archives ajoutes (gui.py).")
    if "draw_reorganize_settings" not in text:
        if GUI_TR_CLEANUP_NEW not in text:
            raise SystemExit("gui.py a change : patch rangement des dossiers impossible.")
        text = text.replace(GUI_TR_CLEANUP_NEW, GUI_REORG_NEW, 1)
        print("Bouton de rangement des dossiers de jeux ajoute (gui.py).")
    if "archive peut-etre supprimee" not in text:
        if GUI_DDL_OPEN_OLD in text:
            text = text.replace(GUI_DDL_OPEN_OLD, GUI_DDL_OPEN_NEW, 1)
        else:
            print("ATTENTION : gui.py a change, bouton d'ouverture de l'archive Donor DDL non adapte.")
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
    meta_module = SRC / "common" / "meta.py"
    meta_text = meta_module.read_text(encoding="utf-8")
    if "_france_git_commit" not in meta_text:
        if META_VERSION_OLD not in meta_text:
            print("ATTENTION : meta.py a change, affichage du commit impossible.")
        else:
            meta_module.write_text(meta_text.replace(META_VERSION_OLD, META_VERSION_NEW, 1), encoding="utf-8")
            import py_compile
            py_compile.compile(str(meta_module), doraise=True)
            print("Commit F95Checker-src affiche a la place du numero de build (meta.py).")
    apply_ddl_patches()
    apply_translation_patches()
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
    if INI.is_file():
        cfg.read(INI, encoding="utf-8")  # Garde les autres reglages (nettoyage des traductions...)
    if not cfg.has_section("france"):
        cfg.add_section("france")
    cfg["france"].update({
        "api_key": api_key.strip(),
        "auth_mode": cfg["france"].get("auth_mode", "bearer"),
        "api_url": cfg["france"].get("api_url", "https://f95france.site/api/games"),
        "ignore_ids": cfg["france"].get("ignore_ids", "71058"),
    })
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


def download_prebuilt_wheels() -> Path | None:
    """Windows : imgui et zipfile-deflate64 n'ont pas de wheel PyPI pour Python 3.12,
    pip devrait les compiler (MSVC requis). On recupere celles publiees par la CI du
    depot. None si indisponibles : pip compilera comme avant."""
    if sys.platform != "win32":
        return None
    suffix = f"-cp{sys.version_info.major}{sys.version_info.minor}-win_amd64.whl"
    dest = CACHE_DIR / "wheels"
    try:
        with urllib.request.urlopen(WHEELS_RELEASE_API, timeout=30) as resp:
            assets = json.load(resp)["assets"]
        dest.mkdir(parents=True, exist_ok=True)
        for asset in assets:
            name = asset["name"]
            if name.endswith(suffix) and not (dest / name).is_file():
                urllib.request.urlretrieve(asset["browser_download_url"], dest / name)
    except Exception as exc:
        print(f"Wheels precompilees indisponibles ({exc}), pip compilera si besoin.")
        return None
    return dest


def ensure_deps(py_cmd: list[str]) -> None:
    # Le marqueur retient l'interpreteur : F95Checker-src peut etre partage entre
    # Windows et Linux (dual boot), et un changement de version de Python impose
    # de reinstaller les dependances.
    marker = SRC / ".deps_ok"
    stamp = f"{sys.executable} {sys.version}"
    if marker.is_file() and marker.read_text(encoding="utf-8").strip() == stamp:
        return
    print("Dependances (une fois, patientez)...")
    cmd = [*py_cmd, "-m", "pip", "install", "-q", "-U", "-r", "requirements.txt"]
    if (wheels := download_prebuilt_wheels()) is not None:
        cmd += ["--find-links", str(wheels)]
    subprocess.run(cmd, check=True, cwd=SRC)
    marker.write_text(stamp, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reconfigure", action="store_true")
    parser.add_argument("--setup-only", action="store_true")
    args = parser.parse_args()
    py_cmd = find_python()
    if not py_cmd:
        print("Python 3.12 (ou 3.11) requis.")
        return 1
    use_bundled_certificates()
    ensure_git()
    ensure_src()
    auto_update_upstream()
    apply_patches()
    # Avant ensure_config : la verification de la cle API importe les modules de F95Checker
    ensure_deps(py_cmd)
    ensure_config(force=args.reconfigure)
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
import os
import shutil
import sqlite3
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

import certifi

from common.structs import Label

API_URL = "https://f95france.site/api/games"
LAUNCHER_RAW_URL = "https://raw.githubusercontent.com/Hunteraulo1/f95list-f95checker/main/F95Checker-France.bat"
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

# Windows recent : racines absentes du magasin tant qu'elles n'ont pas servi (voir setup_france.py)
_SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())

_busy = False
_last_result = ""
_checking_updates = False
_last_update_result = ""


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


_TR_CLEANUP_KEYS = ("tr_delete_archive", "tr_delete_extracted", "game_delete_archive")
_tr_cleanup_cache: dict[str, bool] | None = None


def tr_cleanup_setting(key: str) -> bool:
    global _tr_cleanup_cache
    if _tr_cleanup_cache is None:
        section = load_config()["france"]
        _tr_cleanup_cache = {k: section.getboolean(k, fallback=False) for k in _TR_CLEANUP_KEYS}
    return _tr_cleanup_cache.get(key, False)


def set_tr_cleanup_setting(key: str, value: bool) -> None:
    tr_cleanup_setting(key)
    _tr_cleanup_cache[key] = bool(value)
    path = _config_paths()[0]
    cfg = configparser.ConfigParser()
    if path.is_file():
        cfg.read(path, encoding="utf-8")
    if not cfg.has_section("france"):
        cfg.add_section("france")
    cfg["france"][key] = "true" if value else "false"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        cfg.write(f)


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
        with urllib.request.urlopen(req, timeout=60, context=_SSL_CONTEXT) as resp:
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


def is_checking_updates() -> bool:
    return _checking_updates


def last_update_result() -> str:
    return _last_update_result


def _check_launcher(root: Path) -> tuple[bool, str]:
    """Compare le .bat local au .bat publie sur GitHub."""
    req = urllib.request.Request(LAUNCHER_RAW_URL, headers=_HTTP_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30, context=_SSL_CONTEXT) as resp:
            remote = resp.read()
        local = (root / "F95Checker-France.bat").read_bytes()
    except OSError as exc:
        raise ValueError(f"Launcher : verification impossible ({exc}).") from exc
    if remote == local:
        return False, "Launcher : a jour."
    return True, "Launcher : nouvelle version disponible."


def _git_output(src: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=src, capture_output=True, encoding="utf-8", errors="replace", timeout=30,
        stdin=subprocess.DEVNULL, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or f"git {args[0]} a echoue")
    return result.stdout.strip()


def _check_upstream(src: Path) -> tuple[bool, str]:
    """Compare le commit installe au dernier commit de F95Checker."""
    if not shutil.which("git"):
        raise ValueError("F95Checker : verification impossible (Git introuvable).")
    try:
        local = _git_output(src, "rev-parse", "HEAD")
        remote = _git_output(src, "ls-remote", "origin", "refs/heads/main").split()[0]
    except (ValueError, OSError, IndexError, subprocess.SubprocessError) as exc:
        raise ValueError(f"F95Checker : verification impossible ({exc}).") from exc
    if remote == local:
        return False, "F95Checker : a jour."
    return True, f"F95Checker : nouvelle version disponible ({local[:7]} -> {remote[:7]})."


def _check_updates() -> tuple[bool, bool, list[str]]:
    root = Path(__file__).resolve().parents[2]
    available = failed = False
    lines = []
    for check, target in ((_check_launcher, root), (_check_upstream, root / "F95Checker-src")):
        try:
            found, line = check(target)
            available = available or found
        except ValueError as exc:
            failed = True
            line = str(exc)
        lines.append(line)
    return available, failed, lines


def _spawn_launcher_after_exit(root: Path) -> None:
    """Relance le launcher une fois ce processus termine : tant que F95Checker tourne, le
    verrou d'instance unique ferait quitter la nouvelle instance aussitot."""
    env = dict(os.environ, F95_RESTART_PID=str(os.getpid()))
    # Herite d'un demarrage avec Windows : le launcher se croirait encore en mode silencieux
    env.pop("UPDATE_PROMPT", None)
    if sys.platform == "win32":
        env["F95_RESTART_LAUNCHER"] = str(root / "F95Checker-France.bat")
        script = "Wait-Process -Id $env:F95_RESTART_PID -ErrorAction SilentlyContinue; Start-Process -FilePath $env:F95_RESTART_LAUNCHER"
        cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script]
    else:
        env["F95_RESTART_LAUNCHER"] = str(root / "F95Checker-France.sh")
        script = 'tail --pid="$F95_RESTART_PID" -f /dev/null; exec bash "$F95_RESTART_LAUNCHER"'
        cmd = ["bash", "-c", script]
    subprocess.Popen(
        cmd, env=env, cwd=root,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        start_new_session=sys.platform != "win32",
    )


def _install_updates() -> None:
    from common.structs import MsgBox
    from external import error
    from modules import globals, msgbox, utils

    try:
        _spawn_launcher_after_exit(Path(__file__).resolve().parents[2])
    except Exception:
        utils.push_popup(
            msgbox.msgbox, "F95-France", error.text(), MsgBox.error, more=error.traceback()
        )
        return
    globals.gui.close()


async def check_updates_from_gui() -> None:
    from common.structs import MsgBox
    from external import error
    from modules import icons, msgbox, utils
    global _checking_updates, _last_update_result
    if _checking_updates:
        return
    _checking_updates = True
    _last_update_result = "Verification..."
    try:
        loop = asyncio.get_event_loop()
        available, failed, lines = await loop.run_in_executor(None, _check_updates)
        if available:
            _last_update_result = "Mise a jour disponible"
            lines.append("\nF95Checker va se fermer, se mettre a jour puis redemarrer.")
            buttons = {
                f"{icons.check} Mettre a jour": _install_updates,
                f"{icons.cancel} Plus tard": None,
            }
        else:
            _last_update_result = "Verification incomplete" if failed else "Tout est a jour"
            buttons = True
        utils.push_popup(
            msgbox.msgbox, "F95-France", "\n".join(lines),
            MsgBox.warn if failed else MsgBox.info,
            buttons,
        )
    except Exception:
        _last_update_result = "Erreur"
        utils.push_popup(
            msgbox.msgbox, "F95-France", error.text(), MsgBox.error, more=error.traceback()
        )
    finally:
        _checking_updates = False
# ---------------------------------------------------------------------------
# Traductions F95-France : onglet "F95 France" dans la fiche d'un jeu,
# telechargement a la demande (Mega, Google Drive, kDrive, Pixeldrain)
# puis installation dans le dossier du jeu apres confirmation.
# ---------------------------------------------------------------------------

import base64
import re
import struct
import time
import urllib.parse

_tr_catalog: dict | None = None
_tr_loading = False
_tr_error = ""
_tr_loaded_at = 0.0
_TR_CACHE_SECONDS = 15 * 60
_tr_states: dict[str, str] = {}

_TR_STATUS = {
    "completed": ("Terminee", (0.30, 0.69, 0.31)),
    "in_progress": ("En cours", (1.00, 0.65, 0.15)),
    "abandoned": ("Abandonnee", (0.90, 0.30, 0.30)),
}
_TR_TYPE = {
    "auto": "Automatique",
    "semi-auto": "Semi-automatique",
    "manual": "Manuelle",
    "to_tested": "A tester",
    "vf": "VF officielle",
    "hs": "Hors service",
}
_TR_DOC_SUFFIXES = {".txt", ".md", ".url", ".pdf", ".html", ".htm", ".nfo", ".lnk", ".rtf", ".doc", ".docx"}
_TR_JUNK = {"__macosx", ".ds_store", "thumbs.db", "desktop.ini"}
_TR_RENPY_SUFFIXES = {".rpy", ".rpyc", ".rpa", ".rpym", ".rpymc", ".ttf", ".otf"}


def _api_base() -> str:
    url = _resolve_api_url(load_config())
    return url.rsplit("/games", 1)[0] if "/games" in url else url.rstrip("/")


def _api_get_json(path: str):
    cfg = load_config()
    api_key = cfg["france"].get("api_key", "")
    if not api_key.strip():
        raise ValueError("Cle API F95-France manquante (relancez le launcher pour la configurer).")
    req = urllib.request.Request(
        _api_base() + path,
        headers=_request_headers(api_key, cfg["france"].get("auth_mode", "bearer")),
    )
    try:
        with urllib.request.urlopen(req, timeout=60, context=_SSL_CONTEXT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ValueError(_api_error_message(exc.code, exc.read())) from exc
    except urllib.error.URLError as exc:
        raise ValueError(f"Reseau : {exc.reason}") from exc


def _load_translations_catalog() -> dict:
    games = _api_get_json("/games")
    translations = _api_get_json("/translations")
    try:
        translators = _api_get_json("/translators")
    except ValueError:
        translators = []
    if not isinstance(games, list) or not isinstance(translations, list):
        raise ValueError("Reponse API inattendue.")
    by_thread: dict[tuple[str, int], str] = {}
    for g in games:
        if isinstance(g, dict) and isinstance(g.get("threadId"), (int, float)) and g.get("id"):
            by_thread[(str(g.get("website") or "").lower(), int(g["threadId"]))] = g["id"]
    by_game: dict[str, list[dict]] = {}
    for t in translations:
        if isinstance(t, dict) and t.get("gameId"):
            by_game.setdefault(t["gameId"], []).append(t)
    names = {t["id"]: t.get("name") or "" for t in translators if isinstance(t, dict) and t.get("id")}
    return {"by_thread": by_thread, "by_game": by_game, "translators": names}


async def _refresh_translations_catalog() -> None:
    global _tr_catalog, _tr_loading, _tr_error, _tr_loaded_at
    if _tr_loading:
        return
    _tr_loading = True
    _tr_error = ""
    try:
        loop = asyncio.get_event_loop()
        _tr_catalog = await loop.run_in_executor(None, _load_translations_catalog)
        _tr_loaded_at = time.time()
    except ValueError as exc:
        _tr_error = str(exc)
    except Exception as exc:
        _tr_error = f"Erreur : {exc}"
    finally:
        _tr_loading = False


def _game_translations(game) -> list[dict] | None:
    if _tr_catalog is None:
        return None
    if game.custom:
        if not _is_lc_thread_url(game.url):
            return []
        key = ("lc", _thread_id_from_url(game.url))
    else:
        key = ("f95z", game.id)
    game_id = _tr_catalog["by_thread"].get(key)
    if not game_id:
        return []
    order = {"completed": 0, "in_progress": 1, "abandoned": 2}
    return sorted(
        _tr_catalog["by_game"].get(game_id, []),
        key=lambda t: (t.get("tname") == "integrated", order.get(t.get("status"), 3), t.get("updatedAt") or ""),
    )


def _norm_version(version: str) -> str:
    v = (version or "").strip().lower()
    v = re.sub(r"^(?:version|ver\.?|v)\s*", "", v)
    return re.sub(r"\s+", " ", v)


def _game_version(game) -> tuple[str, str]:
    if game.installed:
        return game.installed, "installee"
    return game.version or "", "derniere"


def _host_of(link: str) -> str:
    host = urllib.parse.urlparse(link or "").netloc.lower()
    return host[4:] if host.startswith("www.") else host


def _direct_kind(link: str) -> str | None:
    if not link:
        return None
    if re.search(r"mega\.nz/(?:file/[\w-]+#[\w-]+|#![\w-]+![\w-]+)", link):
        return "mega"
    if re.search(r"drive\.google\.com/(?:file/d/|open\?id=|uc\?)", link):
        return "gdrive"
    if re.search(r"kdrive\.infomaniak\.com/app/share/\d+/[\w-]+", link):
        return "kdrive"
    if re.search(r"pixeldrain\.com/(?:u|api/file)/\w+", link):
        return "pixeldrain"
    return None


def _b64url(text: str) -> bytes:
    text = text.replace("-", "+").replace("_", "/").replace(",", "")
    return base64.b64decode(text + "=" * (-len(text) % 4))


def _mega_keys(key_b64: str) -> tuple[bytes, bytes]:
    k = struct.unpack(">8I", _b64url(key_b64))
    aes_key = struct.pack(">4I", *(k[i] ^ k[i + 4] for i in range(4)))
    iv = struct.pack(">2I", k[4], k[5]) + b"\0" * 8
    return aes_key, iv


def _mega_decrypt_name(aes_key: bytes, attributes: str) -> str:
    from Cryptodome.Cipher import AES
    raw = AES.new(aes_key, AES.MODE_CBC, b"\0" * 16).decrypt(_b64url(attributes)).rstrip(b"\0")
    if not raw.startswith(b"MEGA"):
        raise ValueError("Cle Mega invalide.")
    return json.loads(raw[4:].decode("utf-8", errors="replace")).get("n") or "traduction"


def _mega_decrypt_file(src: Path, dst: Path, aes_key: bytes, iv: bytes) -> None:
    from Cryptodome.Cipher import AES
    cipher = AES.new(aes_key, AES.MODE_CTR, nonce=b"", initial_value=iv)
    with src.open("rb") as fin, dst.open("wb") as fout:
        while chunk := fin.read(4 * 1024 * 1024):
            fout.write(cipher.decrypt(chunk))


def _filename_from_disposition(value: str) -> str:
    if not value:
        return ""
    if m := re.search(r"filename\*\s*=\s*[^']*''([^;]+)", value, re.IGNORECASE):
        return urllib.parse.unquote(m.group(1).strip().strip('"'))
    if m := re.search(r'filename\s*=\s*"?([^";]+)"?', value, re.IGNORECASE):
        return m.group(1).strip()
    return ""


def _safe_filename(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).strip(" .")
    return name[:150] or "traduction"


async def _resolve_direct_link(link: str) -> dict:
    """Retourne {url, name, size, mega} pour un lien d'hebergeur supporte."""
    from modules import api

    kind = _direct_kind(link)
    if kind == "pixeldrain":
        file_id = re.search(r"pixeldrain\.com/(?:u|api/file)/(\w+)", link).group(1)
        info = json.loads(await api.fetch("GET", f"https://pixeldrain.com/api/file/{file_id}/info", cookies=False))
        return {"url": f"https://pixeldrain.com/api/file/{file_id}?download", "name": info.get("name") or file_id, "size": info.get("size"), "mega": None}

    if kind == "gdrive":
        m = re.search(r"/d/([\w-]+)", link) or re.search(r"[?&]id=([\w-]+)", link)
        url = f"https://drive.usercontent.google.com/download?id={m.group(1)}&export=download&confirm=t"
        async with api.request("GET", url, read=False, cookies=False) as (_, req):
            if "text/html" in (req.headers.get("Content-Type") or ""):
                raise LookupError("Google Drive demande une confirmation manuelle.")
            name = _filename_from_disposition(req.headers.get("Content-Disposition", ""))
            size = req.content_length
        return {"url": url, "name": name or m.group(1), "size": size, "mega": None}

    if kind == "kdrive":
        drive, share = re.search(r"share/(\d+)/([\w-]+)", link).groups()
        base = f"https://kdrive.infomaniak.com/2/app/{drive}/share/{share}"
        init = json.loads(await api.fetch("GET", f"{base}/init", cookies=False))
        file_id = init["data"]["file_id"]
        info = json.loads(await api.fetch("GET", f"{base}/files/{file_id}", cookies=False))["data"]
        name = info.get("name") or str(file_id)
        if info.get("type") == "dir":
            name += ".zip"
        return {"url": f"{base}/files/{file_id}/download", "name": name, "size": info.get("size") if info.get("type") != "dir" else None, "mega": None}

    if kind == "mega":
        m = re.search(r"mega\.nz/file/([\w-]+)#([\w-]+)", link) or re.search(r"mega\.nz/#!([\w-]+)!([\w-]+)", link)
        file_id, key = m.groups()
        aes_key, iv = _mega_keys(key)
        res = json.loads(await api.fetch(
            "POST", "https://g.api.mega.co.nz/cs?id=0",
            json=[{"a": "g", "g": 1, "ssl": 2, "p": file_id}], cookies=False,
        ))
        res = res[0] if isinstance(res, list) else res
        if isinstance(res, int):
            raise LookupError(f"Mega a refuse le lien (erreur {res}), il est peut-etre expire.")
        return {"url": res["g"], "name": _mega_decrypt_name(aes_key, res["at"]), "size": res.get("s"), "mega": (aes_key, iv)}

    raise LookupError("Hebergeur non supporte.")


def _game_root(game) -> Path | None:
    from modules import globals, utils

    base = globals.settings.default_exe_dir.get(globals.os)
    for executable in game.executables:
        if utils.is_uri(executable):
            continue
        exe = Path(executable)
        if not exe.is_absolute() and base:
            exe = Path(base) / exe
        if exe.is_file():
            return exe.parent
        if exe.is_dir():
            return exe.parent if exe.suffix.lower() == ".app" else exe
    return None


def _is_doc(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in _TR_DOC_SUFFIXES


def _children(folder: Path) -> list[Path]:
    return [c for c in folder.iterdir() if c.name.lower() not in _TR_JUNK]


def _plan_install(extracted: Path, game_root: Path, renpy: bool) -> tuple[list[tuple[Path, Path]], str] | None:
    """Determine quoi copier ou dans le dossier du jeu. None si structure non reconnue."""
    root_names = {c.name.lower() for c in game_root.iterdir() if c.is_dir()}
    renpy = renpy or "game" in root_names and (game_root / "renpy").is_dir()

    # Descend dans les dossiers "enveloppe" (FR_Jeu-0.1/...), sans depasser un dossier du jeu (game/, www/...)
    src = extracted
    while True:
        kids = [c for c in _children(src) if not _is_doc(c)]
        if len(kids) == 1 and kids[0].is_dir() and kids[0].name.lower() not in root_names | {"tl"}:
            src = kids[0]
        else:
            break

    # Un dossier de l'archive qui existe aussi a la racine du jeu (game/, www/, Jeu_Data/...)
    level = [src]
    for _ in range(4):
        for folder in level:
            if any(c.is_dir() and c.name.lower() in root_names for c in _children(folder)):
                return [(c, game_root / c.name) for c in _children(folder) if not _is_doc(c)], "racine du jeu"
        level = [c for f in level for c in _children(f) if c.is_dir()]

    # Ren'Py : fichiers de traduction en vrac (.rpa, .rpy, tl/) -> game/
    if renpy:
        kids = [c for c in _children(src) if not _is_doc(c)]
        if kids and all(c.suffix.lower() in _TR_RENPY_SUFFIXES or (c.is_dir() and c.name.lower() == "tl") for c in kids):
            return [(c, game_root / "game" / c.name) for c in kids], "dossier game/"
    return None


def _count_plan(plan: list[tuple[Path, Path]]) -> tuple[int, int]:
    total = replaced = 0
    for src, dst in plan:
        files = [(src, dst)] if src.is_file() else [(f, dst / f.relative_to(src)) for f in src.rglob("*") if f.is_file()]
        for _, target in files:
            total += 1
            replaced += target.exists()
    return total, replaced


def _execute_plan(plan: list[tuple[Path, Path]]) -> int:
    copied = 0
    for src, dst in plan:
        if src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            copied += 1
            continue
        for f in src.rglob("*"):
            if f.is_file() and f.name.lower() not in _TR_JUNK:
                target = dst / f.relative_to(src)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, target)
                copied += 1
    return copied


def _archive_stem_fr(name: str) -> str:
    lower = name.lower()
    for _, extensions, _ in shutil.get_unpack_formats():
        for ext in sorted(extensions, key=len, reverse=True):
            if lower.endswith(ext) and len(name) > len(ext):
                return name[:-len(ext)].rstrip(" .") or name
    return Path(name).stem or name


def _unpack_translation(file: Path) -> Path:
    target = file.parent / _archive_stem_fr(file.name)
    if target.exists():
        shutil.rmtree(target, ignore_errors=True)
    fmt = shutil._find_unpack_format(str(file))
    if fmt:
        shutil.unpack_archive(file, target, fmt)
    else:
        target.mkdir(parents=True)
        shutil.copy2(file, target / file.name)
    return target


def _push_msg(text: str, level=None, buttons=True) -> None:
    from common.structs import MsgBox
    from modules import msgbox, utils
    utils.push_popup(msgbox.msgbox, "Traduction F95-France", text, level or MsgBox.info, buttons)


def _cleanup_translation_files(archive: Path | None, extracted: Path) -> str:
    """Supprime l'archive et/ou le dossier decompresse selon les reglages. Renvoie un resume."""
    done, errors = [], []
    targets = []
    if tr_cleanup_setting("tr_delete_extracted"):
        targets.append(("dossier decompresse", extracted))
    if archive is not None and archive != extracted and tr_cleanup_setting("tr_delete_archive"):
        targets.append(("archive", archive))
    for label, path in targets:
        try:
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            elif path.exists():
                path.unlink()
            else:
                continue
            done.append(label)
        except OSError as exc:
            errors.append(f"{label} : {exc}")
    # Retire "Traduction FR" puis le dossier du jeu s'ils sont devenus vides
    folder = extracted.parent
    for _ in range(2):
        try:
            folder.rmdir()
        except OSError:
            break
        folder = folder.parent
    lines = []
    if done:
        lines.append("Supprime : " + ", ".join(done) + ".")
    if errors:
        lines.append("Suppression impossible :\n" + "\n".join(errors))
    return "\n".join(lines)


def _offer_install(game, translation: dict, extracted: Path, mods_ok: bool = False, archive: Path | None = None) -> None:
    from common.structs import MsgBox
    from external import async_thread
    from modules import callbacks, icons

    open_folder = (f"{icons.folder_open_outline} Ouvrir le dossier", lambda: async_thread.run(callbacks.default_open(str(extracted))))
    if translation.get("tname") == "translation_with_mods" and not mods_ok:
        buttons = {f"{icons.check} Continuer": lambda: _offer_install(game, translation, extracted, mods_ok=True, archive=archive)}
        if link := translation.get("tlink"):
            buttons[f"{icons.open_in_new} Voir la page"] = lambda: callbacks.open_webpage(link)
        buttons[open_folder[0]] = open_folder[1]
        buttons[f"{icons.cancel} Annuler"] = None
        _push_msg(
            "Cette traduction est prevue pour une version du jeu avec des mods.\n\n"
            "Il peut etre necessaire d'installer un ou plusieurs mods pour qu'elle\n"
            "fonctionne correctement (textes manquants ou erreurs sinon).\n"
            "Verifie la page de la traduction ou le fichier A_Lire / readme fourni.",
            MsgBox.warn,
            buttons,
        )
        return
    game_root = _game_root(game)
    if game_root is None:
        def _after_exe(selected):
            if selected:
                _offer_install(game, translation, extracted, mods_ok=True, archive=archive)
        _push_msg(
            f"Traduction telechargee dans :\n{extracted}\n\n"
            "Aucun executable n'est defini pour ce jeu, impossible de savoir ou l'installer.\n"
            "Choisis l'exe du jeu pour continuer, ou installe la traduction a la main.",
            MsgBox.warn,
            {
                f"{icons.open_in_app} Choisir l'exe": lambda: callbacks.add_game_exe(game, _after_exe),
                open_folder[0]: open_folder[1],
                f"{icons.cancel} Annuler": None,
            },
        )
        return

    def _install(plan):
        async def _run():
            try:
                loop = asyncio.get_event_loop()
                copied = await loop.run_in_executor(None, _execute_plan, plan)
            except Exception as exc:
                _push_msg(f"Installation impossible :\n{exc}", MsgBox.error)
                return
            cleaned = await loop.run_in_executor(None, _cleanup_translation_files, archive, extracted)
            _push_msg(f"Traduction installee : {copied} fichier(s) copies dans\n{game_root}" + (f"\n\n{cleaned}" if cleaned else ""))
        async_thread.run(_run())

    plan = _plan_install(extracted, game_root, translation.get("gameType") == "renpy")
    if plan is None:
        src = extracted
        while len(kids := [c for c in _children(src) if not _is_doc(c)]) == 1 and kids[0].is_dir():
            src = kids[0]
        fallback = [(c, game_root / c.name) for c in _children(src) if not _is_doc(c)]
        _push_msg(
            f"Traduction telechargee dans :\n{extracted}\n\n"
            "Structure de la traduction non reconnue : je ne sais pas ou la placer.\n"
            f"Tu peux copier son contenu a la racine du jeu ({game_root}),\n"
            "ou ouvrir le dossier pour l'installer a la main (voir le fichier A_Lire / readme s'il y en a un).",
            MsgBox.warn,
            {
                f"{icons.check} Copier a la racine du jeu": lambda: _install(fallback),
                open_folder[0]: open_folder[1],
                f"{icons.cancel} Annuler": None,
            },
        )
        return

    plan, where = plan
    total, replaced = _count_plan(plan)
    targets = "\n".join(f"  - {dst.relative_to(game_root).as_posix()}{'/' if src.is_dir() else ''}" for src, dst in plan[:8])
    if len(plan) > 8:
        targets += f"\n  - ... (+{len(plan) - 8})"
    _push_msg(
        f"Installer la traduction dans le {where} ?\n\n"
        f"Jeu : {game_root}\n"
        f"{total} fichier(s) a copier, dont {replaced} remplacant des fichiers existants :\n{targets}",
        MsgBox.info,
        {
            f"{icons.check} Installer": lambda: _install(plan),
            open_folder[0]: open_folder[1],
            f"{icons.cancel} Annuler": None,
        },
    )


def _translation_folder(game) -> Path:
    from modules import globals, utils
    downloads_dir = globals.settings.downloads_dir.get(globals.os)
    downloads_dir = Path(downloads_dir) if downloads_dir else Path.home() / "Downloads"
    return downloads_dir / utils.clean_str(game.name)[:32] / "Traduction FR"


async def _finish_download(game, translation: dict, download, final: Path, mega=None) -> None:
    """Dechiffre (Mega), renomme, extrait puis propose l'installation."""
    try:
        download.state = download.State.Extracting
        loop = asyncio.get_event_loop()
        def _finish():
            if download.path != final:
                if final.exists():
                    final.unlink()
                if mega:
                    _mega_decrypt_file(download.path, final, *mega)
                    download.path.unlink()
                else:
                    download.path.rename(final)
                download.path = final
            return _unpack_translation(final)
        download.extracted = await loop.run_in_executor(None, _finish)
        download.total = download.progress  # Taille parfois inconnue a l'avance (kDrive, navigateur)
    except Exception as exc:
        download.error = f"Extraction impossible : {exc}"
        return
    finally:
        download.state = download.State.Stopped
    _offer_install(game, translation, download.extracted, archive=download.path)


async def _download_translation(game, translation: dict) -> None:
    from common.structs import FileDownload
    from modules import api

    tid = translation["id"]
    link = translation.get("tlink") or ""
    if not _direct_kind(link):
        await _browser_download(game, translation)
        return
    _tr_states[tid] = "Recherche du fichier..."
    try:
        info = await _resolve_direct_link(link)
    except Exception:
        # Lien direct qui ne repond pas comme prevu : on passe par le navigateur (sans re-intercepter ce lien)
        _tr_states.pop(tid, None)
        await _browser_download(game, translation, intercept=False)
        return
    _tr_states.pop(tid, None)

    folder = _translation_folder(game)
    name = _safe_filename(info["name"])
    download = FileDownload(f"[FR] {name}", cookies=False, total=info["size"])
    download.path = folder / f"{name}.part"  # .part : download_file() ne doit pas l'extraire lui-meme
    download.path_nest_level = 2
    download.url = info["url"]
    api.downloads[f"fr/{tid}"] = download

    await api.download_file(download)
    if download.error or download.cancel:
        return
    await _finish_download(game, translation, download, folder / name, info["mega"])


async def _browser_download(game, translation: dict, intercept: bool = True) -> None:
    """Ouvre le lien dans le navigateur integre ; des qu'un telechargement demarre,
    la fenetre se reduit et le fichier arrive dans le dossier de traductions du jeu.
    Si la page mene a un hebergeur gere en direct (Mega, Drive...), on bascule dessus."""
    from common.structs import DaemonPipe, FileDownload
    from modules import api, webview

    tid = translation["id"]
    link = translation.get("tlink") or ""
    folder = _translation_folder(game)
    key = f"fr/{tid}"
    download = None
    final = None
    direct = None
    _tr_states[tid] = "Navigateur ouvert : clique sur le bouton de telechargement de la page"
    try:
        with await webview.start(
            "fr_download", link, str(folder), intercept,
            title=f"Traduction FR : {game.name} (le telechargement sera recupere automatiquement)",
            size=(1100, 800),
            extension=False,  # Le script de l'extension casse certains sites (Mega : "redefine property: sleep")
            pipe=True,
        ) as pipe:
            while True:
                if download is not None and download.cancel:
                    pipe.kill()
                    download.error = "Interrompu par l'utilisateur"
                    break
                try:
                    msg = await asyncio.wait_for(pipe.get_async(), timeout=0.5)
                except (asyncio.TimeoutError, TimeoutError):
                    continue
                if not isinstance(msg, list) or not msg:
                    continue
                if msg[0] == "started":
                    _tr_states.pop(tid, None)
                    name = msg[1]
                    download = FileDownload(f"[FR] {name}", cookies=False, total=msg[2] if msg[2] > 0 else None)
                    download.path = folder / name
                    download.path_nest_level = 2
                    download.url = link
                    download.state = download.State.Downloading
                    download.start = download.current = time.time()
                    api.downloads[key] = download
                elif msg[0] == "progress" and download is not None:
                    download.progress = msg[1]
                    if msg[2] > 0:
                        download.total = msg[2]
                    download.current = time.time()
                elif msg[0] == "done" and download is not None:
                    final = Path(msg[1])
                    download.progress = msg[2]
                    download.path = final
                    break
                elif msg[0] == "error":
                    if download is not None:
                        download.error = msg[1]
                    break
                elif msg[0] == "direct" and download is None:
                    direct = msg[1]
                    break
    except DaemonPipe.DaemonPipeExit:
        pass
    finally:
        _tr_states.pop(tid, None)
    if direct:
        await _download_translation(game, {**translation, "tlink": direct})
        return
    if download is None:
        return  # Fenetre fermee sans telechargement
    if final is None:
        download.error = download.error or "Navigateur ferme avant la fin du telechargement"
        download.state = download.State.Stopped
        return
    await _finish_download(game, translation, download, final)


def browser_download_daemon(url: str, target_dir: str, intercept: bool = True, *, cookies: dict[str, str] = {}, cookies_domain: str = None, **kwargs):
    """Processus navigateur (webview-daemon) : recupere le premier telechargement lance par la page."""
    from PyQt6 import QtCore, QtNetwork, QtWebEngineCore
    from modules import webview

    app = webview.create(**kwargs)
    if cookies and cookies_domain:
        domain = QtCore.QUrl("https://" + cookies_domain)
        for key, value in cookies.items():
            app.window.webview.cookieStore.setCookie(
                QtNetwork.QNetworkCookie(QtCore.QByteArray(key.encode()), QtCore.QByteArray(value.encode())), domain
            )
    profile = app.window.webview.profile
    try:
        profile.downloadRequested.disconnect()  # Pas de boite "Enregistrer sous"
    except TypeError:
        pass
    State = QtWebEngineCore.QWebEngineDownloadRequest.DownloadState
    current = {"dl": None, "last": 0.0}

    def progress():
        dl = current["dl"]
        now = time.time()
        if now - current["last"] >= 0.25:
            current["last"] = now
            app.pipe.put(["progress", dl.receivedBytes(), dl.totalBytes()])

    def state_changed(state):
        dl = current["dl"]
        if state == State.DownloadCompleted:
            app.pipe.put(["done", str(Path(dl.downloadDirectory()) / dl.downloadFileName()), dl.receivedBytes()])
            app.quit()
        elif state in (State.DownloadCancelled, State.DownloadInterrupted):
            app.pipe.put(["error", dl.interruptReasonString() or "Telechargement annule"])
            app.quit()

    def requested(dl):
        if current["dl"] is not None:
            dl.cancel()
            return
        Path(target_dir).mkdir(parents=True, exist_ok=True)
        dl.setDownloadDirectory(target_dir)
        dl.setDownloadFileName(_safe_filename(dl.downloadFileName()))
        current["dl"] = dl
        dl.receivedBytesChanged.connect(progress)
        dl.stateChanged.connect(state_changed)
        dl.accept()
        app.pipe.put(["started", dl.downloadFileName(), dl.totalBytes()])
        app.window.showMinimized()

    profile.downloadRequested.connect(requested)

    def url_changed(new_url):
        target = new_url.toString()
        if intercept and current["dl"] is None and _direct_kind(target):
            app.pipe.put(["direct", target])
            app.quit()
    app.window.webview.urlChanged.connect(url_changed)
    app.window.webview.setUrl(QtCore.QUrl(url))
    app.window.show()
    app.exec()


def _start_translation_download(game, translation: dict) -> None:
    from external import async_thread
    from modules import icons

    wanted = _norm_version(translation.get("version") or "")
    current, _ = _game_version(game)
    def _go():
        async_thread.run(_download_translation(game, translation))
    if wanted and current and wanted != _norm_version(current):
        _push_msg(
            f"Cette traduction est prevue pour la version {translation.get('version')} du jeu,\n"
            f"mais ton jeu est en version {current}.\n\n"
            "Elle peut ne pas fonctionner (textes manquants, erreurs). Telecharger quand meme ?",
            None,
            {f"{icons.download} Telecharger quand meme": _go, f"{icons.cancel} Annuler": None},
        )
    else:
        _go()


def draw_translations_tab(game) -> None:
    import imgui
    from external import async_thread
    from modules import api, callbacks, icons

    icon = getattr(icons, "translate", "")
    if not imgui.begin_tab_item(f"{icon} F95 France###f95france")[0]:
        return
    try:
        imgui.spacing()
        if (_tr_catalog is None or time.time() - _tr_loaded_at > _TR_CACHE_SECONDS) and not _tr_loading and not _tr_error:
            async_thread.run(_refresh_translations_catalog())
        if _tr_catalog is None:
            if _tr_error:
                imgui.text_colored(_tr_error, 0.9, 0.3, 0.3)
                if imgui.small_button(f"{icons.refresh} Reessayer"):
                    globals_reset_error()
            else:
                imgui.text_disabled("Chargement des traductions F95-France...")
            return
        translations = _game_translations(game)
        current, current_kind = _game_version(game)
        imgui.text_disabled(f"Version du jeu ({current_kind}) : {current or '?'}")
        imgui.same_line()
        if imgui.small_button(f"{icons.refresh}###fr_refresh"):
            globals_reset_error()
            async_thread.run(_refresh_translations_catalog())
        if not translations:
            imgui.spacing()
            imgui.text_disabled("Aucune traduction F95-France pour ce jeu.")
            return
        for t in translations:
            tid = t["id"]
            imgui.spacing()
            imgui.separator()
            imgui.spacing()
            translator = _tr_catalog["translators"].get(t.get("translatorId"), "")
            title = t.get("translationName") or ("Traduction integree au jeu" if t.get("tname") == "integrated" else "Traduction francaise")
            if t.get("tname") == "translation_with_mods":
                title += " + mods"
            imgui.push_font(imgui.fonts.bold)
            imgui.text(title)
            imgui.pop_font()
            if translator:
                imgui.same_line()
                imgui.text_disabled(f"par {translator}")
            status, color = _TR_STATUS.get(t.get("status"), (t.get("status") or "?", (0.7, 0.7, 0.7)))
            imgui.text_colored(status, *color)
            imgui.same_line()
            imgui.text_disabled(f"| {_TR_TYPE.get(t.get('ttype'), t.get('ttype') or '?')}")

            wanted = t.get("version") or ""
            imgui.text(f"Pour la version du jeu : {wanted or '?'}")
            if t.get("tversion") and t.get("tversion") != wanted and t.get("tname") != "integrated":
                imgui.same_line()
                imgui.text_disabled(f"(traduction {t['tversion']})")
            if wanted and current:
                imgui.same_line()
                if _norm_version(wanted) == _norm_version(current):
                    imgui.text_colored(f"{icons.check} correspond a ton jeu", 0.30, 0.69, 0.31)
                else:
                    imgui.text_colored(f"{getattr(icons, 'alert', '!')} differente de ton jeu ({current})", 1.0, 0.65, 0.15)

            link = t.get("tlink") or ""
            if t.get("tname") == "integrated" or not link:
                continue
            kind = _direct_kind(link)
            busy = _tr_states.get(tid) or (
                (dl := api.downloads.get(f"fr/{tid}")) and dl.state not in (dl.State.Stopped, dl.State.Removed)
            )
            if busy:
                imgui.push_disabled()
            if imgui.button(f"{icons.download} Telecharger###fr_dl_{tid}"):
                _start_translation_download(game, t)
            if busy:
                imgui.pop_disabled()
            elif not kind:
                imgui.same_line()
                imgui.text_disabled("(?)")
                if imgui.is_item_hovered():
                    imgui.set_tooltip(
                        "Cet hebergeur ne permet pas le telechargement direct.\n"
                        "Une fenetre de navigateur s'ouvre : clique sur le bouton de telechargement\n"
                        "de la page, F95Checker recupere le fichier automatiquement."
                    )
            imgui.same_line()
            if imgui.button(f"{icons.open_in_new}###fr_open_{tid}"):
                callbacks.open_webpage(link)
            if imgui.is_item_hovered():
                imgui.set_tooltip("Ouvrir dans ton navigateur habituel")
            imgui.same_line()
            if imgui.button(f"{icons.content_copy}###fr_copy_{tid}"):
                callbacks.clipboard_copy(link)
            if imgui.is_item_hovered():
                imgui.set_tooltip("Copier le lien")
            imgui.same_line()
            imgui.text_disabled(_host_of(link) + ("" if kind else " (via navigateur)"))
            if busy:
                imgui.text_disabled(_tr_states.get(tid) or "Telechargement en cours (voir la barre laterale)")
    finally:
        imgui.end_tab_item()


def globals_reset_error() -> None:
    global _tr_error, _tr_loaded_at
    _tr_error = ""
    _tr_loaded_at = 0.0


# ---------------------------------------------------------------------------
# Rangement des dossiers de jeux : <dossier des jeux>/<Nom du jeu>/<dossier actuel>
# (meme convention que les telechargements Donor DDL)
# ---------------------------------------------------------------------------

_reorg_busy = False
_reorg_journal: Path | None | bool = False  # False = pas encore cherche


def _reorg_journal_dir() -> Path:
    return _config_paths()[0].parent


def _last_reorg_journal() -> Path | None:
    global _reorg_journal
    if _reorg_journal is False:
        files = sorted(
            p for p in _reorg_journal_dir().glob("rangement-*.json") if not p.name.endswith(".annule.json")
        ) if _reorg_journal_dir().is_dir() else []
        _reorg_journal = files[-1] if files else None
    return _reorg_journal


def _reorg_container_name(game) -> str:
    from modules import utils
    # Comme le Donor DDL (clean_str()[:32]) ; Windows retire de toute facon les espaces finaux
    return utils.clean_str(game.name)[:32].rstrip()


def _rel_exe_parts(exe: str, base: Path) -> tuple[str, ...] | None:
    p = Path(exe)
    if p.is_absolute():
        try:
            p = p.relative_to(base)
        except ValueError:
            return None
    return p.parts


CONFLICTS_DIR = "___CONFLICTS___"
IGNORED_DIR = "___IGNORED___"


def _self_root() -> Path:
    # Dossier du launcher : contient F95Checker-src et ._f95_france_cache
    return Path(__file__).resolve().parents[2]


def _contains(folder: Path, path: Path) -> bool:
    """Vrai si `folder` est `path` ou l'un de ses parents."""
    try:
        folder = folder.resolve()
        path = path.resolve()
    except OSError:
        return True  # Dans le doute, on ne touche a rien
    norm = lambda p: os.path.normcase(str(p))
    return norm(folder) in {norm(path), *(norm(p) for p in path.parents)}


def _same_dir(a: Path, b: Path) -> bool:
    try:
        return a.exists() and b.exists() and os.path.samefile(a, b)
    except OSError:
        return False


def _plan_reorganize(base: Path, games: list) -> dict:
    from modules import utils
    skipped: list[tuple[str, str]] = []
    by_top: dict[str, dict] = {}  # dossier de 1er niveau -> {game_ids, depths}
    for game in games:
        for exe in game.executables:
            if utils.is_uri(exe):
                continue
            parts = _rel_exe_parts(exe, base)
            if parts is None:
                skipped.append((f"{game.name} : {exe}", "hors du dossier des jeux, ignore"))
                continue
            if len(parts) < 2:
                skipped.append((f"{game.name} : {exe}", "exe directement a la racine du dossier des jeux"))
                continue
            if not (base.joinpath(*parts)).exists():
                skipped.append((f"{game.name} : {exe}", "exe introuvable"))
                continue
            info = by_top.setdefault(parts[0], {"games": {}, "depths": []})
            info["games"][game.id] = game
            info["depths"].append(len(parts))

    tops_lower = {t.lower() for t in by_top}
    moves: list[dict] = []
    conflicts: list[dict] = []  # Dossiers de jeux non rangeables : deplacables dans ___CONFLICTS___
    already = 0
    containers: dict[str, int] = {}  # nom de dossier (minuscules) -> id du jeu qui l'utilise
    self_root = _self_root()

    def conflict(top: str, info: dict, reason: str) -> None:
        target = base / CONFLICTS_DIR / top
        if target.exists():
            skipped.append((top, f"{reason} ; deja present dans {CONFLICTS_DIR}"))
            return
        skipped.append((top, reason))
        conflicts.append({
            "game_ids": sorted(info["games"]),
            "game": ", ".join(sorted(g.name for g in info["games"].values())),
            "old": top,
            "new": f"{CONFLICTS_DIR}/{top}",
            "reason": reason,
        })

    for top, info in sorted(by_top.items(), key=lambda kv: kv[0].lower()):
        if top.lower() in (CONFLICTS_DIR.lower(), IGNORED_DIR.lower()):
            continue  # Dossiers des conflits / ignores : jamais ranges
        if _contains(base / top, self_root):
            skipped.append((top, "contient F95Checker, jamais deplace"))
            continue
        if len(info["games"]) > 1:
            names = ", ".join(sorted(g.name for g in info["games"].values()))
            conflict(top, info, f"dossier partage par plusieurs jeux ({names})")
            continue
        game = next(iter(info["games"].values()))
        clean = _reorg_container_name(game)
        if not clean:
            conflict(top, info, f"nom de jeu vide une fois nettoye ({game.name})")
            continue
        nested = [d >= 3 for d in info["depths"]]
        if top == clean and all(nested):
            already += 1
            containers[clean.lower()] = game.id
            continue
        if top == clean and any(nested):
            conflict(top, info, "structure mixte (exes a plusieurs niveaux)")
            continue
        owner = containers.get(clean.lower())
        if owner is not None and owner != game.id:
            conflict(top, info, f"un autre jeu utilise deja le dossier \"{clean}\"")
            continue
        container = base / clean
        in_place = top == clean or _same_dir(container, base / top)
        if not in_place and container.exists():
            if not container.is_dir():
                conflict(top, info, f"\"{clean}\" existe deja et n'est pas un dossier")
                continue
            other = by_top.get(clean) or next((v for k, v in by_top.items() if k.lower() == clean.lower()), None)
            if other is not None and (set(other["games"]) != {game.id} or not all(d >= 3 for d in other["depths"])):
                conflict(top, info, f"le dossier \"{clean}\" existe deja et appartient a un autre jeu")
                continue
            if other is None:
                # Dossier sans jeu (ignore) : on ne fusionne jamais dedans
                conflict(top, info, f"un dossier ignore porte deja le nom \"{clean}\"")
                continue
        if (container / top).exists() and not in_place:
            conflict(top, info, f"\"{clean}/{top}\" existe deja")
            continue
        containers[clean.lower()] = game.id
        moves.append({"game_id": game.id, "game": game.name, "old": top, "new": f"{clean}/{top}"})

    planned = set(containers) | {CONFLICTS_DIR.lower(), IGNORED_DIR.lower()}
    orphans: list[dict] = []  # Dossiers sans jeu : deplacables dans ___IGNORED___
    for d in sorted(base.iterdir(), key=lambda p: p.name.lower()) if base.is_dir() else []:
        if d.is_dir() and not d.name.startswith(".") and d.name.lower() not in tops_lower and d.name.lower() not in planned:
            if _contains(d, self_root):
                skipped.append((d.name, "contient F95Checker, jamais deplace"))
            elif (base / IGNORED_DIR / d.name).exists():
                skipped.append((d.name, f"aucun jeu de F95Checker ne pointe dessus ; deja present dans {IGNORED_DIR}"))
            else:
                skipped.append((d.name, "aucun jeu de F95Checker ne pointe dessus"))
                orphans.append({"kind": "ignored", "game_ids": [], "old": d.name, "new": f"{IGNORED_DIR}/{d.name}"})
    for c in conflicts:
        c["kind"] = "conflict"
    return {"moves": moves, "conflicts": conflicts, "orphans": orphans, "skipped": skipped, "already": already}


def _move_dir(base: Path, old: str, new: str) -> None:
    """Deplace base/old vers base/new (new = <conteneur>/<nom>), y compris quand le conteneur est old lui-meme."""
    import time
    src, dst = base.joinpath(*Path(old).parts), base.joinpath(*Path(new).parts)
    container = dst.parent
    if not src.is_dir():
        raise OSError(f"dossier introuvable : {src}")
    if _contains(src, _self_root()):
        raise OSError("ce dossier contient F95Checker, il n'est jamais deplace")
    if container == base:
        # Annulation : on sort le dossier de son conteneur
        old_container = src.parent
        if _same_dir(dst, old_container):  # Le dossier portait le nom du conteneur
            tmp = base / f".rangement-{int(time.time() * 1000)}"
            src.rename(tmp)
            try:
                old_container.rmdir()
            except OSError:
                tmp.rename(src)
                raise
            tmp.rename(dst)
            return
        if dst.exists():
            raise OSError(f"la cible existe deja : {dst}")
        src.rename(dst)
        try:
            old_container.rmdir()  # Conteneur vide : on le retire
        except OSError:
            pass
        return
    if _same_dir(container, src):
        # Le dossier porte deja le nom du conteneur : on passe par un nom temporaire
        tmp = base / f".rangement-{int(time.time() * 1000)}"
        src.rename(tmp)
        try:
            container.mkdir()
            tmp.rename(dst)
        except OSError:
            try:
                container.rmdir()
            except OSError:
                pass
            tmp.rename(src)
            raise
        return
    if dst.exists():
        raise OSError(f"la cible existe deja : {dst}")
    created = not container.exists()
    container.mkdir(exist_ok=True)
    try:
        src.rename(dst)
    except OSError:
        if created:
            try:
                container.rmdir()
            except OSError:
                pass
        raise


def _execute_moves(base: Path, moves: list[dict], reverse: bool = False) -> tuple[list[dict], list[str]]:
    done, errors = [], []
    for m in (reversed(moves) if reverse else moves):
        old, new = (m["new"], m["old"]) if reverse else (m["old"], m["new"])
        try:
            _move_dir(base, old, new)
            done.append(m)
        except OSError as exc:
            errors.append(f"{old} : {exc}")
    return done, errors


async def _rebase_executables(base: Path, moves: list[dict], reverse: bool = False) -> None:
    from modules import db, globals, utils
    for m, game_id in ((m, gid) for m in moves for gid in (m["game_ids"] if "game_ids" in m else [m["game_id"]])):
        game = globals.games.get(game_id)
        if game is None:
            continue
        old, new = (m["new"], m["old"]) if reverse else (m["old"], m["new"])
        old_parts = Path(old).parts
        changed = False
        for i, exe in enumerate(game.executables):
            if utils.is_uri(exe):
                continue
            parts = _rel_exe_parts(exe, base)
            if parts and tuple(p.lower() for p in parts[:len(old_parts)]) == tuple(p.lower() for p in old_parts):
                game.executables[i] = Path(new, *parts[len(old_parts):]).as_posix()
                changed = True
        if changed:
            await db.update_game(game, "executables")
            game.validate_executables()


def _reorg_msg(text: str, level=None, buttons=True, more: str = None) -> None:
    from common.structs import MsgBox
    from modules import msgbox, utils
    utils.push_popup(msgbox.msgbox, "Rangement des jeux", text, level or MsgBox.info, buttons, more=more)


def _reorg_base() -> Path | None:
    from modules import globals
    base = globals.settings.default_exe_dir.get(globals.os)
    return Path(base) if base else None


async def reorganize_preview() -> None:
    global _reorg_busy
    from common.structs import MsgBox
    from external import async_thread
    from modules import globals, icons

    base = _reorg_base()
    if base is None or not base.is_dir():
        _reorg_msg("Definis d'abord le dossier par defaut des exes (Settings > Executables).", MsgBox.warn)
        return
    _reorg_busy = True
    try:
        plan = await asyncio.get_event_loop().run_in_executor(None, _plan_reorganize, base, list(globals.games.values()))
    except Exception as exc:
        _reorg_msg(f"Analyse impossible :\n{exc}", MsgBox.error)
        return
    finally:
        _reorg_busy = False
    moves, conflicts, orphans, skipped = plan["moves"], plan["conflicts"], plan["orphans"], plan["skipped"]
    special = {c["old"] for c in conflicts} | {o["old"] for o in orphans}
    details = []
    if moves:
        details.append(f"A RANGER ({len(moves)})")
        details += [f"  {m['old']}  ->  {m['new']}" for m in moves]
    if conflicts:
        details.append(f"\nCONFLITS ({len(conflicts)}) : deplacables dans {CONFLICTS_DIR} (option)")
        details += [f"  {c['old']}  :  {c['reason']}" for c in conflicts]
    if orphans:
        details.append(f"\nSANS JEU ({len(orphans)}) : deplacables dans {IGNORED_DIR} (option)")
        details += [f"  {o['old']}" for o in orphans]
    others = [(label, reason) for label, reason in skipped if label not in special]
    if others:
        details.append(f"\nAUTRES IGNORES ({len(others)})")
        details += [f"  {label}  :  {reason}" for label, reason in others]
    text = (
        f"Dossier des jeux : {base}\n\n"
        f"{len(moves)} dossier(s) a ranger dans <Nom du jeu>/<dossier actuel>.\n"
        f"{plan['already']} deja range(s), {len(skipped)} dossier(s) ignore(s)"
        + (f", dont {len(conflicts)} en conflit" if conflicts else "")
        + (f" et {len(orphans)} sans jeu" if orphans else "")
        + "."
    )
    if not moves and not conflicts and not orphans:
        _reorg_msg(text + "\n\nRien a ranger.", MsgBox.info, more="\n".join(details) or None)
        return
    _reorg_preview_popup(base, text, "\n".join(details), moves, conflicts, orphans)


def _reorg_preview_popup(base: Path, text: str, details: str, moves: list, conflicts: list, orphans: list) -> None:
    import imgui
    from external import async_thread
    from modules import globals, icons, utils

    opts = {"conflicts": False, "orphans": False}

    def content():
        imgui.text(text)
        imgui.spacing()
        if conflicts:
            _, opts["conflicts"] = imgui.checkbox(
                f"Deplacer aussi les {len(conflicts)} dossier(s) en conflit dans {CONFLICTS_DIR}###reorg_conflicts",
                opts["conflicts"],
            )
        if orphans:
            _, opts["orphans"] = imgui.checkbox(
                f"Deplacer aussi les {len(orphans)} dossier(s) sans jeu dans {IGNORED_DIR}###reorg_orphans",
                opts["orphans"],
            )
        imgui.spacing()
        imgui.text("Les chemins des exes seront mis a jour. Un journal permet d'annuler.\n"
                   "Ferme les jeux en cours avant de continuer.")
        imgui.spacing()
        size = imgui.io.display_size
        try:
            imgui.push_font(imgui.fonts.mono_sm)
            pushed = True
        except Exception:
            pushed = False
        imgui.input_text_multiline(
            "###reorg_details", details,
            width=min(globals.gui.scaled(900), size.x * 0.8),
            height=min(globals.gui.scaled(350), size.y * 0.45),
            flags=imgui.INPUT_TEXT_READ_ONLY,
        )
        if pushed:
            imgui.pop_font()

    def apply():
        selected = list(moves)
        if opts["conflicts"]:
            selected += conflicts
        if opts["orphans"]:
            selected += orphans
        if selected:
            async_thread.run(_reorganize_apply(base, selected))

    utils.push_popup(
        utils.popup, "Rangement des jeux", content,
        buttons={f"{icons.check} Ranger": apply, f"{icons.cancel} Annuler": None},
        closable=True, outside=False,
    )


async def _reorganize_apply(base: Path, moves: list[dict]) -> None:
    global _reorg_busy, _reorg_journal
    import time
    from common.structs import MsgBox
    _reorg_busy = True
    try:
        done, errors = await asyncio.get_event_loop().run_in_executor(None, _execute_moves, base, moves)
        if done:
            journal = _reorg_journal_dir() / f"rangement-{time.strftime('%Y%m%d-%H%M%S')}.json"
            journal.parent.mkdir(parents=True, exist_ok=True)
            journal.write_text(json.dumps({"base": str(base), "moves": done}, indent=1, ensure_ascii=False), encoding="utf-8")
            _reorg_journal = journal
            await _rebase_executables(base, done)
    finally:
        _reorg_busy = False
    moved_conflicts = sum(1 for m in done if m.get("kind") == "conflict")
    moved_orphans = sum(1 for m in done if m.get("kind") == "ignored")
    text = f"{len(done) - moved_conflicts - moved_orphans} dossier(s) range(s)."
    if moved_conflicts:
        text += f"\n{moved_conflicts} dossier(s) en conflit deplace(s) dans {CONFLICTS_DIR}."
    if moved_orphans:
        text += f"\n{moved_orphans} dossier(s) sans jeu deplace(s) dans {IGNORED_DIR}."
    if errors:
        text += f"\n{len(errors)} echec(s) (jeu ouvert, fichier verrouille...) : voir le detail."
    _reorg_msg(text, MsgBox.warn if errors else MsgBox.info, more="\n".join(errors) or None)


async def reorganize_undo() -> None:
    global _reorg_busy, _reorg_journal
    from common.structs import MsgBox
    journal = _last_reorg_journal()
    base = _reorg_base()
    if journal is None or base is None:
        return
    _reorg_busy = True
    try:
        moves = json.loads(journal.read_text(encoding="utf-8"))["moves"]
        done, errors = await asyncio.get_event_loop().run_in_executor(None, _execute_moves, base, moves, True)
        await _rebase_executables(base, done, reverse=True)
        if not errors:
            journal.rename(journal.with_name(journal.stem + ".annule.json"))
            _reorg_journal = False
    except Exception as exc:
        _reorg_msg(f"Annulation impossible :\n{exc}", MsgBox.error)
        return
    finally:
        _reorg_busy = False
    text = f"{len(done)} dossier(s) remis a leur place."
    if errors:
        text += f"\n{len(errors)} echec(s) : voir le detail. Le journal est conserve."
    _reorg_msg(text, MsgBox.warn if errors else MsgBox.info, more="\n".join(errors) or None)


def draw_reorganize_settings(draw_settings_label, right_width) -> None:
    import imgui
    from common.structs import MsgBox
    from external import async_thread
    from modules import icons

    draw_settings_label(
        "Ranger les dossiers de jeux",
        "Range chaque jeu dans <dossier des jeux>/<Nom du jeu>/<dossier actuel>,\n"
        "comme les telechargements Donor DDL, et met a jour les chemins des exes.\n"
        "Un apercu s'affiche avant tout deplacement.",
    )
    if _reorg_busy:
        imgui.push_disabled()
    if imgui.button("Apercu###fr_reorg_preview", width=right_width):
        async_thread.run(reorganize_preview())
    if _reorg_busy:
        imgui.pop_disabled()
    journal = _last_reorg_journal()
    if journal is not None:
        draw_settings_label("Annuler le dernier rangement", f"Journal : {journal}")
        if _reorg_busy:
            imgui.push_disabled()
        if imgui.button("Annuler###fr_reorg_undo", width=right_width):
            _reorg_msg(
                "Remettre les dossiers du dernier rangement a leur place d'origine ?",
                MsgBox.warn,
                {
                    f"{icons.check} Annuler le rangement": lambda: async_thread.run(reorganize_undo()),
                    f"{icons.cancel} Fermer": None,
                },
            )
        if _reorg_busy:
            imgui.pop_disabled()

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
import time
from pathlib import Path

LC_HOST_MARKER = "lewdcorner.com"
_THREAD_RE = re.compile(r"threads/(?:([^./]*)\.)?(\d+)")
# Jeux dont la verification a echoue en 403 pendant le refresh en cours, signales
# en une seule popup par report_session_expired() a la fin de api.refresh()
_session_expired_games: list[str] = []
# Autres echecs (502, timeout...) regroupes par message d'erreur, meme principe
_failed_games: dict[str, list[str]] = {}
# Debit des refresh LC : sans limite, aiohttp ouvre jusqu'a 100 connexions d'un coup,
# ce qui fait bannir l'IP (surtout une IP VPN partagee) par l'anti-flood du site
_LC_MAX_CONCURRENT = 2
_LC_REQUEST_DELAY = 1.0
_lc_sem = None
# Erreur bloquante (403/429/5xx) rencontree pendant le refresh en cours : les jeux
# restants ne sont plus demandes, pour ne pas insister sur un site qui refuse
_lc_abort_error: str | None = None
LC_LOGIN_SNOOZE = 24 * 60 * 60
_lc_remaining = 0
_session_expired_reason = ""
_status_login = False
_status_session = False
_status_challenge = False
# Cloudflare refuse aiohttp sur certains systemes (defi 403 meme avec des cookies valides) :
# des le premier refus, les requetes LC passent par un WebEngine masque jusqu'a la fermeture
_browser_mode = False
_browser_pipe = None
_browser_lock = None
_browser_seq = 0
_BROWSER_BASE_URL = f"https://{LC_HOST_MARKER}/robots.txt"
_BROWSER_HOSTS = (LC_HOST_MARKER, f"www.{LC_HOST_MARKER}")
_BROWSER_LINE_LIMIT = 64 * 1024 * 1024
_BROWSER_TIMEOUT = 40
_BROWSER_CHALLENGE_TIMEOUT = 5 * 60
_BROWSER_CHALLENGE_GRACE_MS = 20 * 1000
_BROWSER_FOCUS_POLL = 0.5
_BROWSER_IDLE_MS = 2 * 60 * 1000
# Liste des dernieres mises a jour (page Latest Updates V2) : evite une requete par jeu a
# chaque refresh : LewdCorner est strict, seul un Full Refresh manuel demande toutes les pages.
# La marge couvre aussi son tri, pas strictement chronologique.
_LC_UPDATES_URL = f"https://{LC_HOST_MARKER}/latest-updates/api?view=all&sort=date&cat=All&tier=All&per_page=60&page="
_LC_UPDATES_MAX_PAGES = 20
_LC_FIRST_LOOKBACK = 30 * 24 * 60 * 60
_LC_FEED_MARGIN = 60 * 60
_feed_state_pending: dict | None = None
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


def _login_dismissed_path() -> Path:
    return _cookies_path().with_name("lc_login_dismissed.txt")


def _is_login_snoozed() -> bool:
    """L'utilisateur a ferme la fenetre de connexion automatique il y a moins de LC_LOGIN_SNOOZE."""
    try:
        return time.time() - float(_login_dismissed_path().read_text(encoding="utf-8")) < LC_LOGIN_SNOOZE
    except (OSError, ValueError):
        return False


def _snooze_login() -> None:
    path = _login_dismissed_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(time.time()), encoding="utf-8")


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
    # Fenetre fermee sans connexion : garder la session actuelle plutot que l'ecraser
    if "xf_user" not in new_cookies:
        return False
    _save_lc_cookies(new_cookies)
    _login_dismissed_path().unlink(missing_ok=True)
    _close_browser()
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
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
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
    global _browser_mode
    from modules import api

    if _browser_mode and _browser_can_fetch(url):
        return await _fetch_page_browser(url)
    cookies = _load_lc_cookies() if is_lc_url(url) else False
    try:
        async with api.request("GET", url, cookies=cookies, timeout=30, headers=_LC_BROWSER_HEADERS) as (res, req):
            if _is_cf_challenge(req.status, req.headers.get("cf-mitigated")) and _browser_can_fetch(url):
                _browser_mode = True
                return await _fetch_page_browser(url)
            if req.status >= 400:
                return None, _http_error(req.status, res)
            return res, None
    except Exception as exc:
        return None, (f"{type(exc).__name__}: {exc}" if str(exc) else type(exc).__name__)


def _http_error(status: int, body: bytes) -> str:
    if status == 403 and b"required reading" in body.lower():
        # LewdCorner bloque tout le site (meme la home) tant qu'un sujet marque
        # "lecture obligatoire" par le staff n'a pas ete ouvert une fois par ce
        # compte, dans un vrai navigateur. Le compte est bien connecte : ca n'a
        # rien a voir avec Cloudflare ni avec des cookies perimes.
        return "REQUIRED_READING"
    return f"HTTP {status}"


def _is_cf_challenge(status: int, mitigated: str | None) -> bool:
    return status == 403 and mitigated == "challenge"


def _browser_can_fetch(url: str) -> bool:
    """Le fetch() du navigateur masque ne peut lire que sa propre origine."""
    from urllib.parse import urlsplit

    return (urlsplit(url).hostname or "").lower() in _BROWSER_HOSTS


def _close_browser() -> None:
    global _browser_pipe
    if _browser_pipe:
        _browser_pipe.kill()
        _browser_pipe = None


def _remember_browser_cookie(name: str, value: str) -> None:
    cookies = _load_lc_cookies()
    if cookies.get(name) != value:
        cookies[name] = value
        _save_lc_cookies(cookies)


async def _start_browser():
    import asyncio
    import shlex
    from common.structs import DaemonPipe
    from modules import globals, webview

    kwargs = webview.create_kwargs() | dict(
        title="F95Checker: Verification LewdCorner",
        size=(500, 720),
        buttons=False,
        extension=False,
        private=True,
    )
    proc = await asyncio.create_subprocess_exec(
        *shlex.split(globals.daemon_cmd or globals.start_cmd),
        "webview-daemon",
        json.dumps(["lc_browser"]),
        json.dumps(kwargs),
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        # Une ligne contient une page entiere (64 Ko par defaut)
        limit=_BROWSER_LINE_LIMIT,
    )
    pipe = DaemonPipe(proc)
    # Par le pipe et non en argument : la ligne de commande est visible des autres processus
    pipe.put({"cookies": _load_lc_cookies()})
    return pipe


def _main_window_active() -> bool:
    from modules import globals

    gui = globals.gui
    return bool(gui.focused) and not gui.hidden and not gui.minimized


async def _wait_for_main_window() -> bool:
    """Attend que l'utilisateur revienne sur F95Checker. False si l'application est masquee."""
    import asyncio
    from modules import globals

    while not globals.gui.hidden:
        if _main_window_active():
            return True
        await asyncio.sleep(_BROWSER_FOCUS_POLL)
    return False


async def _browser_exchange(request: dict) -> dict:
    import asyncio

    global _browser_pipe, _status_challenge
    if not _browser_pipe or not await _browser_pipe.is_alive():
        _browser_pipe = await _start_browser()
    _browser_pipe.put(request)
    timeout = _BROWSER_TIMEOUT
    waiting_for_user = False
    next_message = None
    try:
        while True:
            # Pas de wait_for pendant l'attente : l'annuler chaque seconde pourrait perdre une ligne
            next_message = next_message or asyncio.ensure_future(_browser_pipe.get_async())
            done, _ = await asyncio.wait({next_message}, timeout=_BROWSER_FOCUS_POLL if waiting_for_user else timeout)
            if not done:
                if not waiting_for_user:
                    raise TimeoutError
                if _main_window_active():
                    waiting_for_user = False
                    timeout = _BROWSER_CHALLENGE_TIMEOUT + _BROWSER_TIMEOUT
                    _browser_pipe.put({"reveal": True})
                continue
            message = next_message.result()
            next_message = None
            if not isinstance(message, dict):
                continue
            if "cookie" in message:
                _remember_browser_cookie(*message["cookie"])
            elif "challenge" in message:
                _status_challenge = message["challenge"]
                timeout = _BROWSER_CHALLENGE_TIMEOUT + _BROWSER_TIMEOUT
                waiting_for_user = message["challenge"] == "user"
            elif message.get("id") == request["id"]:
                return message
    finally:
        if next_message:
            next_message.cancel()
        _status_challenge = False


async def _browser_fetch(url: str, follow_redirects: bool = True) -> dict:
    """Requete via le WebEngine masque. Renvoie la reponse du sous-processus, ou {"error": ...}."""
    import asyncio
    import base64
    from common.structs import DaemonPipe
    from modules import globals

    global _browser_lock, _browser_seq
    if _browser_lock is None:
        _browser_lock = asyncio.Lock()
    async with _browser_lock:
        _browser_seq += 1
        request = {
            "id": _browser_seq,
            "url": url,
            "follow": follow_redirects,
            # F95Checker en arriere-plan : pas de fenetre surprise, comme lc_login
            "interactive": not globals.gui.hidden,
        }
        # Le sous-processus peut avoir quitte pour inactivite juste avant cette requete
        for attempt in range(2):
            try:
                result = await _browser_exchange(request)
                break
            except DaemonPipe.DaemonPipeExit:
                _close_browser()
                if attempt:
                    return {"error": "navigateur LewdCorner arrete de facon inattendue"}
            except Exception as exc:
                _close_browser()
                return {"error": f"{type(exc).__name__}: {exc}" if str(exc) else type(exc).__name__}
    if result.get("error"):
        return result
    return result | {"body": base64.b64decode(result.get("body") or "")}


async def _fetch_page_browser(url: str) -> tuple[bytes | None, str | None]:
    result = await _browser_fetch(url)
    if err := result.get("error"):
        return None, err
    if _is_cf_challenge(result["status"], result.get("mitigated")):
        return None, "CLOUDFLARE_CHALLENGE"
    if result["status"] >= 400:
        return None, _http_error(result["status"], result["body"])
    return result["body"], None


def browser_daemon(**kwargs) -> None:
    """Sous-processus : garde une page LewdCorner legere ouverte et y execute les requetes
    avec fetch(), donc avec le reseau et les cookies du navigateur, sans charger les scripts
    et images de chaque page. Un defi Cloudflare est d'abord tente hors ecran (une page jamais
    affichee est gelee par Chromium), et seul un defi qui demande une action apparait, quand
    l'utilisateur revient sur F95Checker."""
    import sys
    import threading

    from PyQt6 import QtCore, QtNetwork
    from modules import webview

    app = webview.create(**kwargs)
    app.setQuitOnLastWindowClosed(False)
    window = app.window
    view = window.webview
    pipe = app.pipe
    base_url = QtCore.QUrl(_BROWSER_BASE_URL)
    home_url = QtCore.QUrl(f"https://{LC_HOST_MARKER}/")
    state = "loading"
    request = None
    fetching = False
    challenge_announced = False

    def reply(**fields):
        nonlocal request, fetching, challenge_announced
        pipe.put({"id": request["id"], **fields})
        request = None
        fetching = False
        challenge_announced = False
        result_timer.stop()
        challenge_deadline.stop()
        challenge_grace.stop()
        window.hide()
        idle_timer.start()

    def reply_challenge():
        reply(status=403, mitigated="challenge", body="")

    def show_offscreen():
        window.setAttribute(QtCore.Qt.WidgetAttribute.WA_DontShowOnScreen, True)
        window.show()

    def reveal_challenge():
        challenge_deadline.start()
        window.hide()
        window.setAttribute(QtCore.Qt.WidgetAttribute.WA_DontShowOnScreen, False)
        window.show()
        window.raise_()
        window.activateWindow()

    def navigate(url):
        nonlocal state
        state = "loading"
        view.setUrl(url)

    def detect_page(_=None):
        view.page.runJavaScript("!!(window._cf_chl_opt || document.getElementById('challenge-form'))", 0, on_detected)

    def on_detected(is_challenge):
        nonlocal state, challenge_announced
        if state == "ready":
            return
        if is_challenge:
            state = "challenge"
            if not request:
                return
            if not request["interactive"]:
                reply_challenge()
                return
            if not challenge_announced:
                challenge_announced = True
                pipe.put({"challenge": "auto"})
                challenge_grace.start()
                if not window.isVisible():
                    # Defi charge pendant que la page etait gelee : le relancer une fois active
                    show_offscreen()
                    view.reload()
            challenge_poll.start()
            return
        challenge_poll.stop()
        if view.url().path() != base_url.path():
            navigate(base_url)
            return
        state = "ready"
        challenge_grace.stop()
        window.hide()
        start_fetch()

    def start_fetch():
        nonlocal fetching
        if state != "ready" or not request or fetching:
            return
        fetching = True
        idle_timer.stop()
        redirect = "follow" if request["follow"] else "manual"
        view.page.runJavaScript(f"""
            window.__lc = window.__lc || {{}};
            delete window.__lc[{request["id"]}];
            fetch({json.dumps(request["url"])}, {{
                credentials: "include",
                redirect: "{redirect}",
                signal: AbortSignal.timeout({_BROWSER_TIMEOUT * 1000 - 5000}),
            }}).then(async res => {{
                const bytes = new Uint8Array(await res.arrayBuffer());
                let binary = "";
                for (let i = 0; i < bytes.length; i += 32768) {{
                    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 32768));
                }}
                window.__lc[{request["id"]}] = {{
                    status: res.status,
                    redirected: res.type === "opaqueredirect",
                    url: res.url,
                    mitigated: res.headers.get("cf-mitigated"),
                    body: btoa(binary),
                }};
            }}).catch(err => {{
                window.__lc[{request["id"]}] = {{ error: String(err) }};
            }});
        """, 1)
        result_timer.start()

    def poll_result():
        if request:
            view.page.runJavaScript(
                f"window.__lc && window.__lc[{request['id']}] ? JSON.stringify(window.__lc[{request['id']}]) : null",
                1, on_result,
            )

    def on_result(raw):
        nonlocal fetching
        if not raw or not fetching:
            return
        result_timer.stop()
        result = json.loads(raw)
        if _is_cf_challenge(result.get("status"), result.get("mitigated")) and request["interactive"] and not request.get("retried"):
            # Ouvrir une vraie page, la seule a pouvoir afficher le defi, puis rejouer la requete
            request["retried"] = True
            fetching = False
            show_offscreen()
            navigate(home_url)
            return
        reply(**result)

    def on_stdin_line(line: str):
        nonlocal request
        message = json.loads(line) if line else None
        if message is None:
            app.quit()
        elif "cookies" in message:
            origin = QtCore.QUrl(f"https://{LC_HOST_MARKER}")
            for key, value in message["cookies"].items():
                view.cookieStore.setCookie(
                    QtNetwork.QNetworkCookie(QtCore.QByteArray(key.encode()), QtCore.QByteArray(value.encode())),
                    origin,
                )
            view.setUrl(base_url)
        elif "reveal" in message:
            # Le defi a pu aboutir pendant que ce message arrivait
            if request and state == "challenge":
                reveal_challenge()
        else:
            request = message
            idle_timer.stop()
            if state == "challenge":
                detect_page()
            else:
                start_fetch()

    def on_cookie_added(cookie: QtNetwork.QNetworkCookie):
        if LC_HOST_MARKER in cookie.domain():
            pipe.put({"cookie": [cookie.name().data().decode("utf-8"), cookie.value().data().decode("utf-8")]})

    class StdinBridge(QtCore.QObject):
        line = QtCore.pyqtSignal(str)

    bridge = StdinBridge()
    bridge.line.connect(on_stdin_line)

    def read_stdin():
        for line in sys.stdin:
            bridge.line.emit(line)
        # Application principale fermee
        bridge.line.emit("")

    def make_timer(interval: int, callback, single_shot=False):
        timer = QtCore.QTimer(app)
        timer.setInterval(interval)
        timer.setSingleShot(single_shot)
        timer.timeout.connect(callback)
        return timer

    result_timer = make_timer(50, poll_result)
    challenge_poll = make_timer(1000, detect_page)
    challenge_deadline = make_timer(_BROWSER_CHALLENGE_TIMEOUT * 1000, lambda: request and reply_challenge(), True)
    challenge_grace = make_timer(_BROWSER_CHALLENGE_GRACE_MS, lambda: pipe.put({"challenge": "user"}), True)
    idle_timer = make_timer(_BROWSER_IDLE_MS, app.quit, True)

    original_close = window.closeEvent

    def close_event(event):
        # Fenetre fermee sans repondre au defi
        if request:
            reply_challenge()
        original_close(event)
        app.quit()

    window.closeEvent = close_event
    view.cookieStore.cookieAdded.connect(on_cookie_added)
    view.loadFinished.connect(detect_page)
    idle_timer.start()
    threading.Thread(target=read_stdin, daemon=True).start()
    app.exec()


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


_LC_MONTHS = {m: i for i, m in enumerate(("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"), 1)}


def _parse_lc_date(text: str) -> int:
    import datetime as dt
    from common.parser import datestamp

    # Pas de strptime("%b") : Qt applique la locale systeme (ex: fr_FR) au demarrage,
    # et "Sep" n'est alors plus reconnu, ce qui mettait toutes les dates a 0
    match = re.match(r"^([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{1,2}),?\s+(\d{4})$", (text or "").strip())
    if not match:
        return 0
    month = _LC_MONTHS.get(match.group(1).lower())
    if not month:
        return 0
    try:
        parsed = dt.datetime(int(match.group(3)), month, int(match.group(2)), tzinfo=dt.timezone.utc)
    except ValueError:
        return 0
    return datestamp(parsed.timestamp())


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
    previews_urls = []
    if post is not None:
        imgs = post.find_all(lambda elem: elem.name == "img" and "bbImage" in (elem.get("class") or []))
        if imgs:
            image_url = imgs[0].get("data-src") or imgs[0].get("src") or "missing"
        # Miniatures /data/attachments/...?hash= (accessibles sans connexion, contrairement
        # aux originaux /attachments/...), dans l'ordre du post, sans la couverture
        for img in imgs[1:]:
            src = img.get("data-src") or img.get("src") or ""
            if src.startswith(("http://", "https://")) and src != image_url and src not in previews_urls:
                previews_urls.append(src)

    parsed = SimpleNamespace(
        name=name, thread_version=version, developer=developer, type=type_, status=status,
        last_updated=last_updated, score=score, votes=votes, description=description,
        changelog="", tags=tags, unknown_tags=tuple(unknown_tags), image_url=image_url,
        previews_urls=previews_urls, downloads=(),
    )
    return parsed, None


async def _scrape_and_apply(game, updates: dict | None = None) -> tuple[bool, str]:
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
    game.previews_urls = parsed.previews_urls
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
        # Upstream recent : dict "updates" local a api.refresh() ; ancien upstream :
        # globals.new_updated_games
        if updates is None:
            updates = getattr(globals, "new_updated_games", None)
        if updates is not None:
            updates[game.id] = OldGame(
                id=game.id,
                name=old_name,
                version=old_version,
                status=old_status,
            )

    return True, ""


async def check_lc_session() -> tuple[bool, str | None]:
    """Verifie qu'une requete simple vers LewdCorner passe, avant de lancer un refresh
    par jeu. Une session/cookie 'cf_clearance' perime bloque TOUTES les requetes de la
    meme facon (pas juste certains jeux), donc un seul aller-retour ici evite d'envoyer
    N requetes vouees a echouer identiquement en 403. Renvoie (ok, erreur)."""
    global _browser_mode
    from modules import api

    if not is_lc_logged_in():
        return False, "LOGIN_REQUIRED"
    if _browser_mode:
        return await _check_lc_session_browser()
    try:
        # Sans suivre les redirections : avec des cookies expires, LewdCorner boucle
        # indefiniment vers /login/two-step au lieu de renvoyer une erreur
        async with api.request(
            "GET", f"https://{LC_HOST_MARKER}/", cookies=_load_lc_cookies(), timeout=30,
            headers=_LC_BROWSER_HEADERS, allow_redirects=False,
        ) as (res, req):
            if _is_cf_challenge(req.status, req.headers.get("cf-mitigated")):
                _browser_mode = True
                return await _check_lc_session_browser()
            if 300 <= req.status < 400:
                if "/login" in req.headers.get("Location", ""):
                    return False, "LOGIN_REQUIRED"
                return False, f"HTTP {req.status}"
            if req.status >= 400:
                return False, _http_error(req.status, res)
            if b'data-logged-in="true"' not in res:
                return False, "LOGIN_REQUIRED"
            return True, None
    except Exception as exc:
        return False, (f"{type(exc).__name__}: {exc}" if str(exc) else type(exc).__name__)


async def _check_lc_session_browser() -> tuple[bool, str | None]:
    result = await _browser_fetch(f"https://{LC_HOST_MARKER}/", follow_redirects=False)
    if err := result.get("error"):
        return False, err
    # fetch() masque la cible des redirections : sur la home, c'est toujours /login
    if result.get("redirected"):
        return False, "LOGIN_REQUIRED"
    if _is_cf_challenge(result["status"], result.get("mitigated")):
        return False, "CLOUDFLARE_CHALLENGE"
    if result["status"] >= 400:
        return False, _http_error(result["status"], result["body"])
    if b'data-logged-in="true"' not in result["body"]:
        return False, "LOGIN_REQUIRED"
    return True, None


def status_text() -> str:
    """Texte de progression en bas de fenetre, comme les etapes de refresh de F95Checker."""
    from modules import utils

    if _status_login:
        return "En attente de la connexion LewdCorner..."
    if _status_challenge == "user":
        return "Verification Cloudflare a faire dans sa fenetre..."
    if _status_challenge:
        return "Verification Cloudflare en cours..."
    if _status_session:
        return "Verification de la session LewdCorner..."
    # is_refreshing : un refresh annule peut laisser des taches jamais demarrees dans le compte
    if _lc_remaining > 0 and utils.is_refreshing():
        return f"LewdCorner : {_lc_remaining} jeu{'x' if _lc_remaining > 1 else ''} restant{'s' if _lc_remaining > 1 else ''}..."
    return ""


def _session_failure_text(reason: str) -> str:
    if reason == "LOGIN_REQUIRED":
        return "LewdCorner ne reconnait pas la session."
    if reason == "REQUIRED_READING":
        return "Un sujet en lecture obligatoire doit etre ouvert sur LewdCorner dans un navigateur."
    if "CLOUDFLARE_CHALLENGE" in reason:
        return "La verification Cloudflare n'a pas ete terminee."
    return reason


def _feed_state_path() -> Path:
    return _cookies_path().with_name("lc_feed.json")


def _load_feed_state() -> dict:
    try:
        data = json.loads(_feed_state_path().read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _parse_updates_page(data: bytes) -> tuple[dict[int, float], bool] | None:
    """Renvoie ({id du sujet: date de mise a jour}, autre page disponible), ou None si illisible."""
    try:
        result = json.loads(data)["result"]
        return {int(item["id"]): float(item["timestamp"]) for item in result["items"]}, bool(result["hasMore"])
    except (KeyError, TypeError, ValueError):
        return None


async def _fetch_recent_updates(since: float) -> tuple[dict[int, float] | None, str | None]:
    """Parcourt les mises a jour jusqu'a la date demandee, sans depasser le plafond de pages
    (plus de 1000 mises a jour, soit des semaines d'absence). (None, cause) si la liste est illisible."""
    import asyncio

    updates = {}
    for page in range(1, _LC_UPDATES_MAX_PAGES + 1):
        data, err = await _fetch_page(f"{_LC_UPDATES_URL}{page}")
        if not data:
            return None, err or "reponse vide"
        parsed = _parse_updates_page(data)
        if not parsed:
            return None, "reponse illisible"
        if not parsed[0]:
            return None, "liste vide"
        items, has_more = parsed
        updates.update(items)
        if not has_more or min(items.values()) < since:
            return updates, None
        await asyncio.sleep(_LC_REQUEST_DELAY)
    return updates, None


async def _games_to_refresh(games: list, full: bool, selection: bool) -> list:
    """Ne garde que les jeux signales par la liste des mises a jour, sauf Full Refresh manuel."""
    from common.structs import Status

    global _feed_state_pending
    _feed_state_pending = None
    # Recheck de jeux choisis : ne dit rien sur les autres jeux, l'etat de suivi reste inchange
    if selection:
        return games
    now = time.time()
    if full:
        _feed_state_pending = {"last_check": now}
        return games
    last_check = _load_feed_state().get("last_check", now - _LC_FIRST_LOOKBACK)
    since = last_check - _LC_FEED_MARGIN
    updates, err = await _fetch_recent_updates(since)
    if updates is None:
        # Jamais de repli sur toutes les pages : le prochain refresh reprendra depuis last_check
        _failed_games.setdefault(f"Liste des mises a jour LewdCorner indisponible ({err}).", []).extend(game.name for game in games)
        return []
    _feed_state_pending = {"last_check": now}
    return [
        game for game in games
        if game.status is Status.Unchecked or game.image.missing or updates.get(_thread_id(game.url), 0) >= since
    ]


async def refresh_lc_game(game, updates: dict | None = None) -> None:
    """Refresh d'un jeu custom LewdCorner, lance par start_refresh()."""
    from common.structs import MsgBox
    from modules import globals, msgbox, utils

    global _lc_abort_error, _lc_remaining, _session_expired_reason
    import asyncio

    try:
        async with _lc_sem:
            if _lc_abort_error:
                success, error_msg = False, _lc_abort_error
            else:
                success, error_msg = await _scrape_and_apply(game, updates)
                if not success and re.search(r"HTTP (403|429|5\d\d)|REQUIRED_READING|CLOUDFLARE_CHALLENGE|TooManyRedirects", error_msg):
                    _lc_abort_error = error_msg
                await asyncio.sleep(_LC_REQUEST_DELAY)
        if not success:
            if "HTTP 403" in error_msg or "TooManyRedirects" in error_msg or "CLOUDFLARE_CHALLENGE" in error_msg or error_msg == "REQUIRED_READING":
                # Le 403 sur LewdCorner vient quasi toujours d'une session/cookie
                # Cloudflare (cf_clearance) perimee ou liee a une autre IP que celle
                # de ce client HTTP, pas d'un vrai probleme par jeu. Regrouper ces
                # echecs en un seul message (voir api.refresh) au lieu de spammer
                # une popup par jeu.
                _session_expired_games.append(game.name)
                _session_expired_reason = error_msg
            else:
                _failed_games.setdefault(error_msg, []).append(game.name)
    except Exception:
        from external import error
        utils.push_popup(
            msgbox.msgbox, "LewdCorner",
            f'Erreur inattendue en verifiant "{game.name}".',
            MsgBox.error,
            more=error.traceback(),
        )
    finally:
        _lc_remaining -= 1
        globals.refresh_progress += 1


async def start_refresh(games: list, updates: dict | None = None, *, full: bool = True, selection: bool = False) -> list:
    """Point d'entree appele depuis api.refresh() : verifie d'abord la session LC une
    seule fois, et ne lance les refresh par jeu (taches renvoyees) que si elle passe."""
    import asyncio
    from modules import globals

    global _feed_state_pending, _lc_sem, _lc_abort_error, _lc_remaining, _session_expired_reason, _status_login, _status_session
    _feed_state_pending = None
    if not games:
        return []
    _lc_sem = asyncio.Semaphore(_LC_MAX_CONCURRENT)
    _lc_abort_error = None
    _lc_remaining = 0
    _status_session = True
    try:
        ok, err = await check_lc_session()
        # F95Checker en arriere-plan : pas de fenetre de connexion surprise, comme le captcha d'api.py
        if err == "LOGIN_REQUIRED" and not _is_login_snoozed():
            _status_login = True
            try:
                # Reduit ou sans le focus : la fenetre attend le retour de l'utilisateur
                if await _wait_for_main_window():
                    if await lc_login():
                        ok, err = await check_lc_session()
                    else:
                        _snooze_login()
            finally:
                _status_login = False
    finally:
        _status_session = False
    if not ok and err and ("HTTP 403" in err or err in ("REQUIRED_READING", "LOGIN_REQUIRED", "CLOUDFLARE_CHALLENGE")):
        _session_expired_games.extend(game.name for game in games)
        _session_expired_reason = err
        globals.refresh_progress += len(games)
        return []
    if not ok:
        # Site injoignable (502, timeout, reseau...) : inutile de tenter chaque jeu
        _failed_games.setdefault(f"LewdCorner injoignable ({err}).", []).extend(game.name for game in games)
        globals.refresh_progress += len(games)
        return []
    _status_session = True
    try:
        selected = await _games_to_refresh(games, full, selection)
    finally:
        _status_session = False
    globals.refresh_progress += len(games) - len(selected)
    _lc_remaining = len(selected)
    return [asyncio.create_task(refresh_lc_game(game, updates)) for game in selected]


def _push_lc_popup(message: str, more: str) -> None:
    """Remplace une popup LewdCorner identique encore ouverte au lieu d'en empiler une de plus
    a chaque refresh (sinon des dizaines s'accumulent quand F95Checker tourne en arriere-plan)."""
    from common.structs import MsgBox
    from modules import globals, msgbox, utils

    for popup in globals.popup_stack:
        if popup.open and popup.func is msgbox.msgbox and popup.args[:2] == ("LewdCorner", message):
            # Fermee au prochain rendu par Popup.__call__
            popup.open = False
    utils.push_popup(msgbox.msgbox, "LewdCorner", message, MsgBox.warn, more=more)


def report_session_expired() -> None:
    """Affiche une seule popup pour tous les jeux LC refuses en 403 pendant ce refresh,
    et une par type d'erreur pour les autres echecs."""
    from modules import globals

    global _feed_state_pending
    # Refresh interrompu par le site : les jeux restants n'ont pas ete vus. Un echec isole
    # (sujet supprime...) ne bloque pas : la liste ne le signalerait de toute facon plus.
    if _feed_state_pending and not _session_expired_games and not _lc_abort_error:
        path = _feed_state_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(_feed_state_pending), encoding="utf-8")
    _feed_state_pending = None

    if globals.gui.hidden:
        # Sinon une popup s'empilerait a chaque refresh ; le prochain refresh visible redemandera
        _session_expired_games.clear()

    for error_msg, failed in _failed_games.items():
        names = sorted(set(failed))
        _push_lc_popup(f"{len(names)} jeu(x) LewdCorner non verifie(s) :\n{error_msg}", "\n".join(names))
    _failed_games.clear()

    if not _session_expired_games:
        return
    names = sorted(set(_session_expired_games))
    _session_expired_games.clear()
    _push_lc_popup(
        f"{len(names)} jeu(x) LewdCorner non verifie(s) : session expiree ou refusee.\n"
        f"Cause : {_session_failure_text(_session_expired_reason)}\n"
        + (
            "Relancez la verification et terminez-la dans la fenetre qui s'ouvre."
            if "CLOUDFLARE_CHALLENGE" in _session_expired_reason
            else "Reconnectez-vous via le bouton Se connecter dans la sidebar LewdCorner."
        ),
        "\n".join(names),
    )


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
WshShell.Run """" & WScript.Arguments(0) & """ --startup", 0, False
@@END_SILENT_LAUNCHER@@
