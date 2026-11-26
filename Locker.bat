@echo off
setlocal

:: create temporary VBScript
set "VBS=%TEMP%\locker_%RANDOM%.vbs"

> "%VBS%" echo Set objShell = CreateObject("WScript.Shell")
>> "%VBS%" echo Set objIE = CreateObject("InternetExplorer.Application")
>> "%VBS%" echo objIE.Navigate "about:blank"
>> "%VBS%" echo objIE.FullScreen = True
>> "%VBS%" echo objIE.Visible = True
>> "%VBS%" echo Do While objIE.Document Is Nothing
>> "%VBS%" echo   WScript.Sleep 100
>> "%VBS%" echo Loop
>> "%VBS%" echo objIE.Document.Body.InnerHTML = "<html><body style='background:black;color:red;font-family:Arial;text-align:center;padding-top:15%%;'><h1>YOUR COMPUTER IS LOCKED</h1><p style='font-size:24px;'>Enter password or press Alt+F4</p><input id='pwd' type='password' style='font-size:24px;text-align:center;' /><button onclick='check()' style='font-size:24px;'>UNLOCK</button><script>function check(){if(document.getElementById(\"pwd\").value==\"0000\"){window.close();}}</script></body></html>"
>> "%VBS%" echo Do While objIE.Visible = True
>> "%VBS%" echo   WScript.Sleep 500
>> "%VBS%" echo Loop
>> "%VBS%" echo objIE.Quit

start "" "%VBS%"
exit
