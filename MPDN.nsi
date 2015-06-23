; ****************************************************************************
; * Copyright (C) 2002-2010 OpenVPN Technologies, Inc.                       *
; * Copyright (C)      2012 Alon Bar-Lev <alon.barlev@gmail.com>             *
; * Modified for MediaPlayerDotNet by
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
!include "nsProcess.nsh"

; x64.nsh for architecture detection
!include "x64.nsh"

; File Associations
!include "FileAssociation.nsh"

; Replacing in File
!include "ReplaceInFile.nsh"

; Read the command-line parameters
!insertmacro GetParameters
!insertmacro GetOptions

!insertmacro GetParent
 
Var /GLOBAL switch_overwrite
!include 'MoveFileFolder.nsh'

; Windows version check
!include WinVer.nsh


;--------------------------------
;Configuration

;General

; Package name as shown in the installer GUI
Name "${PROJECT_NAME_LONG} (${PROJECT_NAME_SHORT}) ${ARCH} v${VER_MAJOR}.${VER_MINOR}.${VER_BUILD}"

; On 64-bit Windows the constant $PROGRAMFILES defaults to
; C:\Program Files (x86) and on 32-bit Windows to C:\Program Files. However,
; the .onInit function (see below) takes care of changing this for 64-bit 
; Windows.
InstallDir "$PROGRAMFILES\${PROJECT_NAME_SHORT}"

; Installer filename
OutFile "${PROJECT_NAME}_${ARCH}_${VER_MAJOR}_${VER_MINOR}_${VER_BUILD}_${VER_REV}_Installer.exe"

ShowInstDetails show
ShowUninstDetails show

;Remember install folder
InstallDirRegKey HKLM "SOFTWARE\${PROJECT_NAME}_${ARCH}" ""

;--------------------------------
;Modern UI Configuration

; Compile-time constants which we'll need during install
!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation of ${PROJECT_NAME_SHORT}${SPECIAL_BUILD}.$\r$\n$\r$\nInstaller by Antoine Aflalo and Zach Saw."

!define MUI_COMPONENTSPAGE_TEXT_TOP "Select the components to install/upgrade.  Stop any ${PROJECT_NAME_SHORT} processes.  All DLLs are installed locally."

!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\ChangeLog.txt"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Show Changelog"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_RUN_TEXT "Start ${PROJECT_NAME_LONG} (${PROJECT_NAME_SHORT})"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PROJECT_NAME}.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED

!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_ABORTWARNING
!define MUI_ICON "icon.ico"
!define MUI_UNICON "uninst.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "install-whirl.bmp"
!define MUI_UNFINISHPAGE_NOAUTOCLOSE

!define MUI_PAGE_CUSTOMFUNCTION_SHOW Welcome.show
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE Welcome.leave
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryGUI.show
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_PAGE_CUSTOMFUNCTION_SHOW StartGUI.show
!insertmacro MUI_PAGE_FINISH

!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.ModifyUnWelcome
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE un.LeaveUnWelcome
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

Var /Global strMpdnKilled ; Track if GUI was killed so we can tick the checkbox to start it upon installer finish
Var /Global removeLocalData ; Track if the user wants to remove the local data also
Var /Global removeExtensions ; Track if the user wants to remove the extensions folder
Var /Global isUpgrading

;--------------------------------
;Languages
 
!insertmacro MUI_LANGUAGE "English"
  
;--------------------------------
;Language Strings

LangString DESC_SecMPDN ${LANG_ENGLISH} "Install ${PROJECT_NAME_LONG} (${PROJECT_NAME_SHORT}), the player. This is required."

LangString DESC_SecLAVFilter ${LANG_ENGLISH} "Install LAV Filters (may be omitted if already installed)."

LangString DESC_SecXySubFilter ${LANG_ENGLISH} "Install XySubFilter (may be omitted if already installed)."

;--------------------------------
;Reserve Files
  
;Things that need to be extracted on first (keep these lines before any File command!)
;Only useful for BZIP2 compression

ReserveFile "install-whirl.bmp"

;--------------------------------
;Macros

!macro RegisterExtensions
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mkv"    "${PROJECT_NAME_SHORT} MKV Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".avi"    "${PROJECT_NAME_SHORT} AVI Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mkv"    "${PROJECT_NAME_SHORT} MKV Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mp4"    "${PROJECT_NAME_SHORT} MP4 Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".m4v"    "${PROJECT_NAME_SHORT} M4V Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mp4v"   "${PROJECT_NAME_SHORT} MP4V Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".3g2"    "${PROJECT_NAME_SHORT} 3G2 Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".3gp2"   "${PROJECT_NAME_SHORT} 3GP2 Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".3gp"    "${PROJECT_NAME_SHORT} 3GP Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".3gpp"   "${PROJECT_NAME_SHORT} 3GPP Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mov"    "${PROJECT_NAME_SHORT} MOV Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".m2ts"   "${PROJECT_NAME_SHORT} M2TS Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".ts"     "${PROJECT_NAME_SHORT} TS Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".asf"    "${PROJECT_NAME_SHORT} ASF Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wmv"    "${PROJECT_NAME_SHORT} WMV Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wm"     "${PROJECT_NAME_SHORT} WM Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".asx"    "${PROJECT_NAME_SHORT} ASX Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wax"    "${PROJECT_NAME_SHORT} WAX Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wvx"    "${PROJECT_NAME_SHORT} WVX Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wmx"    "${PROJECT_NAME_SHORT} WMX Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".wpl"    "${PROJECT_NAME_SHORT} WPL Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".dvr-ms" "${PROJECT_NAME_SHORT} DVR-MS Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".avi"    "${PROJECT_NAME_SHORT} AVI Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mpg"    "${PROJECT_NAME_SHORT} MPG Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".mpeg"   "${PROJECT_NAME_SHORT} MPEG Video File"
    ${registerExtension} "$INSTDIR\${PROJECT_NAME}.exe" ".m1v"    "${PROJECT_NAME_SHORT} M1V Video File"
!macroend

!macro UnregisterExtensions
    ${unregisterExtension} ".mkv"    "${PROJECT_NAME_SHORT} MKV Video File"
    ${unregisterExtension} ".avi"    "${PROJECT_NAME_SHORT} AVI Video File"
    ${unregisterExtension} ".mkv"    "${PROJECT_NAME_SHORT} MKV Video File"
    ${unregisterExtension} ".mp4"    "${PROJECT_NAME_SHORT} MP4 Video File"
    ${unregisterExtension} ".m4v"    "${PROJECT_NAME_SHORT} M4V Video File"
    ${unregisterExtension} ".mp4v"   "${PROJECT_NAME_SHORT} MP4V Video File"
    ${unregisterExtension} ".3g2"    "${PROJECT_NAME_SHORT} 3G2 Video File"
    ${unregisterExtension} ".3gp2"   "${PROJECT_NAME_SHORT} 3GP2 Video File"
    ${unregisterExtension} ".3gp"    "${PROJECT_NAME_SHORT} 3GP Video File"
    ${unregisterExtension} ".3gpp"   "${PROJECT_NAME_SHORT} 3GPP Video File"
    ${unregisterExtension} ".mov"    "${PROJECT_NAME_SHORT} MOV Video File"
    ${unregisterExtension} ".m2ts"   "${PROJECT_NAME_SHORT} M2TS Video File"
    ${unregisterExtension} ".ts"     "${PROJECT_NAME_SHORT} TS Video File"
    ${unregisterExtension} ".asf"    "${PROJECT_NAME_SHORT} ASF Video File"
    ${unregisterExtension} ".wmv"    "${PROJECT_NAME_SHORT} WMV Video File"
    ${unregisterExtension} ".wm"     "${PROJECT_NAME_SHORT} WM Video File"
    ${unregisterExtension} ".asx"    "${PROJECT_NAME_SHORT} ASX Video File"
    ${unregisterExtension} ".wax"    "${PROJECT_NAME_SHORT} WAX Video File"
    ${unregisterExtension} ".wvx"    "${PROJECT_NAME_SHORT} WVX Video File"
    ${unregisterExtension} ".wmx"    "${PROJECT_NAME_SHORT} WMX Video File"
    ${unregisterExtension} ".wpl"    "${PROJECT_NAME_SHORT} WPL Video File"
    ${unregisterExtension} ".dvr-ms" "${PROJECT_NAME_SHORT} DVR-MS Video File"
    ${unregisterExtension} ".avi"    "${PROJECT_NAME_SHORT} AVI Video File"
    ${unregisterExtension} ".mpg"    "${PROJECT_NAME_SHORT} MPG Video File"
    ${unregisterExtension} ".mpeg"   "${PROJECT_NAME_SHORT} MPEG Video File"
    ${unregisterExtension} ".m1v"    "${PROJECT_NAME_SHORT} M1V Video File"
!macroend

!macro UninstallCommon
    ${If} $removeExtensions == "1"
        RMDir /r "$INSTDIR\Extensions"
    ${EndIf}
    RMDir /r "$INSTDIR\Native"
    Delete "$INSTDIR\*.*"
    RMDir /r "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}"
    Delete "$DESKTOP\${PROJECT_NAME_SHORT} ${ARCH}.lnk"

    !insertmacro UnregisterExtensions
!macroend

!macro SelectByParameter SECT PARAMETER DEFAULT
    ${GetOptions} $R0 "/${PARAMETER}=" $0
    ${If} ${DEFAULT} == 0
        ${If} $0 == 1
            !insertmacro SelectSection ${SECT}
        ${Else}
            !insertmacro UnSelectSection ${SECT}
        ${EndIf}
    ${Else}
        ${If} $0 != 0
            !insertmacro SelectSection ${SECT}
        ${Else}
            !insertmacro UnSelectSection ${SECT}
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
    ${nsProcess::FindProcess} "${PROJECT_NAME}.exe" $R0
    ${If} $R0 == 0
        MessageBox MB_YESNO|MB_ICONEXCLAMATION "To perform the specified operation, ${PROJECT_NAME_SHORT} needs to be closed.$\r$\n$\r$\nClose it now?" /SD IDYES IDNO guiEndNo
        DetailPrint "Closing ${PROJECT_NAME_SHORT}..."
        Goto guiEndYes
    ${Else}
        Goto mpdnNotRunning
    ${EndIf}

    guiEndNo:
        Quit

    guiEndYes:
        ; user wants to close MPDN as part of install/upgrade
        ${nsProcess::FindProcess} "${PROJECT_NAME}.exe" $R0
        ${If} $R0 == 0
            ${nsProcess::KillProcess} "${PROJECT_NAME}.exe" $R0
        ${Else}
            Goto guiClosed
        ${EndIf}
        Sleep 100
        Goto guiEndYes

    guiClosed:
        ; Keep track that we closed the GUI so we can offer to auto (re)start it later
        StrCpy $strMpdnKilled "1"

    mpdnNotRunning:    

SectionEnd


Section /o "Player" SecMPDN

    SetOverwrite on

    ${If} $isUpgrading == "1"
        !insertmacro UninstallCommon
    ${EndIf}
    SetOutPath "$INSTDIR"

    File /r "MPDN\Temp\*.*"    
    File "MPDN\ChangeLog.txt"
    !insertmacro RegisterExtensions

    CreateShortCut "$DESKTOP\${PROJECT_NAME_SHORT} ${ARCH}.lnk" "$INSTDIR\${PROJECT_NAME}.exe" ""
    CreateDirectory "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}"
    CreateShortCut "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}\Changelog.lnk" "$INSTDIR\ChangeLog.txt" ""
    WriteINIStr "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}\MPDN Project Page.url" "InternetShortcut" "URL" "http://forum.doom9.org/showthread.php?t=171120"
    CreateShortCut "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}\${PROJECT_NAME_SHORT} ${ARCH}.lnk" "$INSTDIR\${PROJECT_NAME}.exe" ""
    CreateShortCut "$SMPROGRAMS\${PROJECT_NAME_SHORT} ${ARCH}\Uninstall ${PROJECT_NAME_SHORT} ${ARCH}.lnk" "$INSTDIR\Uninstall.exe" ""
SectionEnd


SectionGroup "!Dependencies (Advanced)"

    Section /o "LAV Filters" SecLAVFilter

        SetOverwrite on
        SetOutPath "$INSTDIR\Filters"
        File "Pre-requisites\LAVFilters-Installer.exe"
        ExecWait "$INSTDIR\Filters\LAVFilters-Installer.exe"
    SectionEnd

    Section /o "XySubFilter" SecXySubFilter

        SetOverwrite on
        SetOutPath "$INSTDIR\Filters"
        File "/oname=XySubFilter.dll" "Pre-requisites\XySubFilter.${ARCH}.dll"               
        ExecWait '"$SYSDIR\regsvr32.exe" /s "$INSTDIR\Filters\XySubFilter.dll"' 
        IfFileExists "$LOCALAPPDATA\${PROJECT_NAME}\Application.${ARCH}.config" ModifyConfiguration InstallConf
        
        ModifyConfiguration:
			!insertmacro _ReplaceInFile "$LOCALAPPDATA\${PROJECT_NAME}\Application.${ARCH}.config" "<UseXySubFilter>False</UseXySubFilter>" "<UseXySubFilter>True</UseXySubFilter>"
        goto endXy
		
		InstallConf:
		FileOpen $9 $LOCALAPPDATA\${PROJECT_NAME}\Application.${ARCH}.config w
		FileWrite $9 '<Configuration xmlns:yaxlib="http://www.sinairv.com/yaxlib/">$\r$\n'
		FileWrite $9 "<DirectShowSettings>$\r$\n"
		FileWrite $9 "<LoadSubtitles>True</LoadSubtitles>$\r$\n"
		FileWrite $9 "<UseXySubFilter>True</UseXySubFilter>$\r$\n"
		FileWrite $9 "</DirectShowSettings>$\r$\n"
		FileWrite $9 "</Configuration>"
		FileClose $9
		
		endXy:

    SectionEnd

SectionGroupEnd

;--------------------------------
;Installer Sections

Function .onInit    
    ${IfNot} ${AtLeastWin7}
        MessageBox MB_OK "Windows 7 and above required"
        Quit
    ${EndIf}
    
    System::Call 'kernel32::CreateMutex(i 0, i 0, t "MpdnInstaller") ?e'
    Pop $R0
    StrCmp $R0 0 +3
        MessageBox MB_OK "The installer is already running."
        Abort
    StrCpy $switch_overwrite 0
    
    ${GetParameters} $R0
    ClearErrors
    Call AbortIfBadFramework
    
    !insertmacro SelectByParameter ${SecMPDN} SELECT_MPDN 1
    
    !insertmacro SelectByParameter ${SecLAVFilter} SELECT_LAV 1
    !insertmacro SelectByParameter ${SecXySubFilter} SELECT_XYSUB 1
    
    !insertmacro MULTIUSER_INIT
    SetShellVarContext all
    
    ${IF} ${RunningX64}
        SetRegView 64
    ${EndIf}

    ; Check if the installer was built for x86_64
    ${If} "${ARCH}" == "x64"
        ${IfNot} ${RunningX64}
            ; User is running 64 bit installer on 32 bit OS
            MessageBox MB_OK|MB_ICONEXCLAMATION "This installer is designed to run only on 64-bit systems."
            Quit
        ${EndIf}
        
        ; Change the installation directory to C:\Program Files, but only if the
        ; user has not provided a custom install location.
        ${If} "$INSTDIR" == "$PROGRAMFILES\${PROJECT_NAME_SHORT}"
            StrCpy $INSTDIR "$PROGRAMFILES64\${PROJECT_NAME_SHORT}"
        ${EndIf}
    ${EndIf}
    
    StrCpy $isUpgrading "0"
    ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}" "UninstallString"
    StrCmp $R0 "" done
    IfFileExists "$R0" 0 done

uninst:
    ; Set InstDir to current install dir
    ${GetParent} $R0 $R1
    StrCpy $INSTDIR "$R1"
    StrCpy $isUpgrading "1"

    !insertmacro SelectByParameter ${SecLAVFilter} SELECT_LAV 0
    !insertmacro SelectByParameter ${SecXySubFilter} SELECT_XYSUB 0
    
done:
 
FunctionEnd

;--------------------------------
;Dependencies

Function Welcome.show
    ${If} $isUpgrading == "1"
        ${NSD_CreateLabel} 120u 80u 80% 84u "${PROJECT_NAME} ${ARCH} is already installed.$\r$\nInstaller will perform an update.$\r$\n$\r$\n$\r$\n$\r$\n$\r$\n* Clean installation WARNING:$\r$\n$\r$\n        If you have modified or custom extensions,$\r$\n        they will also be deleted!"
        Pop $R0
        SetCtlColors $R0 "" ${MUI_BGCOLOR}
        ${NSD_CreateCheckbox} 120u -18u 50% 12u "Perform a clean install"
        Pop $removeExtensions
        SetCtlColors $removeExtensions "" ${MUI_BGCOLOR}
    ${EndIf}
FunctionEnd

Function Welcome.leave
    StrCpy $removeExtensions "0"
    ${If} $isUpgrading == "1"
        ${NSD_GetState} $removeExtensions $0
        ${If} $0 <> 0
            StrCpy $removeExtensions "1"
        ${Else}
            StrCpy $removeExtensions "0"
        ${EndIf}
    ${EndIf}
FunctionEnd

Function DirectoryGUI.show
    ${If} $isUpgrading == "1"
        FindWindow $R1 "#32770" "" $HWNDPARENT
        GetDlgItem $R2 $R1 1019
        EnableWindow $R2 0
        GetDlgItem $R2 $R1 1001
        EnableWindow $R2 0
    ${EndIf}
FunctionEnd

Function DirectoryGUI.leave
FunctionEnd

Function StartGUI.show
    ; if we killed the GUI to do the install/upgrade, automatically tick the "Start GUI" option
    ${If} $strMpdnKilled == "1"
        SendMessage $mui.FinishPage.Run ${BM_SETCHECK} ${BST_CHECKED} 1
    ${EndIf}
FunctionEnd

;--------------------
;Post-install section

Section -post

    SetOverwrite on
    SetOutPath "$INSTDIR"
    Delete $TEMP\Mpdn.zip

    ; Store install folder in registry
    WriteRegStr HKLM "SOFTWARE\${PROJECT_NAME}_${ARCH}" "" "$INSTDIR"
    
    ; Enable software deinterlacing in LAV Video Decoder
    WriteRegDWORD HKCU "SOFTWARE\LAV\Video" "SWDeintMode" 1

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Show up in Add/Remove programs
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}" "DisplayName" "${PROJECT_NAME_LONG} (${PROJECT_NAME_SHORT}) ${ARCH} v${VER_MAJOR}.${VER_MINOR}.${VER_BUILD}${SPECIAL_BUILD}"
    WriteRegExpandStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}" "DisplayIcon" "$INSTDIR\${PROJECT_NAME}.exe"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}" "DisplayVersion" "${VER_MAJOR}.${VER_MINOR}.${VER_BUILD}"

SectionEnd

;--------------------------------
;Descriptions

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMPDN} $(DESC_SecMPDN)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecLAVFilter} $(DESC_SecLAVFilter)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecXySubFilter} $(DESC_SecXySubFilter)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section

Function un.ModifyUnWelcome
    IfFileExists "$INSTDIR\Extensions\*.*" 0 NoExt
    ${NSD_CreateLabel} 120u -60u 80% 40u "* Remove ${PROJECT_NAME_SHORT} Extensions WARNING:$\r$\n$\r$\n        If you have modified or custom extensions,$\r$\n        they will also be deleted!$\r$\n$\r$\nRemove:"
    Pop $R0
    SetCtlColors $R0 "" ${MUI_BGCOLOR}
    ${NSD_CreateCheckbox} 120u -18u 80u 12u "${PROJECT_NAME_SHORT} Extensions"
    Pop $removeExtensions
    SetCtlColors $removeExtensions "" ${MUI_BGCOLOR}
    ${NSD_CreateCheckbox} 210u -18u 100u 12u "${PROJECT_NAME_SHORT} config files"
    Pop $removeLocalData
    SetCtlColors $removeLocalData "" ${MUI_BGCOLOR}
    Goto Done
NoExt:
    ${NSD_CreateCheckbox} 120u -18u 50% 12u "Remove ${PROJECT_NAME_SHORT} configuration files"
    Pop $removeLocalData
    SetCtlColors $removeLocalData "" ${MUI_BGCOLOR}
Done:
FunctionEnd

Function un.LeaveUnWelcome
    ${NSD_GetState} $removeExtensions $0
    ${If} $0 <> 0
        StrCpy $removeExtensions "1"
    ${Else}
        StrCpy $removeExtensions "0"
    ${EndIf}
    ${NSD_GetState} $removeLocalData $0
    ${If} $0 <> 0
        StrCpy $removeLocalData "1"
    ${Else}
        StrCpy $removeLocalData "0"
    ${EndIf}
FunctionEnd

Function un.onInit
    ClearErrors
    !insertmacro MULTIUSER_UNINIT
    SetShellVarContext all
    ${If} ${RunningX64}
        SetRegView 64
    ${EndIf}
FunctionEnd

Section "Uninstall"

    ${IF} ${RunningX64}
        SetRegView 64
    ${EndIf}
    
    ; Stop exe if currently running
    DetailPrint "Stopping ${PROJECT_NAME_LONG}..."
    StopGUI:
    
    ${nsProcess::FindProcess} "${PROJECT_NAME}.exe" $R0
    ${If} $R0 == 0
        ${nsProcess::KillProcess} "${PROJECT_NAME}.exe" $R0
    ${Else}
        Goto guiClosed
    ${EndIf}
    Goto StopGUI

    guiClosed:

    IfFileExists "$INSTDIR\Filters\XySubFilter.dll" UnRegXy XyNotInstalled
    
    UnRegXy:
    ; Don't works
    ;UnRegDLL "$INSTDIR\Pre-requisites\XySubFilter.dll"
    ExecWait '"$SYSDIR\regsvr32.exe" /s /u "$INSTDIR\Filters\XySubFilter.dll"' 
    Delete   "$INSTDIR\Filters\XySubFilter.dll"
    
    XyNotInstalled:
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$INSTDIR\ChangeLog.txt"
    
    ${If} $removeLocalData == "1"
        Pop $1
        ${If} ${ARCH} == "x64"
            StrCpy $1 "64"
        ${Else}
            ${If} ${ARCH} == "x86"
                StrCpy $1 "86"
            ${Else}
                StrCpy $1 "${ARCH}"
            ${EndIf}
        ${EndIf}
        Delete "$LOCALAPPDATA\${PROJECT_NAME}\Application.$1.config"
        RMDir /r "$LOCALAPPDATA\${PROJECT_NAME}\PlayerExtensions.$1"
        RMDir /r "$LOCALAPPDATA\${PROJECT_NAME}\RenderScripts.$1"
        RMDir /r "$LOCALAPPDATA\${PROJECT_NAME}\ScriptAsmCache.$1"
        RMDir /r "$LOCALAPPDATA\${PROJECT_NAME}\ShaderCache.$1"
        RMDir "$LOCALAPPDATA\MediaPlayerDotNet.exe.dump"
        RMDir "$LOCALAPPDATA\${PROJECT_NAME}" ; Delete the directory ONLY if empty
    ${EndIf}

    !insertmacro UninstallCommon
    RMDir /r "$INSTDIR\Filters"
    RMDir "$INSTDIR"
    
    DeleteRegKey HKLM "SOFTWARE\${PROJECT_NAME}_${ARCH}"
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PROJECT_NAME}_${ARCH}"

SectionEnd

