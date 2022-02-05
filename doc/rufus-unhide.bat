@echo off

rem rufus hides usb devices; this unhides them

rem but first we need admin
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\heis.vbs" del "%temp%\heis.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || ( echo Set U = CreateObject^("Shell.Application"^) : U.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params% & exit", "", "runas", 1 >> "%temp%\heis.vbs" && "%temp%\heis.vbs" && exit /B )

echo(
echo( please exit rufus and disconnect the usb flashdrive before continuing
echo(
pause

rem do the thing
mountvol /r

echo(
echo( done
echo(  ^(you can reconnect the flashdrive now if you'd like^)
echo(

pause
