@ECHO OFF 

SETLOCAL

:: set variables
SET CDir=%~dp0%
SET PasDoc=D:\Coding\Git\PasDoc\pasdoc\bin\pasdoc.exe

:: main stuff here 

CALL %PasDoc% --option-file="%CDir%\pasdoc.opt" "%CDir%\..\Source\*.pas" || PAUSE 