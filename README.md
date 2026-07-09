# ProtonVPN-qBittorrent-Auto-Port-Sync
This is a PowerShell script (and a VBscript to hide it) that fetches your forwarded port and network adapter GUID from ProtonVPN, and injects it into qBittorrent via it's webUI. It basically just automates the changing of the listening port and network adapter and can be configured to run on PC startup.
## Features
* **Set and Forget Port Forwarding:** Scrapes local ProtonVPN logs to catch port assignments.
* **API Integration:** Pushes the new port directly to qBittorrent.
* **Kill Switch Binding:** Automatically injects the ProtonVPN interface GUID into qBittorrent's `.ini` config so traffic *only* routes through the VPN.
* **Silent Execution:** Includes a VBScript launcher to run the PowerShell background monitor invisibly, without hiding the qBittorrent UI itself.

## Prerequisites
* Windows OS
* **ProtonVPN** installed with Port Forwarding enabled in the app.
* **qBittorrent** installed on the same machine, this script was not designed with LAN or docker containers in mind.

## Setup Instructions

### 1. Configure qBittorrent WebUI
For the script to communicate with qBittorrent locally without a password prompt, you must enable and configure the Web User Interface.

1. Open qBittorrent and go to **Tools > Options > WebUI**.
2. Check **Web User Interface (Remote control)**.
3. Set the **Port** to `8080`.
4. Check the box for **Bypass authentication for clients on localhost**.
5. *Crucial:* Go to the **Connection** tab and **UNCHECK** "Use UPnP / NAT-PMP to forward the port from my router".
6. Set **Ban client after consecutive failures** to **Never** *(this is optional I'm not sure if it helps or not)*.

### 2. Download and Configure the Scripts
1. Download `Proton_qB_PortUpdater_XXXXXXXX.ps1` and `PU_HiddenLauncher.vbs` to a folder on your PC (wherever you like), the two files are just sitting there in the main section above.
2. Open `Proton_qB_PortUpdater_XXXXXXXX.ps1` in a text editor. 
    * If you installed qBittorrent anywhere but the default directory, update the `$qbitPath` variable at the top of the script. Otherwise, no changes are needed.
3. Open `PU_HiddenLauncher.vbs` in a text editor.
    * Replace `C:\Path\To\Your\Folder\FileName.ps1` with the actual path to where you saved the PowerShell script.

### 3. Automate with Task Scheduler
To make this run somewhat seamlessly every time you turn on your PC, add it to Windows Task Scheduler.

1. Open **Task Scheduler** and click **Create Task...** (not Basic Task).
2. On the **General** tab:
    * Name it something you'll recognise in the future.
3. On the **Triggers** tab:
    * Click **New...**
    * Begin the task: **At log on**
    * Specific user or Any user (both work).
    * Under Advanced settings, check **Delay task for:** and set it to `1 minute`. *(This gives ProtonVPN time to connect before the script starts, I haven't tested it without the delay so feel free to see if it works without it).*
    * Ensure **Enabled** is checked and click OK.
4. On the **Actions** tab:
    * Click **New...**
    * Action: **Start a program**
    * Program/script: type `wscript.exe`
    * Add arguments: type the path to your VBS file wrapped in quotes. Example: `"C:\Scripts\PU_HiddenLauncher.vbs"`
    * Click OK.

### 4. Network Adapter Naming (Troubleshooting)
The script searches for a network adapter strictly named `ProtonVPN` to bind the application. 
* Open your Windows **Control Panel > Network and Internet > Network Connections**.
* If your ProtonVPN TAP/TUN adapter is named something else (like `Ethernet 2`), right-click it, select **Rename**, and change it exactly to `ProtonVPN`.

## ⚠️ Troubleshooting & Future Updates Disclaimer
*Note: The numbers at the end of the `.ps1` file name represent the date I last updated the script. There will eventually come a time when I stop actively maintaining it.*

This script relies on the specific ways ProtonVPN logs its data and how qBittorrent formats its API and configuration files. If either program releases a major update and this script hasn't been updated yet, it may stop working. 

If that happens, you can easily fix the script yourself by checking the following areas in the .ps1 file:

* **ProtonVPN Log Formatting (Regex):** The script scrapes the Proton logs by searching for the exact phrase `"Port pair \d+->(\d+)"`. If Proton changes the wording in their log files (e.g., to "Assigned Port: 12345"), you will need to update the regex match on those lines (just CTRL+F search `Port pair`) to match the new log format.
* **ProtonVPN Log Location:** The script looks for logs in `$env:LOCALAPPDATA\Proton\Proton VPN\Logs`. If a future Proton update moves the log directory, you will need to update the `$logFolder` variable.
* **qBittorrent WebUI API Endpoint:** The script currently targets qBittorrent's v2 API (`/api/v2/app/setPreferences`). If qBittorrent eventually upgrades to API v3, you will need to update the URL path in the `Invoke-RestMethod` command (around line 43).
* **qBittorrent Config File (.ini) Changes:** The script modifies the `Session\Interface` and `Session\InterfaceName` lines in `qBittorrent.ini`. If qBittorrent renames these settings in a future update, you will need to update the injection logic to match the new `.ini` key names.
* **Network Adapter Name:** The script specifically searches Windows for an adapter named `"ProtonVPN"`. If a future ProtonVPN update forces a different default name for its virtual adapter (and prevents you from renaming it in Windows), you will need to update the `Get-NetAdapter -Name "ProtonVPN"` line to match the new adapter name.
