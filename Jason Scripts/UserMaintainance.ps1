# User Maintainance
# Sabih Saleh 10/10/2023

# Declare our Vars
$cutOffDate = Get-date.AddDays(-90)
 
# Authenicat to AZDO


# Get the list of users
$users = az devops user list --org "https://dev.azure.com/bcagroup" | ConvertFrom-Json
# $users.members

# Loop through each user
foreach ($user in $users.members){

    # Get tha name of user, access levle last access date
    $userName = $user.user.displayName
    $licenseName = $user.accessLevel.licenseDisplayName

    [string]$lastAccessedDateDay = $user.lastAccessedDate.Day
    [string]$lastAccessedDateMonth = $user.lastAccessedDate.Month
    [string]$lastAccessedDateYear = $user.lastAccessedDate.Year

    $lastAccessedDate = "$lastAccessedDateDay/$lastAccessedDateMonth/$lastAccessedDateYear"


    # If they acees more than three month
    if ($lastAccessedDate -lt $cutOffDate ) {

        switch $licenseName {

            "basic" {

                # Downgrade to stakeholder


                # Add to reporting vars

            }
            
            "basoc + Test Plans" {

                # Downgrade to stakeholder


                # Add to reporting vars


            }

            Default {

            }

        }
    }

    

}


# Output to screen the stats