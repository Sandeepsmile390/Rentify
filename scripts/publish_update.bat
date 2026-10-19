@echo off
REM Rentify APK Rebuild & Realtime Broadcast Script
echo ====================================================
echo Starting Rentify APK Rebuild and Update Broadcast...
echo ====================================================
dart run tool/publish_update.dart %*
