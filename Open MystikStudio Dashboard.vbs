Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptFolder = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptFolder, "Start-MystikStudioDashboard.ps1")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Cannot find Start-MystikStudioDashboard.ps1 in:" & vbCrLf & scriptFolder, 16, "File Not Found"
    WScript.Quit
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
shell.Run command, 0, False
