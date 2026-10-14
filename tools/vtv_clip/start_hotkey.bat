@echo off
cd /d "%~dp0"
where python >nul 2>&1
if errorlevel 1 (
    echo Python が見つかりません。
    pause
    exit /b 1
)
rem 最小化して常駐する。タスクバーの「VTV画像クリップ」を閉じると終了する。
start "VTV画像クリップ" /MIN python "%~dp0clip_image.py" %*
