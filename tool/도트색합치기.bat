@echo off
chcp 65001 > nul
title Dot color tool
cd /d "%~dp0.."
python tool\dot_stage_editor.py --open
if errorlevel 1 pause
