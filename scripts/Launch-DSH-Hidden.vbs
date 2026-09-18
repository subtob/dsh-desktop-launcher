' ===================================================================
'  DSH silent launcher trampoline
'
'  Runs launch.bat with a hidden console window, so double-clicking
'  the shortcut does not flash a black cmd window. The PowerShell
'  window that DSH actually runs in still shows normally.
'
'  Argument 1: optional port number (default 3080)
'
'  IMPORTANT: pure ASCII on purpose. Windows consoles here use code
'  page 936 (GBK); UTF-8 text inside script files gets mis-decoded.
' ===================================================================
Option Explicit

Dim fso, shell, base, port, bat, cmdline
Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

base = fso.GetParentFolderName(WScript.ScriptFullName)
bat  = fso.BuildPath(base, "launch.bat")

If Not fso.FileExists(bat) Then
    MsgBox "Cannot find launcher:" & vbCrLf & bat, 16, "DSH"
    WScript.Quit 1
End If

port = "3080"
If WScript.Arguments.Count >= 1 Then
    If Trim(WScript.Arguments(0)) <> "" Then port = Trim(WScript.Arguments(0))
End If

cmdline = """" & bat & """ --port " & port

' 0 = hidden window, False = do not wait
shell.Run cmdline, 0, False
