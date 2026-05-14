Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set wmi = GetObject("winmgmts:\\.\root\cimv2")

scriptFolder = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptFolder, "Start-MystikStudioDashboard.ps1")
bringToFrontPath = fso.BuildPath(scriptFolder, "Bring-MystikStudioDashboardToFront.ps1")

Function SafeStr(value)
    If IsNull(value) Or IsEmpty(value) Then
        SafeStr = ""
    Else
        SafeStr = CStr(value)
    End If
End Function

If Not fso.FileExists(scriptPath) Then
    MsgBox "Cannot find Start-MystikStudioDashboard.ps1 in:" & vbCrLf & scriptFolder, 16, "File Not Found"
    WScript.Quit
End If

dashboardRunning = False
On Error Resume Next
For Each proc In wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name='powershell.exe' OR Name='pwsh.exe'")
    cmdLine = LCase(SafeStr(proc.CommandLine))
    If InStr(cmdLine, LCase("Start-MystikStudioDashboard.ps1")) > 0 Then
        dashboardRunning = True
        Exit For
    End If
Next
On Error Goto 0

If dashboardRunning And fso.FileExists(bringToFrontPath) Then
    command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & bringToFrontPath & """"
    shell.Run command, 0, False
Else
    command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
    shell.Run command, 0, False
End If
