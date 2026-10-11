' Lance un script PowerShell sans fenetre console (pas de flash ni de vol de
' focus au jeu) : wscript run-hidden.vbs <script.ps1> [arguments...]
Dim args, i
args = ""
For i = 1 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & WScript.Arguments(0) & """" & args, 0, False
