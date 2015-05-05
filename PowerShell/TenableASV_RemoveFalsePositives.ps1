# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2013-12-31
# File Type:       PowerShell Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla
# Description:     This is a PowerShell script to remove identified false positives in the Nessus Perimeter Service for PCI ASV scanning because they do not provide a method to remember (and hide) verified false positives.
#
# Notes
# - If you consider this script useful, you should invest in a better ASV.
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

## Set directories
$dirExceptions = "D:\PCI Scans\Exceptions"
$dirScanMe = "D:\PCI Scans\ScanMe"
$dirResults = "D:\PCI Scans\Results"
$dirLogs = "D:\PCI Scans\Logs"

## Set meta
$ver = "1.0"
$lastUpdate = "2013-12-31"
$startTime = Get-Date -format yyyy-MM-dd-HH.mm.ss
$startTimeResults = Get-Date
$Log = "$dirLogs\$startTime.txt"

## List of files
$arrayExceptionFiles = Get-ChildItem -Path $dirExceptions
$arrayScanMeFiles = Get-ChildItem -Path $dirScanMe

## Set up window size for better logging
# If you want to adjust this be sure that the buffersize for width is at a minimum the same size as the windowsize for width
$pshost = get-host
$pswindow = $pshost.ui.rawui

# Set buffer
$newsize = $pswindow.buffersize
$newsize.height = 3000
$newsize.width = 100
$pswindow.buffersize = $newsize

# Set window
$newsize = $pswindow.windowsize
$newsize.height = 50
$newsize.width = 100
$pswindow.windowsize = $newsize

## Start logging
Start-Transcript -path $Log -append | Out-Null

## Talk to the user
Write-Host "==================================================================================================="
Write-Host "Since Tenable's Nessus Perimeter Service won't allow us to ignore verified false positives, we had"
Write-Host "to throw together a script to produce a list of actionable items."
Write-Host "==================================================================================================="
Write-Host "Written by: JZeolla"
Write-Host "Version: $ver"
Write-Host "Last updated: $lastUpdate"
Write-Host "==================================================================================================="
Write-Host "Start time: $startTimeResults"
Write-Host "===================================================================================================`n"

## List all of the files separately
Write-Host "Files(s) to parse:"

FOREACH ( $File in $arrayScanMeFiles )
{	Write-Host "     $File"	}

## Add spacing
Write-Host "`n"

## Gather all the scan results via a file-level loop
FOREACH ( $FileScanMe in $arrayScanMeFiles )
{
  ## Fill "ArrayScanMe" with scan results
  Try
  {	
    $ArrayScanMe = Import-Csv "$dirScanMe\$FileScanMe" -Delimiter "," | select "Plugin ID","CVE","CVSS","Risk","Host","Protocol","Port","Name","Synopsis","Description","Solution","See Also","Plugin Output"
  }
  Catch
  {	"*ERROR*:  Issue importing '$FileScanMe' as a CSV into '$ArrayScanMe'"	}
	
  ## Track the number of False Positives removed from each PCI Scan
  $i = 0

  ## Gather all of the files with exceptions via a file-level loop
  FOREACH ( $FileException in $arrayExceptionFiles )
  {
    Write-Host "Removing exceptions in $FileException from $FileScanMe"

    ## Fill "ArrayException" with the current exceptions file
    Try
    {	$ArrayException = Import-Csv "$dirExceptions\$FileException" -Delimiter "," | select "Plugin ID","CVE","CVSS","Risk","Host","Protocol","Port","Name","Synopsis","Description","Solution","See Also","Plugin Output"	}
    Catch
    {	"*ERROR*:  Issue importing '$FileException' as a CSV into '$ArrayException'"	}

    ## Remove each line in exception from the array holding the ScanMe csv
    # An alternative approach would be to use Compare-Object, but then we wouldn't get the number of false positives which were removed.
    FOREACH ( $Exception in $ArrayException )
    {
      $StartArraySize = @($ArrayScanMe).length
      $ArrayScanMe = $ArrayScanMe | Where-Object -FilterScript `
      {
        if (($_."Plugin ID" -eq $Exception."Plugin ID") -And ` 
            ($_.Host -eq $Exception.Host) -And ` 
            ($_.Protocol -eq $Exception.Protocol) -And ` 
            ($_.Port -eq $Exception.Port))
        {
          $false
        }
        else
        {
          $true
        }
      }
    ## Keep track of the number of false positives removed per PCI Scan
    IF ( $StartArraySize -gt @($ArrayScanMe).length )   {	$i++	}
    }
  }
	
  Write-Host "$i false positives removed from $FileScanMe"
  
	## Dump to file
  IF ( $ArrayScanMe.count -gt 0 )
  {    $ArrayScanMe | Export-Csv "$dirResults\$startTime-$FileScanMe" -Delimiter "," -NoTypeInformation    }
  ELSE
  {    "$FileScanMe has no vulnerabilities above a ranking of 3.99" >> "$dirResults\$startTime-$FileScanMe"    }
	
  Write-Host "$FileScanMe complete. `n"
}

Try
{	$currentResults = Get-ChildItem -Path $dirResults | Where {$_.LastWriteTime -gt $startTimeResults}	}
Catch
{	"*ERROR*:  Unable to calculate the new results"	}

Write-Host "`nDone removing verified false positives.  `n`n"
Write-Host "See:"
FOREACH ( $File in $currentResults )
{	Write-Host "     $File"	}

Write-Host "`n`nPress any key to continue . . ."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")

# Stop logging
Stop-Transcript | Out-Null

# This fixes the transcript formatting without adding a `r`n to each 
# line and making it look horrible in the terminal window,
# or manually duplicating all terminal output to the log
$FixFormat = Get-Content $Log
$FixFormat > $Log
