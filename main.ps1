# Retrieves the config from config.txt.
$config = Get-Content ".\config.txt" | Where-Object { $_ -notmatch "^\s*#" -and $_.Trim() -ne "" }

foreach ($line in $config) {
    $key, $value = $line -split "="
    Set-Variable -Name $key -Value $value
}

# Retrieves the hostnames from hostnames.txt.
$hostnames = Get-Content ".\hostnames.txt"

# Variables and arrays
$clientCount = 0
$quarantineCount = 0
$quarantineHostnames = New-Object System.Collections.ArrayList
$quarantineIps = New-Object System.Collections.ArrayList


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
    	$ping = Test-Connection -ComputerName $hostnameWithLocal -Count 1 -Quiet

    	if ($ping) {
		    $global:clientCount += 1
		    checkIpAddress -hostname $hostnameWithLocal
    	}
}

function main {

    # While searching
    foreach ($hostname in $hostnames) {
	Clear-Host
	Write-Host "Pinging $hostname" -ForegroundColor yellow
	Write-Host "Local clients found: $clientCount"
	Write-Host "Clients in quarantine: $quarantineCount"

	pingHost -hostname $hostname
    }

    # End state
    Clear-Host
    Write-Host "Done." -ForegroundColor green
    Write-Host "Local clients found: $clientCount"
    if ($quarantineCount -gt 0) {
	Write-Host "Clients in quarantine: "
	$quarantineHostnames
    } else {
    	Write-Host "No clients in quarantine."
    }
    Write-Host "" 
}

# Run the function
main
