@echo off
xcopy plugins\settings\RL2MQTT.set source\plugins\settings\ /y
cd source
Powershell.exe -File create_install_zip.ps1
Powershell.exe -File create_source_zip.ps1
pause