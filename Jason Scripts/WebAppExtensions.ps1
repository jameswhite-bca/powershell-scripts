$accounts = (az account list) | ConvertFrom-Json

foreach ($account in $accounts) {

	$webapps = (az webapp list) | ConvertFrom-Json

	foreach ($webapp in $webapps) {

        $webapp

		#az resource show --resource-group 'YourRGName' --resource-type 'Microsoft.Web/sites/siteextensions'  --name 'mywebapp15June/siteextensions'    
        pause

	}

}
