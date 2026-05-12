'' Version: 001.002.001
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptFolder = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptFolder, "Start-Fusion.ps1")
logPath = fso.BuildPath(scriptFolder, "Fusion_vbs_debug.log")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Cannot find Start-Fusion.ps1 in:" & vbCrLf & scriptFolder, 16, "File Not Found"
    WScript.Quit
End If

command = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -NoExit -File " & Chr(34) & scriptPath & Chr(34)
shell.Run command, 1, False
