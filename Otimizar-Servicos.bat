@echo off
REM Abre o otimizador de SERVICOS em PowerShell ja como ADMINISTRADOR.
REM Basta dar duplo-clique neste arquivo.

powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Otimizar-Servicos.ps1\"' -Verb RunAs"
