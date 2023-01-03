; LibreWolf Portable - https://github.com/ltGuillaume/LibreWolf-Portable
;@Ahk2Exe-SetFileVersion 1.4.1

;@Ahk2Exe-Bin Unicode 64*
;@Ahk2Exe-SetCompanyName LibreWolf Community
;@Ahk2Exe-SetDescription LibreWolf Portable
;@Ahk2Exe-SetMainIcon LibreWolf-Portable.ico
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,160`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,206`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,207`, ,,,,1
;@Ahk2Exe-PostExec ResourceHacker.exe -open "%A_WorkFileName%" -save "%A_WorkFileName%" -action delete -mask ICONGROUP`,208`, ,,,,1

#NoEnv
#Persistent
#SingleInstance Off

Global CityHash := False
, LibreWolfPath := A_ScriptDir "\LibreWolf"
, LibreWolfExe  := LibreWolfPath "\librewolf.exe"
, MozCommonPath := A_AppDataCommon "\Mozilla-1de4eec8-1241-4177-a864-e594e8d1fb38"
, ProfilePath   := A_ScriptDir "\Profiles\Default"
, RegKey        := "HKCU\Software\LibreWolf"
, RegKeyFound   := False
, RegBackedUp   := False

; Strings
Global _Title            := "LibreWolf Portable"
, _Waiting               := "Waiting for all LibreWolf processes to close..."
, _NoDefaultBrowser      := "Could not open your default browser."
, _GetLibreWolfPathError := "Could not find the path to LibreWolf:`n" LibreWolfPath
, _GetProfilePathError   := "Could not find the path to the profile folder:`n" ProfilePath "`nIf this is the first time you are running LibreWolf Portable, you can ignore this. Continue?"
, _BackupKeyFound        := "A backup registry key has been found:"
, _BackupFoundActions    := "This means LibreWolf Portable has probably not been closed correctly. Continue to restore the found backup key after running, or remove the backup key yourself and press Retry to back up the current key."
, _ErrorStarting         := "LibreWolf could not be started. Exit code:"
, _MissingDLLs           := "You probably don't have msvcp140.dll and vcruntime140.dll present on your system. Put these files in the folder " LibreWolfPath ",`nor install the Visual C++ runtime libraries via https://librewolf.net."
, _FileReadError         := "Error reading file for modification:"

If (ThisInstanceRunning()) {
	RunLibreWolf()
	Exit()
}
Init()
CheckPaths()
CheckUpdates()
RegBackup()
UpdateProfile()
RunLibreWolf()
SetTimer, WaitForClose, 5000

OtherInstanceRunning() {
	Result := InstanceRunning("Name=""LibreWolf-Portable.exe""")
;MsgBox, OtherInstanceRunning: %Result%
	Return %Result%
}

ThisInstanceRunning() {
	ScriptPathDS := StrReplace(A_ScriptFullPath, "\", "\\")
	Result := InstanceRunning("ExecutablePath=""" ScriptPathDS """")
;MsgBox, ThisInstanceRunning: %Result%
	Return %Result%
}

InstanceRunning(Where) {
	Process, Exist	; Put launcher's process id into ErrorLevel
	Query := "Select ProcessId from Win32_Process where ProcessId!=" ErrorLevel " and " Where
;MsgBox, Query: %Query%
	For Process in ComObjGet("winmgmts:").ExecQuery(Query) {
		 Try {
			oUser := ComObject(0x400C, &User)	; VT_BYREF
			Process.GetOwner(oUser)
;MsgBox, % oUser[]
			If (oUser[] = A_UserName)
				Return True
		} Catch e
			Return True
	}
	Return False
}

Init() {
	EnvGet, LocalAppData, LocalAppData
	FileEncoding, UTF-8-RAW
	FileGetVersion, PortableVersion, %A_ScriptFullPath%
	PortableVersion := SubStr(PortableVersion, 1, -2)
	SetWorkingDir, %A_Temp%
	Menu, Tray, Tip, %_Title% %PortableVersion% [%A_ScriptDir%]`n%_Waiting%
	Menu, Tray, NoStandard
	Menu, Tray, Add, Portable, About
	Menu, Tray, Add, WinUpdater, About
	Menu, Tray, Add, Exit, Exit
	Menu, Tray, Default, Portable
}

About(ItemName) {
	Url = https://github.com/ltGuillaume/LibreWolf-%ItemName%
	Try Run, %Url%
	Catch {
		RegRead, DefBrowser, HKCR, .html
		RegRead, DefBrowser, HKCR, %DefBrowser%\Shell\Open\Command
		Run, % StrReplace(DefBrowser, "%1", Url)
		If (ErrorLevel)
		MsgBox, 48, %_Title%, %_NoDefaultBrowser%
	}
}

CheckPaths() {
	If (!FileExist(LibreWolfExe)) {
		MsgBox, 48, %_Title%, %_GetLibreWolfPathError%
		Exit()
	}

	; Check for profile path argument
	If A_Args.Length() > 1
		For i, Arg in A_Args
			If (A_Args[i+1] And (Arg = "-P" Or Arg = "-Profile")) {
				NewProfilePath := A_Args[i+1]
				SplitPath, NewProfilePath,,,,, ProfileDrive
				ProfilePath := (ProfileDrive ? "" : A_ScriptDir "\") NewProfilePath
				A_Args.RemoveAt(i, 2)
			}

	If (!FileExist(ProfilePath)) {
		MsgBox, 52, %_Title%, %_GetProfilePathError%
		IfMsgBox No
			Exit()
		IfMsgBox Yes
			FileCreateDir, %ProfilePath%
	}
}

; Check for updates (once a day) if LibreWolf-WinUpdater is found and no arguments were passed
CheckUpdates() {
	WinUpdater := A_ScriptDir "\LibreWolf-WinUpdater"
	If (!A_Args.Length() And FileExist(WinUpdater ".exe")) {
		If (FileExist(WinUpdater ".ini"))
			FileGetTime, LastUpdate, %WinUpdater%.ini
		If (!LastUpdate Or SubStr(LastUpdate, 1, 8) < SubStr(A_Now, 1, 8)) {
			Run, %WinUpdater%.exe /Portable
			Exit()
		}
	}
}

RegBackup() {
	PrepRegistry:
	BackupKeyFound := False

	Loop, Reg, %RegKey%, K
		RegKeyFound := True
;MsgBox, RegKeyFound: %RegKeyFound%
	If (RegKeyFound) {
		Loop, Reg, %RegKey%.pbak, K
			BackupKeyFound := True
;MsgBox, BackupFound: %BackupKeyFound%
		If (BackupKeyFound) {
			If (OtherInstanceRunning())
				Return
			MsgBox, 54, %_Title%, %_BackupKeyFound%`n%RegKey%.pbak`n%_BackupFoundActions%
			IfMsgBox Cancel
				Exit()
			IfMsgBox TryAgain
				Goto, PrepRegistry
		} Else {
			RunWait, reg copy %RegKey% %RegKey%.pbak /s /f,, Hide
			RegBackedUp := True
		}
		RegDelete, %RegKey%
	}
}

UpdateProfile() {
	; Skip path adjustment if profile path hasn't changed since last run
	IniRead, LastPlatformDir, %ProfilePath%\compatibility.ini, Compatibility, LastPlatformDir
	If (LastPlatformDir = LibreWolfPath)
		Return False

	; Adjust absolute profile folder paths to current path
	LibreWolfPathDS := StrReplace(LibreWolfPath, "\", "\\")
	VarSetCapacity(LibreWolfPathUri, 300*2)
	DllCall("shlwapi\UrlCreateFromPathW", "Str", LibreWolfPath, "Str", LibreWolfPathUri, "UInt*", 300, "UInt", 0x00040000)	// 0x00040000 = URL_ESCAPE_AS_UTF8
	ProfilePathDS := StrReplace(ProfilePath, "\", "\\")
	VarSetCapacity(ProfilePathUri, 300*2)
	DllCall("shlwapi\UrlCreateFromPathW", "Str", ProfilePath, "Str", ProfilePathUri, "UInt*", 300, "UInt", 0x00040000)
	OverridesPath := "user_pref(""autoadmin.global_config_url"", """ ProfilePathUri "/librewolf.overrides.cfg"");"

	If (FileExist(ProfilePath "\addonStartup.json.lz4")) {
		FileInstall, dejsonlz4.exe, dejsonlz4.exe, 0
		FileInstall, jsonlz4.exe, jsonlz4.exe, 0
		FileCopy, %ProfilePath%\addonStartup.json.lz4, %A_WorkingDir%

		RunWait, dejsonlz4.exe addonStartup.json.lz4 addonStartup.json,, Hide
		If (ReplacePaths("addonStartup.json")) {
			RunWait, jsonlz4.exe addonStartup.json addonStartup.json.lz4,, Hide
			FileMove, addonStartup.json.lz4, %ProfilePath%, 1
		}
		FileDelete, addonStartup.json
	}

	If (FileExist(ProfilePath "\extensions.json"))
		ReplacePaths(ProfilePath "\extensions.json")

	ReplacePaths(ProfilePath "\prefs.js")
}

ReplacePaths(FilePath) {
	If (!FileExist(FilePath) And FilePath = ProfilePath "\prefs.js") {
			FileAppend, %OverridesPath%, %FilePath%
		Return
	}

	FileRead, File, %FilePath%
	If (Errorlevel) {
		MsgBox, 48, %_Title%, %_FileReadError%`n%FilePath%
		Return
	}		
	FileOrg := File

	If (FilePath = ProfilePath "\prefs.js") {
		File := RegExReplace(File, "i)(, "")[^""]+?(\Qlibrewolf.overrides.cfg""\E)", "$1" ProfilePathUri "/$2", Count)
;MsgBox, librewolf.overrides.cfg path was replaced %Count% times
		If (Count = 0)
			File .= OverridesPath
	}
	File := RegExReplace(File, "i).:\\[^""]+?(\Q\\browser\\features\E)", LibreWolfPathDS "$1")
	File := RegExReplace(File, "i)file:\/\/\/[^""]+?(\Q/browser/features\E)", LibreWolfPathUri "$1")
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

RunLibreWolf() {
	If (!ThisInstanceRunning) {
		SetTimer, GetCityHash, 1000
		If (LibreWolfRunning())
			Args := "--new-instance"
	}

	For i, Arg in A_Args
		Args .= " """ Arg """"

;MsgBox, %LibreWolfExe% -profile "%ProfilePath%" %Args%
	RunWait, %LibreWolfExe% -Profile "%ProfilePath%" %Args%,, UseErrorLevel

	If (ErrorLevel) {
		Message := _ErrorStarting " " ErrorLevel
		If (Errorlevel = -1073741515)
			Message .= "`n`n" _MissingDLLs
		MsgBox, 48, %_Title%, %Message%
	}
}

GetCityHash() {
	Loop, Reg, %RegKey%\Firefox\Installer, K
		CityHash := A_LoopRegName
	If (CityHash) {
		SetTimer,, Delete
;MsgBox, CityHash = %CityHash%
	}
}

WaitForClose() {
	If (LibreWolfRunning())
		Return
	SetTimer,, Delete
	SetTimer, CleanUp, 2000
}

LibreWolfRunning() {
	For Process in ComObjGet("winmgmts:").ExecQuery("Select ProcessId from Win32_Process where Name=""librewolf.exe""") {
		 Try {
			oUser := ComObject(0x400C, &User)	; VT_BYREF
			Process.GetOwner(oUser)
;MsgBox, % oUser[]
			If (oUser[] = A_UserName)
				Return True
		} Catch e
			Return True
	}
	Return False
}

CleanUp() {
	; Wait until all instances are closed before restoring backed up registry key
	If (RegBackedUp And OtherInstanceRunning())
		Return

	SetTimer,, Delete

	; Remove files with CityHash of this instance
	If (CityHash) {
		FileDelete, %MozCommonPath%\*%CityHash%*.*
		FileRemoveDir, %MozCommonPath%\updates\%CityHash%, 1
	}

	If (OtherInstanceRunning())
		Exit()

	; Restore backed up registry key
;MsgBox, RegKey: %RegKey%`nRegKeyFound: %RegKeyFound%
	RegDelete, %RegKey%
	If (RegKeyFound) {
		RunWait, reg copy %RegKey%.pbak %RegKey% /s /f,, Hide
		RegDelete, %RegKey%.pbak
	}

	; Remove AppData and Temp folders if empty
	Folders := [ MozCommonPath, A_AppData "\LibreWolf\Extensions", A_AppData "\LibreWolf", LocalAppData "\LibreWolf", "mozilla-temp-files" ]
	For i, Folder in Folders
		FileRemoveDir, %Folder%

	; Clean-up
	FileDelete, *jsonlz4.exe

	Exit()
}

Exit() {
	ExitApp
}