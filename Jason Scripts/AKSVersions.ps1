######################################################
# 
# Daniel Berns (CAG) - 09/09/2023
#
# Powershell script using AZ Cli commands to cycle
# through all subscriptions in a tenant and
# report on the configuration of Function Apps found
# in each subscription
#
######################################################

# Set our output path
$output_path = "c:\temp\aks.csv"

# Delete any existing file
if (Test-Path $output_path) {
	Remove-Item $output_path
}

# Get a list of subscriptions and set counter values
$accounts = (az account list) | ConvertFrom-Json
$accountCount = 0
$accountsCount = $accounts.Count

# Cycle through each subscription in list
foreach ($account in $accounts) {
	
	# Increment counter
	$accountCount ++

	# get string vars from the objects properties
	$accountname = $account.Name
	$accountId = $account.id

	# Ensure the subscription is not disabled
    If ($account.state -ne "Disabled") {

		# Switch the current users context to the current subscription
		az account Set --subscription $accountid

		# Get all resources in the current subscription and set counters
		$resources = (az resource list | ConvertFrom-Json)
		$resourcecount = 0
		$resourcesCount = $resources.count

		# Loop through all resources
		foreach ($resource in $resources) {
			
			# Increment counter
			$resourcecount ++
			
			# get string vars from the objects properties
			$resourcename = $resource.Name
			$resourceType = $resource.type
			$resourceGroup = $resource.resourceGroup

			# Carry out action based on resource type
			switch ($resourceType) {

				"Microsoft.ContainerService/managedClusters" {

					# Were are interested in these resource types, output their values to show progress
					write-output "$accountname ($accountCount of $accountsCount) - $resourceType ($resourceCount of $resourcesCount)"

					# Get the "microsoft.web/sites" resource's configuration
					[PSCustomObject]$aks = (az aks show -g $resourceGroup -n $resourceName | ConvertFrom-Json)
	
                    # get string vars from the objects properties
                    $itemValue = $aks.kubernetesVersion

                    [PSCustomObject]@{
                        subscription_name = $accountname
                        subscription_id = $accountId
                        resource_group = $resourceGroup
                        resource_type = $resourceType
                        resource_name = $resourceName
                        runtime_ver = $itemValue
                    } | Export-Csv -Path $output_path -Append

				}

				default {

					# Were are not interested in these resource types, simply output their values to show progress
					write-output "$accountname ($accountCount of $accountsCount) - $resourceType ($resourceCount of $resourcesCount)"

				}

			}

		}

	}

}

