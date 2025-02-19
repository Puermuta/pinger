# Variables and arrays
$clientCount = 0
$quarantineCount = 0
$quarantineHostnames = New-Object System.Collections.ArrayList
$quarantineIps = New-Object System.Collections.ArrayList

# Retrieves the config from config.txt.
$config = Get-Content ".\config.txt" | Where-Object { $_ -notmatch "^\s*#" -and $_.Trim() -ne "" }

foreach ($line in $config) {
    $key, $value = $line -split "="
    Set-Variable -Name $key -Value $value
}

# Initialize an empty hashtable to store categories
$hostGroups = @{}

# Read the content of the file
$lines = Get-Content "hostnames.txt"

# Variable to keep track of the current category
$currentCategory = ""

foreach ($line in $lines) {
    $trimmedLine = $line.Trim()

    if ($trimmedLine -match "^(.*):$") {  # Match lines ending with ":"
        $currentCategory = $matches[1]
        $hostGroups[$currentCategory] = @()  # Create an empty array for this category
    }
    elseif ($trimmedLine -ne "" -and $currentCategory -ne "") {  # Ignore empty lines
        $hostGroups[$currentCategory] += $trimmedLine
    }
}

function checkIpAddress {
    param (
        [string]$hostname
    )

    try {
        # Resolve the DNS name to get the IP address
        $ipAddress = Resolve-DnsName -Name $hostname -ErrorAction Stop | Select-Object -First 1 -ExpandProperty IPAddress

        # Check if an IP address was found
        if ($ipAddress) {
	    $ipParts = $ipAddress.Split('.')

            # Checks if the last octet is above or equal to the quarantine number.
            $lastOctet = [int]$ipParts[-1]
            if ($lastOctet -ge $quarantineLower) {
        # Increments the quarantineCount, adds the hostname to quarantineHostnames, and adds the IP to quarantineIps.
		$global:quarantineCount += 1
		$quarantineHostnames.Add($hostname)
        $quarantineIps.Add($ipAddress)
            }
        }
    } catch {
        Write-Error "Error resolving the hostname ${hostname}: $_"
    }
}


function pingHost {
	param (
	   [string]$hostname
	)
	
    # Adds the suffix to the hostname. Example: hostname + .local
	$hostnameWithLocal = $hostname + $suffix
        # Pings a given hostname with one packet.
    	$ping = Test-Connection -ComputerName $hostnameWithLocal -Count $queryCount -Quiet

    	if ($ping) {
		    $global:clientCount += 1
		    checkIpAddress -hostname $hostnameWithLocal
    	}
}

function main {
    param (
        [string[]]$hostnames
    )

    # Reset the variables.
    $global:clientCount = 0
    $global:quarantineCount = 0
    $global:quarantineHostnames = New-Object System.Collections.ArrayList
    $global:quarantineIps = New-Object System.Collections.ArrayList

    # While searching. Iterates over hostnames written in hostnames.txt.
    foreach ($hostname in $hostnames) {
	    Clear-Host
	    Write-Host "Pinging $hostname" -ForegroundColor yellow
        Write-Host ""
	    Write-Host "Local clients found: $clientCount"
	    Write-Host "Clients in quarantine: $quarantineCount"

	    pingHost -hostname $hostname # Runs pingHost function.
    }

    # End state
    Clear-Host
    Write-Host "Done." -ForegroundColor green
    Write-Host ""
    Write-Host "Local clients found: $clientCount"

    # Genereate table for easier lookups.
    if ($quarantineCount -gt 0) {
	    Write-Host "Clients in quarantine: " -NoNewLine
        $table = @()
        for ($i = 0; $i -lt $quarantineHostnames.Count; $i++) {
            $table += [PSCustomObject]@{
                'Hostname' = $quarantineHostnames[$i]
                'IP address' = $quarantineIps[$i]
            }
        }  
        $table | Format-Table -AutoSize
    } else {
    	Write-Host "No clients in quarantine."
    }

    Write-Host "Press ENTER to run tests again, or Q to exit."
    while ($true) {
        $key = [System.Console]::ReadKey($true)
        if ($key.Key -eq "Enter") {
            main -hostnames $hostnames
        }
        if ($key.Key -eq "Q") {
            exit
        }
    }
}

# Start menu
Clear-Host
Write-Host "Enter which config to ping:" -ForegroundColor darkgreen

$tempCount = 0
$selectionArray = @()
$hostGroups.GetEnumerator() | ForEach-Object {
    Write-Host "${tempCount}: " -noNewLine -ForeGroundColor green
    Write-Host "Category: $($_.Key)"
    $selectionArray += $_.Key
    $tempCount += 1
}
Write-Host ""

while ($true) {
    $key = [System.Console]::ReadKey($true).KeyChar  # Get the actual key character

    # Convert the character to an integer by subtracting the ASCII value of '0'
    if ($key -match '^\d$') {
    	$index = [int]$key - 48  # Convert to integer
	$selectedGroup = $($selectionArray[$index])
	main -hostname ($hostGroups[$selectedGroup])
    }
}
