@echo off
REM Safe Disk CLI Build Wrapper (Windows)
REM Core logic is in build_cli.go; this wrapper calls it via go run.

setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"
go run build_cli.go %*
popd
