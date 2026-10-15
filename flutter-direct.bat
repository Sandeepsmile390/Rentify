@echo off
rem Rentify Flutter launcher — bypasses bootstrap bug in flutter.bat
rem Use this instead of flutter.bat until flutter.bat self-upgrade is fixed.
set "FLUTTER_ROOT=C:\Users\Sandeep kumar\flutter"
set "DART_EXE=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
set "SNAPSHOT=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot"
"%DART_EXE%" "%SNAPSHOT%" %*
