@echo off
rem -----------------------------------------------------------------------------
rem Night City Roguelite - collect logs for a report
rem -----------------------------------------------------------------------------
rem Copy this file into your Cyberpunk 2077 folder (the one with bin, r6 and
rem red4ext) once. After playing, quit through the menu, then double-click it:
rem it zips the mod's run data and the framework logs onto your desktop.
rem -----------------------------------------------------------------------------
setlocal
cd /d "%~dp0"
if not exist "bin\x64\Cyberpunk2077.exe" (
  echo Put this file in your Cyberpunk 2077 folder ^(the one with bin, r6 and red4ext^) and run it from there.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f = @(@('red4ext\plugins\Codeware\Persistent\ScriptableServiceContainer.dat', 'r6\logs\redscript_rCURRENT.log') | Where-Object { Test-Path $_ }); $t = (Get-Date).AddDays(-2); foreach ($d in 'red4ext\logs', 'red4ext\plugins\Codeware', 'red4ext\plugins\TweakXL', 'red4ext\plugins\ArchiveXL') { if (Test-Path $d) { $f += @(Get-ChildItem $d -Filter *.log | Where-Object { $_.LastWriteTime -gt $t } | ForEach-Object { $_.FullName }) } }; if ($f.Count -eq 0) { Write-Host 'Nothing to collect.'; exit 1 }; $z = Join-Path ([Environment]::GetFolderPath('Desktop')) ('NightCityRoguelite-logs-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.zip'); Compress-Archive -Path $f -DestinationPath $z -Force; Write-Host ('Saved ' + $z + ' - send that file along with what happened.')"
pause
