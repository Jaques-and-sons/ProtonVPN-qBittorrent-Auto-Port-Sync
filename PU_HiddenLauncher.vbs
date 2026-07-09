Set objShell = CreateObject("WScript.Shell")

' IMPORTANT: Change the file path below to the exact location where you saved the .ps1 file, there are indeed supposed to be "" on the left and """ on the right of the file path
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\Path\To\Your\Folder\FileName.ps1""", 0, False