# Rentify APK Rebuild & Realtime Broadcast PowerShell Script
param(
    [switch]$SkipBuild,
    [switch]$Bump
)

$argsList = @()
if ($SkipBuild) { $argsList += "--skip-build" }
if ($Bump) { $argsList += "--bump" }

dart run tool/publish_update.dart @argsList
