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
                     $tmp = $txt.split( '.' )
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
else {
    write-Output "Duplicates detected"
    exit 1
}


