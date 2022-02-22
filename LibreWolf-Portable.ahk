; LibreWolf Portable - https://github.com/ltGuillaume/LibreWolf-Portable
;@Ahk2Exe-SetFileVersion 1.1.0

;@Ahk2Exe-Bin Unicode 64*
;@Ahk2Exe-SetDescription LibreWolf Portable
;@Ahk2Exe-SetMainIcon LibreWolf-Portable.ico
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,160`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,206`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,207`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,208`, ,,,,1

ProgramPath       := A_ScriptDir "\LibreWolf"
ExeFile           := ProgramPath "\librewolf.exe"
ProfilePath       := A_ScriptDir "\Profiles\Default"
LastPathFile      := ProfilePath "\.portable-lastpath"
PortableRunning   := False

; Strings
_Title                = LibreWolf Portable
_GetProgramPathError  = Could not find the path to LibreWolf:`n%ProgramPath%
_GetProfilePathError  = Could not find the path to the profile folder:`n%ProfilePath%`nIf this is the first time you are running LibreWolf Portable, you can ignore this. Continue?
_BackupKeyFound       = A backup registry key has been found:
_BackupFolderFound    = A backup folder has been found:
_BackupFoundActions   = This means LibreWolf Portable has probably not been closed correctly. Continue to restore the found backup after running, or remove the backup yourself and press Retry to back up the current folder/key.
_ErrorStarting        = LibreWolf could not be started. Exit code:
_MissingDLLs          = You probably don't have msvcp140.dll and vcruntime140.dll present on your system. Put these files in the folder %ProgramPath%,`nor install the Visual C++ runtime libraries via https://librewolf.net.
_FileReadError        = Error reading file for modification:

; Preparation
#SingleInstance Off
#NoEnv
EnvGet, Temp, Temp
EnvGet, LocalAppData, LocalAppData
OnExit, Exit
FileGetVersion, PortableVersion, %A_ScriptFullPath%
PortableVersion := SubStr(PortableVersion, 1, -2)
SetWorkingDir, %Temp%
Menu, Tray, Tip, %_Title% %UpdaterVersion%
If !A_IsCompiled
	Menu, Tray, Icon, %A_ScriptDir%\LibreWolf-Portable.ico

; Check for running LibreWolf-Portable processes
DetectHiddenWindows, On
SetTitleMatchMode 2
WinGet, Self, List, %A_ScriptName% ahk_exe %A_ScriptName%
Loop, %Self%
	If (Self%A_Index% != A_ScriptHwnd) {
		PortableRunning := True
;MsgBox, LibreWolf Portable is already running.`nSkipping preparation.
		Goto, Run
	}

; Check path to LibreWolf and profile
If !FileExist(ExeFile) {
	MsgBox, 48, %_Title%, %_GetProgramPathError%
	Exit
}
If !FileExist(ProfilePath) {
	MsgBox, 52, %_Title%, %_GetProfilePathError%
	IfMsgBox No
		Exit
	IfMsgBox Yes
		FileCreateDir, %ProfilePath%
}

; Backup existing registry key and AppData folders
RegKey  := "HKCU\Software\LibreWolf"
Folders := [A_AppData "\LibreWolf", LocalAppData "\LibreWolf"]

PrepRegistry:
RegRead, null, %RegKey%
If !ErrorLevel {
	RegRead, null, %RegKey%.pbak
	If !ErrorLevel {
		MsgBox, 54, %_Title%, %_BackupKeyFound%`n%RegKey%`n%_BackupFoundActions%
		IfMsgBox Cancel
			Exit
		IfMsgBox TryAgain
			Goto, PrepRegistry
	} Else
		RunWait, reg copy %RegKey% %RegKey%.pbak /s /f
	RegDelete, %RegKey%
}

For i, Folder in Folders {
PrepFolder:
	If FileExist(Folder) {
		If FileExist(Folder ".pbak") {
			MsgBox, 54, %_Title%, %_BackupFolderFound%`n%Folder%`n%_BackupFoundActions%
			IfMsgBox Cancel
				Exit
			IfMsgBox TryAgain
				Goto, PrepFolder
			IfMsgBox Continue
				FileRemoveDir, %Folder%, 1
		} Else
			FileMoveDir, %Folder%, %Folder%.pbak, 2
	}
}

; Skip path adjustment if profile path hasn't changed since last run
If FileExist(LastPathFile) {
	FileRead, LastPath, %LastPathFile%
	If LastPath = %ProfilePath%
		Goto, Run
} Else
	FileAppend, %ProfilePath%, %LastPathFile%
;MsgBox, Time to adjust the absolute profile path

; Adjust absolute profile folder paths to current path
FileInstall, dejsonlz4.exe, %Temp%\dejsonlz4.exe, 0
FileInstall, jsonlz4.exe, %Temp%\jsonlz4.exe, 0

ProgramPathDS := StrReplace(ProgramPath, "\", "\\")
VarSetCapacity(ProgramPathUri, 300*2)
DllCall("shlwapi\UrlCreateFromPath" "W", "Str", ProgramPath, "Str", ProgramPathUri, "UInt*", 300, "UInt", 0)
ProfilePathDS := StrReplace(ProfilePath, "\", "\\")
VarSetCapacity(ProfilePathUri, 300*2)
DllCall("shlwapi\UrlCreateFromPath" "W", "Str", ProfilePath, "Str", ProfilePathUri, "UInt*", 300, "UInt", 0)

If FileExist(ProfilePath "\addonStartup.json.lz4") {
	RunWait, dejsonlz4.exe "%ProfilePath%\addonStartup.json.lz4" "%ProfilePath%\addonStartup.json",, Hide
	If ReplacePaths(ProfilePath "\addonStartup.json")
		RunWait, jsonlz4.exe "%ProfilePath%\addonStartup.json" "%ProfilePath%\addonStartup.json.lz4",, Hide
	FileDelete, %ProfilePath%\addonStartup.json
}

ReplacePaths(ProfilePath "\extensions.json")
ReplacePaths(ProfilePath "\prefs.js")

ReplacePaths(FilePath) {
	Global ProgramPathDS, ProgramPathUri, ProfilePath, ProfilePathDS, ProfilePathUri

	If !FileExist(FilePath)
		Return

	FileRead, File, %FilePath%
	If Errorlevel {
		MsgBox, 48, %_FileReadError%`n%FilePath%
		Return
	}		
	FileOrg := File

; Won't work, because LibreWolf resets the value for autoadmin.global_config_url on start-up
;	If FilePath = %ProfilePath%\prefs.js
;		File := RegExReplace(File, "i)(, "")[^""]+?(\Qlibrewolf.overrides.cfg""\E)", "$1" ProfilePathUri "/$2")
	File := RegExReplace(File, "i).:\\[^""]+?(\Q\\browser\\features\E)", ProgramPathDS "$1")
	File := RegExReplace(File, "i)file:\/\/\/[^""]+?(\Q/browser/features\E)", ProgramPathUri "$1")
	File := RegExReplace(File, "i).:\\[^""]+?(\Q\\extensions\E)", ProfilePathDS "$1")
	File := RegExReplace(File, "i)file:\/\/\/[^""]+?(\Q/extensions\E)", ProfilePathUri "$1")

	If (File = FileOrg)
		Return False
	Else {
		FileMove, %FilePath%, %FilePath%.pbak, 1
		FileAppend, %File%, %FilePath%
		Return True
	}
}

; Write current profile path to file
FileDelete, %LastPathFile%
FileAppend, %ProfilePath%, %LastPathFile%

; Run LibreWolf
Run:
For i, Arg in A_Args
	Args .= " """ Arg """"
;MsgBox, %ExeFile% -profile "%ProfilePath%" %Args%
RunWait, %ExeFile% -profile "%ProfilePath%" %Args%,, UseErrorLevel

If ErrorLevel {
	Message := _ErrorStarting " " ErrorLevel
	If Errorlevel = -1073741515
		Message .= "`n`n" _MissingDLLs
	MsgBox, 48, %_Title%, %Message%
}

; Leave the rest to the already running LibreWolf-Portable instance
If PortableRunning
	Exit

ExeFileDS := StrReplace(ExeFile, "\", "\\")
; Wait for all LibreWolf processes of current user to be closed
WaitClose:
Sleep, 5000
StillRunning := False
For Process in ComObjGet("winmgmts:").ExecQuery("Select ProcessId from Win32_Process where ExecutablePath='" ExeFileDS "'") {
   Try {
		oUser := ComObject(0x400C, &User)	; VT_BYREF
		Process.GetOwner(oUser)
;MsgBox, % oUser[]
		If (oUser[] = A_UserName) {
			StillRunning := True
			Break
		}
	} Catch e
		Goto, WaitClose
}

If StillRunning
	Goto, WaitClose

; Restore registry and folders
RegDelete, %RegKey%
RegRead, null, %RegKey%.pbak
If !ErrorLevel {
	RunWait, reg copy %RegKey%.pbak %RegKey% /s /f
	RegDelete, %RegKey%.pbak
}

For i, Folder in Folders {
	If FileExist(Folder)
		FileRemoveDir, %Folder%, 1
	If FileExist(Folder ".pbak")
		FileMoveDir, %Folder%.pbak, %Folder%, 2
}

; Clean-up
Exit:
If !PortableRunning {
	FileDelete, *jsonlz4.exe
	FileRemoveDir, mozilla-temp-files
}