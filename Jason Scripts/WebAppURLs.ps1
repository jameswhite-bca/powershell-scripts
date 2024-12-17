$accountCount = 0
$accounts = (az account list) | ConvertFrom-Json
$accountsCount = $accounts.Count

foreach ($account in $accounts) {
	
	$accountCount ++

	# get string vars from the objects properties
	$accountname = $account.Name
	$accountId = $account.id
    az account Set --subscription $accountId

    If ($account.state -ne "Disabled") {

        # Switch the current users context to the current subscription
		az account Set --subscription $accountid

		# Get all resources in the current subscription - tbd - we can pass a query string here to limit results.
		$resources = (az resource list | ConvertFrom-Json)
		$resourcesCount = $resources.count
		$resourcecount = 0

		# Loop through all resources
		foreach ($resource in $resources) {
			
			$resourcecount ++
			
			$resourcename = $resource.Name
			$resourceid = $resource.id

			# get string vars from the objects properties
			$resourceType = $resource.type
            $resourceName = $resource.name
            $resourceGroup = $resource.resourceGroup


            if ($resourceType -eq 'Microsoft.Web/sites') {

                try {
                    [PSCustomObject]$wapp = (az webapp config hostname list -g $resourceGroup --webapp-name $resourceName | ConvertFrom-Json)

                    foreach ($hostname in $wapp) {
                        $url = $hostname.name
                        write-output "$accountname ($accountCount of $accountsCount) - $resourceType ($resourceCount of $resourcesCount) - $resourceName -  $url"
                        "$accountname,$accountId,$resourceGroup,$resourceName,$url" >> "c:\temp\wa.csv"
                    }
                }
                catch {

                }

            } else {
                write-output "$accountname ($accountCount of $accountsCount) - $resourceType ($resourceCount of $resourcesCount)"
            }

		}
	}
}
