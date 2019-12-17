#PowerShell Script for SQL Service Status Report


#Path to store result of script
$path="D:\SQL\Result"


#Removing old file of this path
Remove-Item $path\* 


#Fetching Server List
$names = Get-content "D:\SQL\AllServers.txt"



#Condition to test server is pingable or not
foreach ($name in $names)
{
  if(Test-Connection -ComputerName $name -Count 1 -ErrorAction SilentlyContinue)
  {
    #Pingable server
    write-output "$name"|out-file $path\pingable_server.txt -Append
  }
  else
  {
    #Not Pingable server
    write-output "$name : is not pingable"|out-file $path\Errorlog.txt -Append
  }
}

#Function to get Credentail
Function Get-Cred
{
    try
    {
        $a=get-credential
        $u = $a.username
        $user = $u.split("\")
        $p = $a.password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p)
        $pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }   
    catch
    {
            $l= New-Object -ComObject wscript.shell
            if($m -eq '1')
            {
                write-host 'Script cancelled'
                $host.SetShouldExit(1)
                exit
            }
            else
            {
                exit
            }
    }       
    return $a
}        

#Calling Get-Cred Function
$Credent=Get-Cred
if($Credent -eq $true)

{
exit
}

#Current Date
$date=GET-DATE -Format G

#Fetching list of pingable servers
$ser=get-content $path\pingable_server.txt

#Condition for Fetching the SQL service status for all servers
$output=foreach($s in $ser)
{
    Try
    {
    gwmi -class win32_service -ComputerName $s -Credential $Credent -ErrorAction "stop" |?{$_.displayname -like '*SQL*'}|select name|foreach{$_.name}|out-file $path\name.txt

    }
    Catch [Exception]
    {
    $err=$_|select exception|foreach{$_.exception}

        if($err -match "User credentials cannot be used for local connections ")
        {

            Write-Output "$s :is a Localhost.User credentials cannot be used for local connections"|out-file $path\ErrorLog.txt -Append
 
        }
        if($err -match "User credentials cannot be used for local connections ")
        {
            continue 
        }

        else
        {
        Write-Host " Pleas Enter valid Username/Password " -ForegroundColor Yellow
        Remove-Item $path\*  -exclude *AllServers*
        exit
 
        }   
     } #End of Catch block
 
#Strong sql services names
$name=Get-Content $path\name.txt

#Fetching sql services infomation by name
foreach($temp in $name)
{
    $service =gwmi -Class win32_service -ComputerName $s -filter "Name='$temp'"
    $servicePID =$service.ProcessID
    $ProcessInfo=gwmi -Class win32_process -ComputerName $s -Filter "ProcessID='$servicePID'"
    $OutputObj  = New-Object -Type PSObject
    $OutputObj | Add-Member -MemberType NoteProperty -Name SystemName -Value $service.SystemName
    $OutputObj | Add-Member -MemberType NoteProperty -Name Name -Value $service.name
    $OutputObj | Add-Member -MemberType NoteProperty -Name state -Value $service.state
    $OutputObj | Add-Member -MemberType NoteProperty -Name displayname -Value $service.displayname
    
    if($service.state -eq 'running')
    {
    
    $OutputObj | Add-Member -MemberType NoteProperty -Name starttime -Value $($Service.ConvertToDateTime($ProcessInfo.CreationDate))
    }
        
    $OutputObj | Add-Member -MemberType NoteProperty -Name Current_Date -Value $date
    $OutputObj
} 
} #End of forech loop

#Storing Sql services information in a csv files
$Output|export-csv $path\output.csv -notypeinformation -ErrorAction "SilentlyContinue"

#conditon to find out difference of current time and starttime of SQL service

import-csv $path\output.csv | % { 
try{
$stime = [datetime]$_.starttime
$etime = [datetime]$_.Current_Date
$TimeDiff = New-TimeSpan $stime $etime
$diff = "{0} days{1} hours{2} minute{3} seconds" -f [Math]::Abs($TimeDiff.get_Days()),[Math]::Abs($TimeDiff.get_Hours()),[Math]::Abs($TimeDiff.get_Minutes()),[Math]::Abs($TimeDiff.get_Seconds())
Write-Output $diff|out-file $path\uptime.txt -Append
}
catch{

Write-Output " "|out-file $path\uptime.txt -Append

}

}

#Converting uptime.txt in a uptime.csv
Get-Content $path\uptime.txt -ErrorAction SilentlyContinue|select @{n='Uptime';e={$_}}|export-csv $path\uptime.csv -NoTypeInformation
$csv1 = @(gc $path\output.csv)
$csv2 = @(gc $path\uptime.csv)
$csv3 = @()

#merging both upper csv files into one csv
for ($i=0; $i -lt $csv1.Count; $i++) 
{
   $csv3 += $csv1[$i] + ',' + $csv2[$i]
}

#Final output of the SQL Serice status
$csv3|out-file $path\SQL_services_status_report.csv -Encoding default

#Removing empty files
get-childItem "$path" | where {$_.length -eq 0} | remove-Item

#Code for header color
#source and destination paths

$sc="$path\SQL_services_status_report.csv"
$de="$path\FinalOutput.xls"

#Final output reports path

$newfile="$path\SQL_services_status_report.xls"

#Funtion to covert csv into excel file
function csvto-excel
{
$xl = new-object  -comobject excel.application
$xl.visible = $true
$Workbook = $xl.workbooks.open("$sc")
$Worksheets = $Workbooks.worksheets
$Workbook.SaveAs("$de",1)
$Workbook.Saved = $True
$xl.Quit()
}
#Calling csvto-excel funtion
csvto-excel

#setting color for header of output file
$excel = new-object  -com Excel.Application  -Property @{Visible =  $false} 
$workbook = $excel.Workbooks.Open($de) # Open the file
$sheet = $workbook.Sheets.Item(1) # Activate the first worksheet
$ColumnMax = ($sheet.UsedRange.Columns).count 
$RowMax = ($sheet.UsedRange.Rows).count 

for($c = 1;  $c -le $ColumnMax; $c++)
{
$sheet.Cells.Item(1,$c).Font.Bold = $true
}
for($k=1; $k -le  $ColumnMax; $k++)
{
$sheet.Cells.Item(1,$k).Interior.ColorIndex = 17
}
$workbook.SaveAs("$newfile") 
$workbook.Saved = $true
$excel.quit() # Quit Excel
[Runtime.Interopservices.Marshal]::ReleaseComObject($excel) # Release COM

#End of powershell script
