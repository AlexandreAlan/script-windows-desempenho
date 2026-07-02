@echo off
REM Abre o OTIMIZADOR TOTAL (versao GRAFICA / janela) ja como ADMINISTRADOR.
REM Basta dar duplo-clique neste arquivo.

powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Otimizador-GUI.ps1\"' -Verb RunAs"
