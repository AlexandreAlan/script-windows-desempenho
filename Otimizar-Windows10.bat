@echo off
REM Abre o otimizador em PowerShell ja como ADMINISTRADOR.
REM Basta dar duplo-clique neste arquivo.

powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Otimizar-Windows10.ps1\"' -Verb RunAs"
