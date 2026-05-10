Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptFolder = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptFolder, "Start-CharacterDesign.ps1")

If Not fso.FileExists(scriptPath) Then
    MsgBox "Cannot find Start-CharacterDesign.ps1 in:" & vbCrLf & scriptFolder, 16, "File Not Found"
    WScript.Quit
End If

' Run with VISIBLE window and -NoExit so the error stays on screen
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File """ & scriptPath & """"
shell.Run command, 1, False
