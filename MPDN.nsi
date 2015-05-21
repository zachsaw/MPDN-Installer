; ****************************************************************************
; * Copyright (C) 2002-2010 OpenVPN Technologies, Inc.                       *
; * Copyright (C)      2012 Alon Bar-Lev <alon.barlev@gmail.com>             *
; * Modified for ${PROJECT_NAME} by
; * Copyright (C)      2015 Antoine Aflalo <antoine@aaflalo.me>              *
; *  This program is free software; you can redistribute it and/or modify    *
; *  it under the terms of the GNU General Public License version 2          *
; *  as published by the Free Software Foundation.                           *
; ****************************************************************************

; MPDN install script for Windows, using NSIS

;;Set minimal version for .NET
!define MIN_FRA_MAJOR "${MAJOR_NET}"
!define MIN_FRA_MINOR "${MINOR_NET}"
!define MIN_FRA_BUILD "${BUILD_NET}"

SetCompressor lzma

; Modern user interface
!include "MUI2.nsh"

; Install for all users. MultiUser.nsh also calls SetShellVarContext to point 
; the installer to global directories (e.g. Start menu, desktop, etc.)
!define MULTIUSER_EXECUTIONLEVEL Admin
!include "MultiUser.nsh"

!addplugindir Plugins/
!include "AbortIfBadDotNetFramework.nsh"
!include "zipdll.nsh"
!include "nsProcess.nsh"

; x64.nsh for architecture detection
!include "x64.nsh"

; File Associations
!include "FileAssociation.nsh"

; Read the command-line parameters
!insertmacro GetParameters
!insertmacro GetOptions

; Move Files and folder
; Used to move the Extensions
!include 'FileFunc.nsh'
!insertmacro Locate
 
Var /GLOBAL switch_overwrite
!include 'MoveFileFolder.nsh'

; Windows version check
!include WinVer.nsh


;--------------------------------
;Configuration

;General

; Package name as shown in the installer GUI
Name "${PROJECT_NAME} ${ARCH} ${VERSION_STRING}"

; On 64-bit Windows the constant $PROGRAMFILES defaults to
; C:\Program Files (x86) and on 32-bit Windows to C:\Program Files. However,
; the .onInit function (see below) takes care of changing this for 64-bit 
; Windows.
InstallDir "$PROGRAMFILES\${PROJECT_NAME}"

; Installer filename
OutFile "${PROJECT_NAME}_${ARCH}_Installer.exe"

ShowInstDetails show
ShowUninstDetails show

;Remember install folder
InstallDirRegKey HKLM "SOFTWARE\${PROJECT_NAME}" ""

;--------------------------------
;Modern UI Configuration

; Compile-time constants which we'll need during install
!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation of ${PROJECT_NAME} ${SPECIAL_BUILD}, a MediaPlayer made by Zach Saw. Render Script made by Shiandrow. Installer by Antoine Aflalo.$\r$\n$\r$\nNote that the Windows version of ${PROJECT_NAME} will only run on Windows Seven, or higher.$\r$\n$\r$\n$\r$\n"

!define MUI_COMPONENTSPAGE_TEXT_TOP "Select the components to install/upgrade.  Stop any ${PROJECT_NAME} processes.  All DLLs are installed locally."

!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\ChangeLog.txt"
!define MUI_FINISHPAGE_RUN_TEXT "Start ${PROJECT_NAME}"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PROJECT_NAME}.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED

!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_ABORTWARNING
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "install-whirl.bmp"
!define MUI_UNFINISHPAGE_NOAUTOCLOSE

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_PAGE_CUSTOMFUNCTION_SHOW StartGUI.show
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

Var /Global strMpdnKilled ; Track if GUI was killed so we can tick the checkbox to start it upon installer finish

;--------------------------------
;Languages
 
!insertmacro MUI_LANGUAGE "English"
  
;--------------------------------
;Language Strings

LangString DESC_SecMPDN ${LANG_ENGLISH} "Install ${PROJECT_NAME}, the player. This is required."

LangString DESC_SecLAVFilter ${LANG_ENGLISH} "Install LAV Splitter/Decoder (may be omitted if already installed)."

LangString DESC_SecXySubFilter ${LANG_ENGLISH} "Install XySubFilter (may be omitted if already installed)."

LangString DESC_SecExtensions ${LANG_ENGLISH} "Install the Extensions. It contains the different Renderers and Player Extensions."

;--------------------------------
;Reserve Files
  
;Things that need to be extracted on first (keep these lines before any File command!)
;Only useful for BZIP2 compression

ReserveFile "install-whirl.bmp"

;--------------------------------
;Macros

!macro SelectByParameter SECT PARAMETER DEFAULT
	${GetOptions} $R0 "/${PARAMETER}=" $0
	${If} ${DEFAULT} == 0
		${If} $0 == 1
			!insertmacro SelectSection ${SECT}
		${EndIf}
	${Else}
		${If} $0 != 0
			!insertmacro SelectSection ${SECT}
		${EndIf}
	${EndIf}
!macroend

!macro WriteRegStringIfUndef ROOT SUBKEY KEY VALUE
	Push $R0
	ReadRegStr $R0 "${ROOT}" "${SUBKEY}" "${KEY}"
	${If} $R0 == ""
		WriteRegStr "${ROOT}" "${SUBKEY}" "${KEY}" '${VALUE}'
	${EndIf}
	Pop $R0
!macroend

!macro DelRegKeyIfUnchanged ROOT SUBKEY VALUE
	Push $R0
	ReadRegStr $R0 "${ROOT}" "${SUBKEY}" ""
	${If} $R0 == '${VALUE}'
		DeleteRegKey "${ROOT}" "${SUBKEY}"
	${EndIf}
	Pop $R0
!macroend

;--------------------
;Pre-install section

Section -pre
	${nsProcess::FindProcess} "MediaPlayerDotNet.exe" $R0
	${If} $R0 == 0
		MessageBox MB_YESNO|MB_ICONEXCLAMATION "To perform the specified operation, ${PROJECT_NAME} needs to be closed. Shall I close it?" /SD IDYES IDNO guiEndNo
		DetailPrint "Closing ${PROJECT_NAME}..."
		Goto guiEndYes
	${Else}
		Goto mpdnNotRunning
	${EndIf}

	guiEndNo:
		Quit

	guiEndYes:
		; user wants to close MPDN as part of install/upgrade
		${nsProcess::FindProcess} "MediaPlayerDotNet.exe" $R0
		${If} $R0 == 0
			${nsProcess::KillProcess} "MediaPlayerDotNet.exe" $R0
		${Else}
			Goto guiClosed
		${EndIf}
		Sleep 100
		Goto guiEndYes

	guiClosed:
		; Keep track that we closed the GUI so we can offer to auto (re)start it later
		StrCpy $strMpdnKilled "1"

	mpdnNotRunning:	
		; Delete previous start menu folder
		RMDir /r "$SMPROGRAMS\${PROJECT_NAME}"		

SectionEnd


Section /o "${PROJECT_NAME}: The Player" SecMPDN

	SetOverwrite on

	SetOutPath "$TEMP"
	
	File "/oname=Mpdn.zip" "MPDN\${ARCH}.zip"		
			
	!insertmacro ZIPDLL_EXTRACT "$TEMP\Mpdn.zip" "$INSTDIR" "<ALL>"
	SetOutPath "$INSTDIR"
	File "MPDN\ChangeLog.txt"
	${registerExtension} "$INSTDIR\MediaPlayerDotNet.exe" ".mkv" "MPDN_MKV_FILE"
	${registerExtension} "$INSTDIR\MediaPlayerDotNet.exe" ".avi" "MPDN_AVI_FILE"
	${registerExtension} "$INSTDIR\MediaPlayerDotNet.exe" ".mp4" "MPDN_MP4_FILE"

SectionEnd

Section /o "${PROJECT_NAME} Extensions" SecExtensions

	SetOverwrite on
	; Delete previous Extensions directory to avoid any conflict
	RMDir /r "$INSTDIR\Extensions"
	
	SetOutPath "$TEMP"
	File "/oname=Mpdn_Extensions.zip" "MPDN\MPDN_Extensions-master.zip"
	!insertmacro ZIPDLL_EXTRACT "$TEMP\Mpdn_Extensions.zip" "$TEMP" "<ALL>"
	!insertmacro MoveFolder "$TEMP\MPDN_Extensions-master\Extensions\" "$INSTDIR\Extensions\" "*.*"

SectionEnd


SectionGroup "!Dependencies (Advanced)"

	Section /o "LAV Filter" SecLAVFilter

		SetOverwrite on
		SetOutPath "$INSTDIR\Pre-requisites"
		File "Pre-requisites\LAVFilters-Installer.exe"
		ExecWait "$INSTDIR\Pre-requisites\LAVFilters-Installer.exe"
	SectionEnd

	Section /o "XySubFilter DLLs" SecXySubFilter

		SetOverwrite on
		SetOutPath "$INSTDIR\Pre-requisites"
		${If} "${ARCH}" == "AnyCPU"
			${If} ${RunningX64}		
				File "/oname=XySubFilter.dll" "Pre-requisites\XySubFilter.x64.dll"
			${Else}
				File "/oname=XySubFilter.dll" "Pre-requisites\XySubFilter.x86.dll"
			${EndIf}
		${EndIf}
		
		${If} "${ARCH}" == "x64"	
				File "/oname=XySubFilter.dll" "Pre-requisites\XySubFilter.x64.dll"				
		${EndIf}
		
		${If} "${ARCH}" == "x86"	
				File "/oname=XySubFilter.dll" "Pre-requisites\XySubFilter.x86.dll"				
		${EndIf}
		; Don't work ...
		;RegDLL "$INSTDIR\Pre-requisites\XySubFilter.dll"
		ExecWait '"$SYSDIR\regsvr32.exe" /s "$INSTDIR\Pre-requisites\XySubFilter.dll"' 

	SectionEnd

SectionGroupEnd

;--------------------------------
;Installer Sections

Function .onInit	
	${IfNot} ${AtLeastWin7}
		MessageBox MB_OK "Windows Seven and above required"
		Quit
	${EndIf}
	
	System::Call 'kernel32::CreateMutex(i 0, i 0, t "myMutex") ?e'
	Pop $R0
	StrCmp $R0 0 +3
		MessageBox MB_OK "The installer is already running."
		Abort
	StrCpy $switch_overwrite 0
	
	${GetParameters} $R0
	ClearErrors
	Call AbortIfBadFramework
	
	!insertmacro SelectByParameter ${SecMPDN} SELECT_MPDN 1
	!insertmacro SelectByParameter ${SecExtensions} SELECT_EXTENSIONS 1
	
	!insertmacro SelectByParameter ${SecLAVFilter} SELECT_LAV 1
	!insertmacro SelectByParameter ${SecXySubFilter} SELECT_XYSUB 1
	
	!insertmacro MULTIUSER_INIT
	SetShellVarContext all

	; Check if the installer was built for x86_64
	${If} "${ARCH}" == "x64"
		${IfNot} ${RunningX64}
			; User is running 64 bit installer on 32 bit OS
			MessageBox MB_OK|MB_ICONEXCLAMATION "This installer is designed to run only on 64-bit systems."
			Quit
		${EndIf}
		
set64Values:
		SetRegView 64

		; Change the installation directory to C:\Program Files, but only if the
		; user has not provided a custom install location.
		${If} "$INSTDIR" == "$PROGRAMFILES\${PROJECT_NAME}"
			StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECT_NAME}"
		${EndIf}
	${Else}
		${If} "${ARCH}" == "AnyCPU"
			${If} ${RunningX64}
				GoTo set64Values
			${EndIf}
		${EndIf}
	${EndIf}
FunctionEnd

;--------------------------------
;Dependencies

Function .onSelChange
	${If} ${SectionIsSelected} ${SecExtensions}
		!insertmacro SelectSection ${SecMPDN}
	${EndIf}
FunctionEnd

Function StartGUI.show
	; if we killed the GUI to do the install/upgrade, automatically tick the "Start OpenVPN GUI" option
	${If} $strMpdnKilled == "1"
		SendMessage $mui.FinishPage.Run ${BM_SETCHECK} ${BST_CHECKED} 1
	${EndIf}
FunctionEnd

;--------------------
;Post-install section

Section -post

	SetOverwrite on
	SetOutPath "$INSTDIR"
	File "icon.ico"
	Delete $TEMP\Mpdn.zip
	Delete $TEMP\Mpdn_Extensions.zip
	Delete $TEMP\MPDN_Extensions-master

	; Store install folder in registry
	WriteRegStr HKLM "SOFTWARE\${PROJECT_NAME}" "" "$INSTDIR"

	; Create uninstaller
	WriteUninstaller "$INSTDIR\Uninstall.exe"

	; Show up in Add/Remove programs
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" "DisplayName" "${PROJECT_NAME} ${VERSION_STRING} ${SPECIAL_BUILD}"
	WriteRegExpandStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" "DisplayIcon" "$INSTDIR\icon.ico"
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}" "DisplayVersion" "${VERSION_STRING}"

SectionEnd

;--------------------------------
;Descriptions

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SecMPDN} $(DESC_SecMPDN)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecLAVFilter} $(DESC_SecLAVFilter)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecXySubFilter} $(DESC_SecXySubFilter)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecExtensions} $(DESC_SecExtensions)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section

Function un.onInit
	ClearErrors
	!insertmacro MULTIUSER_UNINIT
	SetShellVarContext all
	${If} ${RunningX64}
		SetRegView 64
	${EndIf}
FunctionEnd

Section "Uninstall"

	; Stop OpenVPN-GUI if currently running
	DetailPrint "Stopping ${PROJECT_NAME}..."
	StopGUI:
	
	${nsProcess::FindProcess} "MediaPlayerDotNet.exe" $R0
	${If} $R0 == 0
		${nsProcess::KillProcess} "MediaPlayerDotNet.exe" $R0
	${Else}
		Goto guiClosed
	${EndIf}
	Goto StopGUI


	guiClosed:
	IfFileExists "$INSTDIR\Pre-requisites\XySubFilter.dll" UnRegXy XyNotInstalled
	
	UnRegXy:
	; Don't works
	;UnRegDLL "$INSTDIR\Pre-requisites\XySubFilter.dll"
	ExecWait '"$SYSDIR\regsvr32.exe" /s /u "$INSTDIR\Pre-requisites\XySubFilter.dll"' 
	Delete   "$INSTDIR\Pre-requisites\XySubFilter.dll"
	
	XyNotInstalled:
	Delete "$INSTDIR\icon.ico"
	Delete "$INSTDIR\Uninstall.exe"
	Delete "$INSTDIR\ChangeLog.txt"

	RMDir /r "$INSTDIR\Extensions"
	RMDir /r $INSTDIR
	RMDir /r "$SMPROGRAMS\${PROJECT_NAME}"

	DeleteRegKey HKCR "${PROJECT_NAME}File"
	DeleteRegKey HKLM "SOFTWARE\${PROJECT_NAME}"
	DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}"
	
	${unregisterExtension} ".mkv" "MPDN_MKV_FILE"
	${unregisterExtension} ".avi" "MPDN_AVI_FILE"
	${unregisterExtension} ".mp4" "MPDN_MP4_FILE"

SectionEnd

