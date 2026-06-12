@echo off
REM Abre o OTIMIZADOR TOTAL em PowerShell ja como ADMINISTRADOR.
REM Basta dar duplo-clique neste arquivo.

powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Otimizador-Total.ps1\"' -Verb RunAs"
