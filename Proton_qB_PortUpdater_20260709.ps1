# USER CONFIGURATION
# Make sure the webUI settings match the port
$qbitUrl = "http://localhost:8080"
# Update this path if your qBittorrent is installed somewhere else (e.g., a custom drive)
$qbitPath = "C:\Program Files\qBittorrent\qbittorrent.exe"

# SYSTEM PATHS
# I don't reckon you'll need to change the path but if it doesn't work try to find the qBittorrent.ini file in your file explorer
$configPath = "$env:APPDATA\qBittorrent\qBittorrent.ini"
# Locates the ProtonVPN logs for the current Windows user
$logFolder = "$env:LOCALAPPDATA\Proton\Proton VPN\Logs"
$lastPort = 0

Write-Host "Peeking at Proton's port" -ForegroundColor Cyan

while ($true) {
    # 1. Find the most recently modified Proton VPN service log file
    if (Test-Path $logFolder) {
        $latestLog = Get-ChildItem -Path $logFolder -Filter "*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestLog) {
            # 2. Read the end of the log file to find the active port assignment
            $logLines = Get-Content $latestLog.FullName -Tail 500
            $portLine = $logLines | Where-Object { $_ -match "Port pair \d+->(\d+)" } | Select-Object -Last 1
            
            if ($portLine -match "Port pair \d+->(\d+)") {
                $activePort = [int]$matches[1]

                # 3. If a new port is detected, begin the update process
                if ($activePort -ne $lastPort) {
                    Write-Host "New port detected: $activePort" -ForegroundColor Green
                    
                    # 4. Push the new port to qBittorrent's configuration via WebUI API
                    $preferences = @{
                        json = "{ `"listen_port`": $activePort }"
                    }
                    
                    try {
                        Invoke-RestMethod -Uri "$qbitUrl/api/v2/app/setPreferences" -Method Post -Body $preferences
                        Write-Host "Port updated over webUI, now proceeding to kill qBittorrent" -ForegroundColor Yellow
						
						# NOTE: If you figure out how to get this process to work without restarting qBittorrent go ahead and modify the code and tell the community
                        
                        # 5. Force close qBittorrent to apply network changes
                        Stop-Process -Name "qbittorrent" -Force -ErrorAction SilentlyContinue
                        Write-Host "qBittorrent, the grete foe, has been felled. Give it a tick while the memory clears" -ForegroundColor Gray
                        
                        # Wait 5 seconds to ensure Windows fully destroys the old network sockets, I'm not even sure if this is necessary I just keep it around for peace of mind
                        Start-Sleep -Seconds 5
                        
                        # 6. Bind qBittorrent specifically to the ProtonVPN network interface, otherwise you can sometimes randomly connect to a phantom interface that does nothing
                        if (Test-Path $configPath) {
                            Write-Host "Configuring qBittorrent to select the real network interface and not the phantom one" -ForegroundColor Cyan
                            
                            # Ask Windows for the ProtonVPN network adapter's unique GUID
                            # NOTE: Ensure "ProtonVPN" exactly matches the adapter name in Windows Network Connections
                            $vpnAdapter = Get-NetAdapter -Name "ProtonVPN" -ErrorAction SilentlyContinue
                            
                            if ($vpnAdapter) {
                                $vpnGuid = $vpnAdapter.InterfaceGuid
                                Write-Host "Found active ProtonVPN interface GUID: $vpnGuid" -ForegroundColor Green
                                
                                $iniContent = Get-Content $configPath
                                
                                # Inject the GUID so qBittorrent knows exactly where to route traffic
                                if ($iniContent -match "^Session\\Interface=") {
                                    $iniContent = $iniContent -replace "^Session\\Interface=.*", "Session\Interface=$vpnGuid"
                                } else {
                                    $iniContent += "Session\Interface=$vpnGuid"
                                }
                                
                                # Hardcode the InterfaceName so the qBittorrent UI displays it correctly
                                if ($iniContent -match "^Session\\InterfaceName=") {
                                    $iniContent = $iniContent -replace "^Session\\InterfaceName=.*", "Session\InterfaceName=ProtonVPN"
                                } else {
                                    $iniContent += "Session\InterfaceName=ProtonVPN"
                                }
                                
                                Set-Content -Path $configPath -Value $iniContent
                                Write-Host "qBittorrent config securely locked to the VPN adapter." -ForegroundColor Green
                            } else {
                                Write-Host "Warning: Could not find an active network adapter named 'ProtonVPN' in Windows." -ForegroundColor Red
                                Write-Host "qBittorrent will likely revert to 'Any interface'." -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "Warning: qBittorrent.ini not found at $configPath" -ForegroundColor Red
                        }
                        
                        # 7. Relaunch qBittorrent to connect cleanly with the new settings
                        if (Test-Path $qbitPath) {
                            Start-Process -FilePath $qbitPath
                            Write-Host "qBittorrent has returned, check your system tray" -ForegroundColor Green
                        } else {
                            Write-Host "Error: Could not find qbittorrent.exe at $qbitPath. Please update the path in the script." -ForegroundColor Red
                        }

                        $lastPort = $activePort
                    }
                    catch {
                        # If qBittorrent wasn't running to receive the API call, just launch it. This is entirely optional and may piss you off at some point in the future so you can delete or comment it out
                        Write-Host "qBittorrent was not running. Launching it now..." -ForegroundColor Yellow
                        if (Test-Path $qbitPath) {
                            Start-Process -FilePath $qbitPath
                            $lastPort = $activePort
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "Log folder not found. Ensure ProtonVPN is installed and running." -ForegroundColor Red
    }
    
    # 8. Wait 60 seconds before checking the logs again, this just preserves resources you can change the timer to whatever you want
    Start-Sleep -Seconds 60
}