<#################################################################################################################################################
# oracle with PowerShell version 2.0


Assumption:

1.There should be common credentials for all database servers.

2.Script will take in credentials to connect Only once and connect to all databases listed in TNS in sequential way using the credentials taken in the begining

3.There should not be dulicate entry for any database in tnsnames.ora file


Algorithm

1. Script run from desktop.
	a) user have to manually create a shortcut on desktop for window powershell(x86).
	b) user need to set target of shortcut as {<powershell.exe location> -nologo -command "& '<script location>'}
	c) script will run by double-clicking on icon on desktop.


e.g=>    %SystemRoot%\syswow64\WindowsPowerShell\v1.0\powershell.exe -nologo -command "& 'C:\kanchan_or\del.ps1'


2. After execution of the script user credentials needs to be entered.

3. If credentials are wrong script will terminate else it will ask about the username which is to be deleted from database. Message noted in error log

4. If username exist in the database script then execution of the script will proceed else it will get terminated.Message noted in error log

5. Check the database, if user is mapped with any object. 

5.a. If Yes, Pulled all the details of user mapped objects . Lock that user and send mail to database team

5.b.If No, take backup of user (keep it in pre-defined location) & delete it. Send completion mail.

6.In case of any Error output will be stored in Errorlog file

#################################################################################################################################################>




#loading assembly to connect to database

[Reflection.Assembly]::LoadFile("C:\oracle\product\11.2.0\client_1\odp.net\bin\2.x\Oracle.DataAccess.dll")


#Enter filepath of tns entries

$tnsfile = "C:\sql\tnsnames.ora"


#Enter the directory where output files will be store

$path="C:\kanchan_or"


#Enter USERID and PASSWORD to login into the database

$userid=Read-Host "ENTER USER ID TO LOGIN INTO DATABASE "
$pass=Read-Host "ENTER PASSWORD" -AsSecureString
$password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))



#Remove output files if these already exist in the directory excluding .p1 files

Remove-Item $PATH\*  -include *-output.txt*  -Exclude *.ps1*

Remove-Item $PATH\*  -include *-Errorlog.txt*  -Exclude *.ps1*
$date=Get-Date -Format "dd-MM-yyyy"


#getting tns entries for each databse one by one using forloop

                [object[]] $tnsEntries = @() 
                [string] $data = gc $tnsfile | ? {!$_.StartsWith('#')}
                $lines = $data.Replace("`n","").Replace(" ","").Replace("`t","").Replace(")))(","))(").Replace(")))",")))`n").Replace("=(","=;").Replace("(","").Replace(")",";").Replace(";;",";").Replace(";;",";").Split("`n")
                foreach($line in $lines)
                {
                $error.clear()
                    if ($line.Trim().Length -gt 0)
                    {
                        $lineBreakup = ConvertFrom-StringData -StringData $line.Replace(";","`n")
                        $entryName = $line.Split("=")[0]
                        $tnsEntry = New-Object System.Object 
                        
                        $entryName | Out-File $path\db.csv -Append
                        try{
                        #building and opening connection with oracle database
                        $constr = "Data Source=(DESCRIPTION =
                                    (ADDRESS_LIST =
                                      (ADDRESS = (PROTOCOL =" + $lineBreakup["PROTOCOL"] + ")(HOST ="+ $lineBreakup["Host"] +")(PORT =" + $lineBreakup["Port"] + "))
                                    )
                                    (CONNECT_DATA =
                                      (SERVICE_NAME =" + $(if ($lineBreakup["SERVICE_NAME"] -eq $null) {$lineBreakup["SID"]} else {$lineBreakup["SERVICE_NAME"]}) + ")
                                    )
                                  );User Id=$userid;Password=$password;"
                        $conn= New-Object Oracle.DataAccess.Client.OracleConnection($constr)
                       
                            $conn.Open()
                            $database=$(if ($lineBreakup["SERVICE_NAME"] -eq $null) {$lineBreakup["SID"]} else {$lineBreakup["SERVICE_NAME"]})
                                                        
                            Write-host "Opening Connection For $database"        
                                                       
                           }catch{
                           write-host "INVALID CREDENTIALS... !!!" -ForegroundColor RED
                           write-output "INVALID CREDENTIALS... !!!"|out-file $path\$date-ErrorLog.txt -append
                           
                           
                           EXIT
                           }


				
                           
                           $user=Read-Host "ENTER USER NAME TO PERFORM ACTION (DELETE/LOCK)"
                                                     
                            
                            #check if user exist or not
                            try{
                            
                            $sql0 = @"
                            select username,created,account_status from dba_users where username = upper('$user')
"@
                            
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($sql0,$conn)
                            $reader=$command.ExecuteReader()
                          
                            #reading and saving query output value
                            while($reader.Read())
                            {
                                $output=$reader.GetValue(0)
                                $output1=$reader.GetValue(1)
                                $output2=$reader.GetValue(2)
                                
                                                             
                            }
                            }catch{}
                            
                            #True Condition if user exist then give uername,account_status,current timestamp

                            if($output -eq $user)
                            {
                            Write-Output "Opening Connection For $database `n"|out-file $path\$user-output.txt -Append
                           Write-Output " "|out-file $path\$user-output.txt -Append
                            Write-Output "--1.check whether user/service account existing or not"|out-file $path\$user-output.txt -Append
                            $output |out-file $path\$user-output.txt -Append
                            $output1 |out-file $path\$user-output.txt -Append
                           $output2 |out-file $path\$user-output.txt -Append
                            
                            Write-Output "`n`n"|out-file $path\$user-output.txt -Append
                            
                            Write-Output "User Exist Continue......"
                             
                                   
                                   
                                 
                       
                            #2. Running Other query 1  : getting profile information  
                            try{
                            $query1 = @"
                            select distinct profile as mprofile from dba_profiles where  profile in (select profile from dba_users where username = upper('$user'))

"@
                             Write-Output "--2.Check the profile information which we assigned to User or service account"|out-file $path\$user-output.txt -Append
                            
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($query1,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $mprofile=$reader.GetValue(0)
                                    $mprofile|out-file $path\$user-output.txt -Append
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append
                                }
                                
                                }catch{}
                                
                                
                            #2. Running Other Query 2 : passing value of mprofile
                            try{
                            
                            $query2 = @"
                            SELECT DBMS_METADATA.GET_DDL('PROFILE', upper('$mprofile')) from Dual
"@
                             #Write-Output "-- selecting metadatafor user profile"|out-file $path\$user-output.txt -Append
                            
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($query2,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append 
                                      Write-Output "`n"|out-file $path\$user-output.txt -Append                                  
                                }
                                
                                }catch{}
                                   
                            #2. Running Other Query 3 : selecting metadata for user profile
                            
                            try{
                            
                            $query3 = @"
                            select dbms_metadata.get_ddl('USER', username) || '/' usercreate frOM dba_users where username IN UPPER('$user')
"@
                            
                            #Write-Output "-- selecting metadatafor user profile"|out-file $path\$user-output.txt -Append
                             
                           
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($query3,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append
                                    Write-Output "`n`n"|out-file $path\$user-output.txt -Append
                                    
                                }
                                
                                }catch{}
                            
                            
                            #3.
                            # Running Other Query 1 : getting metadata information of the user for system_grant
                            try{
                            $Orcl1 = @"
                            SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT',upper('$user')) from dual

"@
                            
                            Write-Output "--3.check the Metadata information on user/schema"|out-file $path\$user-output.txt -Append
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($Orcl1,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append  
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append                                 
                                }
                            }catch{
                            
                            }
                            
                            #3.
                            # Running Other Query 2: getting metadata information of the user for role_grant
                            try{
                            $Orcl2 = @"
                            SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT',upper('$user')) from dual

"@
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($Orcl2,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append 
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append
                                }
                                
                                }catch{}
                            
                            
                            #3.
                             #Running Other Query 3: getting metadata information of the user for object grant

                            try{
                            $Orcl3 = @"
                                     
                                        SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT','$user') from dual


"@
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($Orcl3,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append                                
                                }
                            }catch{}
                            
                            
                            #3.
                            # Running Other Query 4: getting metadata information of the user for system grant
                            try{
                            $Orcl4 = @"
                                     SELECT dbms_metadata.get_ddl('USER',upper('$user')) FROM dual
                                     
"@
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($Orcl4,$conn)
                            $reader=$command.ExecuteReader()
                          
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append  
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append                                 
                                }
                            
                                }catch{}
                          
####################################################################
#CODING FOR CHECKING OBJECT DOES EXIST OR NOT
###################################################################

                           
                         
                            $object = @"
                            Select object_name,object_type from dba_objects where owner = upper('$user')
"@
                            Write-Output "--4.check the any object are  created under user/service account.."|out-file $path\$user-output.txt -Append
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($object,$conn)
                            $reader=$command.ExecuteReader()
                       $count=$null
                                #reading and saving query output value
                                while($reader.Read())
                                {
                                    $count=$reader.GetValue(0)
                                     
                                    
                                    #$count1=$reader.GetValue(1)  
                                    #$count2=$reader.GetValue(2)  
                                      
                                    $count|out-file $path\$user-output.txt -append
                                    
                                    #$count1|out-file $path\$user-output.txt
                                    #$count2|out-file $path\$user-output.txt
                                   Write-Output "`n`n"|out-file $path\$user-output.txt -Append
                                   
                                   
                                    }
                                    
                                   
                                
                                
# CODE WHEN OBJECT EXIST

if($count -ge 1)
{
Write-Host "OBJECT EXIST for $user "
Write-Host "$count"

$email_to=read-host "Please Enter Email Address To Sent Email "
################################################


try{
                            
$data1 = @"
         Select 'Grant '||granted_role||' to ' || grantee ||' '|| decode(admin_option, 'YES', ' with admin option', '')||';'
         from dba_role_privs where grantee in upper(('$user'))                                   
"@

                             
                            
                            Write-Output "--Query to get the priviledges"|out-file $path\$user-output.txt -Append
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data1,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n "|out-file $path\$user-output.txt -Append                                
                                
                            }
                            
                            }catch{}
                                
###################################
try{

$data2 = @"                                    
        Select 'Grant '||privilege||' to ' || grantee || ' '|| decode(admin_option, 'YES', ' with admin option', '')||';'
        from dba_sys_privs where grantee in upper(('$user'))                                    
"@
                           
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data2,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append 
                                    Write-Output "`n "|out-file $path\$user-output.txt -Append                                
                                 
                            }
                            
                            }catch{}
                            
                            
##############################################

try{

$data3 = @"
Select 'Grant '||privilege||' on '|| owner ||  '.' ||  table_name||' to ' || grantee || ' '|| decode(grantable, 'YES', ' with grant option', '')|| decode(hierarchy, 'YES', ' with hierarchy option', '')|| ';'
from dba_tab_privs where grantee in upper(('$user')) 
union 
Select 'Grant '||privilege||' ('||column_name||') on ' || owner ||  '.' ||  table_name|| ' to ' || grantee || ' '|| decode(grantable, 'YES', ' with grant option', '')||';'
from dba_col_privs where grantee in upper(('$user'))                                    
"@
                            
                            
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data3,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append    
                                    Write-Output "`n `n"|out-file $path\$user-output.txt -Append                                
                                
                            }
                            
                            }catch{}
                            
                            
                            
#Code for locking user account

#Query for locking user

$lock = @"
alter user $user account lock                                     
"@
                            Write-Output "-- query for locking user account"|out-file $path\$user-output.txt -Append
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($lock,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                            $reader.GetValue(0)|out-file $path\$user-output.txt -Append    
                            Write-Output "`n `n "|out-file $path\$user-output.txt -Append                                
                                                                  
                            }
                            
                           
                            
                            

#sending mail from local machine
Write-Host "$user Has Object Roles Hence This Account Has Been Locked" -ForegroundColor Blue
if($email_to -match "@toyota.com")
{
    $email_to=$email_to
}
else
{
    $email_to=$email_to+"@toyota.com"
}
                            $olMailItem = 0
                            $olApp = new-object -comobject outlook.application 
                            $NewMail = $olApp.CreateItem($olMailItem) 
                            $NewMail.Subject = "user is locked" 
                            $NewMail.To = $email_to
                            $NewMail.Body = "$user Has Object Roles Hence This Account Has Been Locked.. From $database" 
                            $NewMail.Send()                            



}#End of if condtion WHEN OBJECT EXIST
                            
#IF USER DOES NOT HAVE OBJECT 
else
{
Write-Host "OBJECT DOES NOT EXIST for $user "
$email_to=read-host "Please Enter Email Address To Sent Email "
################################################
try{
$data1 = @"
         Select 'Grant '||granted_role||' to ' || grantee ||' '|| decode(admin_option, 'YES', ' with admin option', '')||';'
         from dba_role_privs where grantee in upper(('$user'))                                   
"@
                            Write-Output "--Query to get the priviledges"|out-file $path\$user-output.txt -Append
                            Write-Output "`n"|out-file $path\$user-output.txt -Append 
                             
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data1,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                                    $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append                                

                            
                            }
                            
                            }catch{}
                                
###################################
try{

$data2 = @"                                    
        Select 'Grant '||privilege||' to ' || grantee || ' '|| decode(admin_option, 'YES', ' with admin option', '')||';'
        from dba_sys_privs where grantee in upper(('$user'))                                    
"@
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data2,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                            $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append    
                            }
                            
                            }catch{}
                            
                            
##############################################

try{
$data3 = @"
Select 'Grant '||privilege||' on '|| owner ||  '.' ||  table_name||' to ' || grantee || ' '|| decode(grantable, 'YES', ' with grant option', '')|| decode(hierarchy, 'YES', ' with hierarchy option', '')|| ';'
from dba_tab_privs where grantee in upper(('$user')) 
union 
Select 'Grant '||privilege||' ('||column_name||') on ' || owner ||  '.' ||  table_name|| ' to ' || grantee || ' '|| decode(grantable, 'YES', ' with grant option', '')||';'
from dba_col_privs where grantee in upper(('$user'))                                    
"@
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($data3,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                            $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append 
                            }
                            
                            }catch{}
                            
#Code for delete user account

#Query for Deleting user

$del = @"
Drop user $user                                    
"@
                              
                             Write-Output " --query to delete user"|out-file $path\$user-output.txt -Append  
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($del,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                            
                            $reader.GetValue(0)|out-file $path\$user-output.txt -Append   
                                    Write-Output "`n"|out-file $path\$user-output.txt -Append
                                                             
                            }
                            
                            
                            
                            

#sending mail from local machine
Write-Host "$user Has Been Deleted " -ForegroundColor Blue

if($email_to -match "@toyota.com")
{
    $email_to=$email_to
}
else
{
    $email_to=$email_to+"@toyota.com"
}
                            $olMailItem = 0                           
                            $olApp = new-object -comobject outlook.application 
                            $NewMail = $olApp.CreateItem($olMailItem) 
                            $NewMail.Subject = "User Deletion Info" 
                            $NewMail.To = $email_to
                            $NewMail.Body = "$user Has Been Deleted.. From $database" 
                            #$newMail.Attachments.Add($file1) 
                            $NewMail.Send()




}#End of if condition IF USER DOES NOT HAVE OBJECT                         
                            
                            
                                   
                            }#End of if condition if USER EXIST
                            else
                            {   
                            Write-Output "$user Does Not Exist in Database $database"|out-file $path\$date-ErrorLog.txt -Append 
                            Write-HOST "$user Does Not Exist in Database $database" -ForegroundColor RED
                           
                                  
                                 
                            #Query for locking user
                            
                            
                            $time = @"
                            select current_timestamp from dual                                     
"@
                            $command = New-Object Oracle.DataAccess.Client.OracleCommand($time,$conn)
                            $reader=$command.ExecuteReader()
                            #reading and saving query output value
                            while($reader.Read())
                            {
                            $reader.GetValue(0)                                  
                            }
                                  
                            }
                                
                                
                            #closing oracle database connection
                            $conn.Close()
                            Write-host 'connection closed'
                                                       
                
                }#end of if
                
                else
                {
                Write-Output ""
                }
    

#Write-Host "End fo line"
$output=$null
$database=$null
                                
}
#End of PowerShell Script
