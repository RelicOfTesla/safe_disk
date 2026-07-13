@echo off
REM Safe Disk - Build & Run Wrapper (Windows)
REM Core logic is in build.go; this wrapper calls it via go run.

setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"
go run build.go run --rebuild %*
popd
