Option Explicit

Dim shell, fso, scriptDir, batchPath, command, exitCode

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batchPath = scriptDir & "\publish-blog.bat"

If Not fso.FileExists(batchPath) Then
  MsgBox "Publish script not found:" & vbCrLf & batchPath, vbCritical, "GitHub Blog Publish"
  WScript.Quit 1
End If

command = "cmd.exe /c """ & batchPath & """"
exitCode = shell.Run(command, 1, True)

If exitCode <> 0 Then
  MsgBox "Publish script failed with exit code: " & exitCode & vbCrLf & "Check the command window for details.", vbExclamation, "GitHub Blog Publish"
End If
