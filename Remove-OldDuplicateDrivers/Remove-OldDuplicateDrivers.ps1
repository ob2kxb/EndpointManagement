# Use this PowerShell script to find and remove old and unused device drivers from the Windows Driver Store
# Explanation: http://woshub.com/how-to-remove-unused-drivers-from-driver-store/
# Action = true is removing the drivers?  
param (
  [boolean] $Action = $true
)

$dismDrivers = dism /online /get-drivers
$dismDrivers = $dismDrivers | Select-Object -Skip 10
$Operation = "DriverName"
$Drivers = @()
foreach ($Driver in $dismDrivers ) {
    $tmp = $Driver
    $txt = $($tmp.Split( ':' ))[1]
    switch ($Operation) {
        'DriverName' { $Name = $txt
                     $Operation = 'DriverFileName'
                     break
                   }
        'DriverFileName' { $FileName = $txt.Trim()
                         $Operation = 'DriverInbox'
                         break
                       }
        'DriverInbox' { $Inbox = $txt.Trim()
                     $Operation = 'DriverClassName'
                     break
                   }
        'DriverClassName' { $ClassName = $txt.Trim()
                          $Operation = 'DriverVendor'
                          break
                        }
        'DriverVendor' { $Vendor = $txt.Trim()
                       $Operation = 'DriverDate'
                       break
                     }
        'DriverDate' { 
                     $tmp = $txt.split( '/' )
                     $txt = "$($tmp[2]).$($tmp[1]).$($tmp[0].Trim())"
                     $Date = $txt
                     $Operation = 'DriverVersion'
                     break
                   }
        'DriverVersion' { $Version = $txt.Trim()
                        $Operation = 'DriverNull'
                        $params = [ordered]@{ 'FileName' = $FileName
                                              'Vendor' = $Vendor
                                              'Date' = $Date
                                              'Name' = $Name
                                              'ClassName' = $ClassName
                                              'Version' = $Version
                                              'Inbox' = $Inbox
                                            }
                        $obj = New-Object -TypeName PSObject -Property $params
                        $Drivers += $obj
                        break
                      }
         'DriverNull' { $Operation = 'DriverName'
                      break
                     }
    }
}
$last = ''
$NotUnique = @()
foreach ( $Driver in $($Drivers | sort Filename) ) {
    if ($Driver.FileName -eq $last  ) {  $NotUnique += $Driver  }
    $last = $Driver.FileName
}
if($NotUnique.count -eq 0){
    write-Output "No duplicates detected"
    exit 0
}

$Drivers | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name DateParsed -Value ([datetime]::ParseExact($_.Date, "yyyy.d.M", $null))
}
  

$NotUnique | Sort-Object FileName | format-table
# search for duplicate drivers 
$DriverList = $NotUnique | select-object -ExpandProperty FileName -Unique
$ToDelete = @()
foreach ( $Driver in $DriverList ) {
  Write-Output "Duplicate driver found"
  $ToDelete += $Drivers | Where-Object { $_.FileName -eq $Driver } | Sort-Object DateParsed -Descending | Select-Object -first 1 | foreach{
      [pscustomobject]@{
          Action = 'Current'
          FileName = ($_.FileName).trim()
          Name = ($_.Name).trim()
          Date = $_.Date
          Vendor = $_.Vendor
          Version = $_.Version
      }
  }
  $ToDelete += $Drivers | Where-Object { $_.FileName -eq $Driver } | Sort-Object DateParsed -Descending | Select-Object -Skip 1 | foreach {
      [pscustomobject]@{
          Action = 'Delete'
          FileName = ($_.FileName).trim()
          Name = ($_.Name).trim()
          Date = $_.Date
          Vendor = $_.Vendor
          Version = $_.Version
      }
  }
}
Write-Output "List of driver version  to remove:" 
$ToDelete | format-Table
# Removing old driver versions

foreach ( $DeleteDriver in ($ToDelete | Where-Object 'Action' -eq 'Delete') ) {
    $Name = $($DeleteDriver.Name).Trim()
    Write-Output "Flagged for deletion: $($DeleteDriver.Vendor) $($DeleteDriver.FileName) $($DeleteDriver.Version)" 
    if($Action){
      Write-Output "pnputil.exe /delete-driver $Name /uninstall /force"
      Invoke-Expression -Command "pnputil.exe /delete-driver $Name /uninstall /force"
    }
}

return $ToDelete | Where-Object 'Action' -eq 'Delete'