@ECHO OFF 

SETLOCAL

:: set variables
SET CDir=%~dp0%
SET PasDoc=D:\Coding\Git\PasDoc\bin\pasdoc.exe

:: main stuff here 

CALL "%PasDoc%" "@%CDir%\pasdoc.opt" "%CDir%\..\Source\*.pas" || PAUSE 