#region Notes

<#
This script can be modified to meet the needs of your situation.

HOME FOLDER - Would be an easier task to rename the Home Folder to the new username, unless you already had permissions issues throughout the entire directory like I had.
ROAMING PROFILES- If not using roaming profiles remove the section. If using roaming profiles the files themselves will contain the old names however users will retain all data with new folder name. Can also delete the roaming profiles and start fresh.

#>

#endregion Notes

#region Variables

$ADUsers = Get-ADUser -Filter * -SearchBase "<Enter the DN of the speific User or Group of Users you wish to change>"

#endregion Variables

#region Working Script

foreach ($ADUser in $ADUsers) 
{

#region New Username Variables

    $GivenName = $ADUser.GivenName
	$SurName = $ADUser.Surname
    $oldsam =   $aduser.SamAccountName
    $newsam = $givenname + "." + $surname
    $upnsuffix = ($_.UserPrincipalName -split "@")[1]
    $upnNEW = "$newSAM@DOMAIN.net"
    $HomeDirCheck = Get-ADUser $oldSAM -properties homedirectory
    $CitrixProfile = Get-ChildItem -path "\\fileserver\profile-redirection$\*" 
    $HomeDirFolder = Get-ChildItem -Path "\\fileserver\Personal-Folders\"
    $source = "\\fileserver\Personal-Folders\$oldsam\*"
    $destination = "\\fileserver\personal-folders\$newSAM"

#endregion New Username Variables

#region Change SAM Account

#Checks if username has been changed, if not changed will change to Firstname.Lastname
   If($oldsam -eq "$newsam")
   {
       write-host "Changes not required on $oldsam" -BackgroundColor red
   }
   else{
		Try{
	        Set-ADUser $oldsam -SamAccountName $newSAM -UserPrincipalName $upnNEW -ErrorAction Stop 
            Write-Host "Changes to the user $GivenName $SurName were made!" -ForegroundColor Green
        }
        catch{
            write-error "$_ "
        }
   }		

#endregion Change SAM Account

#region Create Home Folder

#Checks if L drive exists for new username, if not creates new folder for L Drive with new username
    If($HomeDirFolder -contains "$newsam")
    {
        write-host "New folder not required on $GivenName $SurName" -BackgroundColor red
    }
    else{
        Try{
            New-Item -Name $newSAM -ItemType Directory -Path \\fileserver\personal-folders | Out-Null
            Write-Host "Created new folder for $GivenName $SurName" -ForegroundColor Green
        }
        catch{ write-error "$_ " }
        }

#endregion Create Home Folder

#region Set Home Path

#Checks for homepath and directory in AD equal to new username, if not sets it
    If($HomeDirCheck -contains $newSAM)
    {
        write-host "Home Path already set for $GivenName $SurName. No action taken." -BackgroundColor red
    }
    else{
        Try{
            Set-ADUser $newSAM -HomeDirectory "\\fileserver\personal-folders\$newSAM" -HomeDrive L:
            Write-Host "Set HomePath for $GivenName $SurName" -ForegroundColor Green
        }
        catch{
            write-error "$_ "
        }
    }

#endregion Set Home Path

#region Copy old Home Folder to New Home Folder. Remove me if just renaming home folder. See notes

    #region Copy Files

    #Copy files from old L drive to new L drive
    Copy-Item -Path "\\fileserver\Personal-Folders\$oldsam\*" -Destination "\\fileserver\personal-folders\$newSAM" -Recurse
    Write-Host "Copied personal folder to new folder for $GivenName $SurName" -ForegroundColor Green

    #endregion Copy Files

    #region Compare Files and remediate

    #Check all files have been copied to the new folder, if not copies again. If they are will delete the original folder.
    Compare-Object $source $destination -Property Name  -PassThru | Where-Object {$_.SideIndicator -eq "=>"} | % {
        if(-not $_.FullName.PSIsContainer) 
        {
            Write-Host "Not all files have been copied for $GivenName $SurName! Starting copy process"
            Robocopy "\\fileserver\Personal-Folders\$oldsam\*" "\\fileserver\personal-folders\$newSAM" /mir
            Remove-Item "\\fileserver\Personal-Folders\$oldsam" -Recurse
        }
        else{
            Try{
            Write-Host "Deleted old personal folder for $GivenName $SurName" -ForegroundColor Green
        }
            catch{
                write-error "$_ "
            }  
        }
    }

    #endregion Compare Files and remediate

    #region Remove Old Home Folder

    Remove-Item "\\fileserver\Personal-Folders\$oldSAM" -Recurse -Force

    #endregion Remove Old Home Folder

#endregion Copy old Home Folder to New Home Folder

#region Rename Citrix Roaming Profile. If not using Citrix or Roaming Profiles remove me. See notes

    #Checks the Citrix profile for the new name. If not renamed yet will rename to match the new username
    If($CitrixProfile -contains "$oldSAM")
    {
        write-host "Citrix profile already changed for $GivenName $SurName" -BackgroundColor red
    }
    else{
        Try{
            Get-ChildItem -path \\fileserver\profile-redirection$\* | Where-Object Name -Like *$oldSAM* | Rename-Item -NewName {$_.name -replace "$oldSAM","$newSAM"}
            Write-Host "Renamed Profile Redirection folder for $GivenName $SurName" -ForegroundColor Green
        }
        catch{
            write-error "$_ "
        }
    }

    #endregion Rename Citrix Roaming Profile

#region Remove White Space

    $oldsam=get-aduser -filter "samaccountname -like '* *'" |select -ExpandProperty samaccountname

    Foreach($user in $oldsam){
        Set-ADUser $user -SamAccountName ($user -replace '\s+', "")
    }

#endregion Remove White Space

}

#endregion Working Script
