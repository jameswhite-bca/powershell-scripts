$pat = "qkg4yj6qn5lmp2wwctkqgm7fwxrjo4e3ae5zapbfqh3hj3q5g3ra"
$organization = "bcagroup"
$project = "ESP"

$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
}

# Get list of work item IDs
$uri = "https://dev.azure.com/$organization/$project/_apis/wit/workitems?api-version=7.1-preview.3"
$uri
Pause

$workItems = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Loop through and delete work items
foreach ($workItem in $workItems.value) {
    $workItemId = $workItem.id
    $deleteUri = "https://dev.azure.com/$organization/_apis/wit/workitems/$workItemId?api-version=7.1-preview.3"
    Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete
    Write-Host "Deleted Work Item $workItemId"
}







#############################################################################################################
# 
# MigrateNovaForiRepos.PS1 - 01/08/2023
#
# Simple script to migrate latest code from NovaFori repos to CAG repos
#
#############################################################################################################

# https://tfs.novafori.com/tfs/PerfectChannel/British%20Car%20Auctions

# Setup Base Variables
$source_org = "https://tfs.novafori.com/tfs/PerfectChannel/"
$target_org = "https://dev.azure.com/bcagroup/"
$source_project = "British Car Auctions"
$target_project = "ESP"
$backup_project = "ESP_BackupProject"

$source_pat = "7xzmefx4gtvrnrog5xkdihhqcm457oremhmttlmaxddtcq6eiw6q"
$target_pat = "qkg4yj6qn5lmp2wwctkqgm7fwxrjo4e3ae5zapbfqh3hj3q5g3ra"

$perform_bca_repo_duplication = 0
$perform_target_clone = 0
$perform_source_clone = 0
$perform_update_source_from_target = 0
$perform_bca_repo_overwrite = 1

$target_path = "c:\temp\esp\target"
$source_path = "c:\temp\esp\source"
$duplicates_path = "c:\temp\esp\duplicates"
$overwrite_path = "c:\temp\esp\overwrite"

$repo_count = 0

# Step 1 - Duplicate existing BCA ESP Project Repositories
#
# Target >> Backup

if ($perform_bca_repo_duplication) {

	write-host "perform_bca_repo_duplication = $perform_bca_repo_duplication"

	$target_pat | az devops login --org $target_org

	# Backup Existing Repo's - Preserving Master Branch Only
	$repos = az repos list --org $target_org --project "$target_project" --output JSON | ConvertFrom-Json
	$repos_count = $repos.Count

	foreach ($repo in $repos) {

		$repo_count ++

		# Set our desired back up folder
		set-location $duplicates_path

		$repo_name = $repo.name
		$repo_path = $duplicates_path + "\" + $repo_name + ".git"
		
		write-host "$repo_name, $repo_path ($repo_count of $repos_count)"

		if ((test-path -LiteralPath $repo_path -PathType Container)) {
			remove-item -LiteralPath $repo_path -Recurse -Force
		}

		$duplicate_repo = az repos show --repository $repo_name --org $target_org --project "$backup_project" --output JSON | ConvertFrom-Json

		If (!($duplicate_repo)){
			$duplicate_repo = az repos create --name $repo_name --org $target_org --project "$backup_project"  --output JSON | ConvertFrom-Json
		} else {
			$delete_repo = az repos delete --name $repo_name --org $target_org --project "$backup_project"  --output JSON | ConvertFrom-Json
			$duplicate_repo = az repos create --name $repo_name --org $target_org --project "$backup_project"  --output JSON | ConvertFrom-Json
		}

		git clone --mirror $repo.webUrl
		set-location $repo_path
		git remote set-url --push origin $duplicate_repo.webUrl
		git fetch -p origin
		git push --mirror	

	}

	$repo_count = 0

}


# Target >> Local

if ($perform_target_clone) {

	write-host "perform_target_clone = $perform_target_clone"

	$target_pat | az devops login --org $target_org

	# Backup Existing Repo's - Preserving Master Branch Only
	$repos = az repos list --org $target_org --project "$target_project" --output JSON | ConvertFrom-Json
	$repos_count = $repos.Count

	foreach ($repo in $repos) {

		$repo_count ++

		# Set our desired back up folder
		set-location $target_path

		$repo_name = $repo.name
		$repo_path = $target_path + "\" + $repo_name
		
		write-host "$repo_name, $repo_path ($repo_count of $repos_count)"

		if ((test-path -LiteralPath $repo_path -PathType Container)) {
			remove-item -LiteralPath $repo_path -Recurse -Force
		}

		git clone $repo.webUrl

	}

	$repo_count = 0

}

#
# Source >> Local

if ($perform_source_clone) {

	write-host "perform_source_clone = $perform_source_clone"

	$source_pat | az devops login --org $source_org

	$repos = az repos list --org $source_org --project "$source_project" --output JSON | ConvertFrom-Json
	$repos_count = $repos.Count

	foreach ($repo in $repos) {

		$repo_count ++
		
		# Set our desired copy folder
		set-location $source_path

		$repo_name = $repo.name
		$repo_path = $source_path + "\" + $repo_name
		
		write-host "$repo_name, $repo_path ($repo_count of $repos_count)"

		if (!(test-path -LiteralPath $repo_path -PathType Container)) {
			remove-item -LiteralPath $repo_path -Recurse -Force
		}

		git clone --mirror $repo.webUrl

	}

	$repo_count = 0

}


if ($perform_bca_repo_overwrite) {

	write-host "perform_bca_repo_overwrite = $perform_bca_repo_overwrite"

	$source_pat | az devops login --org $source_org

	# Backup Existing Repo's - Preserving Master Branch Only
	$repos = az repos list --org $source_org --project "$source_project" --output JSON | ConvertFrom-Json
	$repos_count = $repos.Count

	foreach ($repo in $repos) {

		$repo_count ++

		# Set our desired back up folder
		set-location $source_path

		$repo_name = $repo.name
		$repo_path = $source_path + "\" + $repo_name + ".git"
		$push_url = $target_org + $backup_project + "/_git/" + $repo_name

		write-host "$repo_name, $repo_path ($repo_count of $repos_count)"

		$duplicate_repo = az repos show --repository $repo_name --org $target_org --project "$backup_project" --output JSON | ConvertFrom-Json

		If (!($duplicate_repo)){
			$duplicate_repo = az repos create --name $repo_name --org $target_org --project "$backup_project"  --output JSON | ConvertFrom-Json
		} else {
			az repos delete --id $duplicate_repo.id --org $target_org --project "$backup_project" --yes
			$duplicate_repo = az repos create --name $repo_name --org $target_org --project "$backup_project"  --output JSON | ConvertFrom-Json
		}

		if ((test-path -LiteralPath $repo_path -PathType Container)) {

			remove-item -LiteralPath $repo_path -Recurse -Force

		} 

		set-location $source_path
		git clone --mirror $repo.webUrl					

		set-location $repo_path
		git remote set-url --push origin $push_url
		git fetch -p origin
		git push --mirror

		if ((test-path -LiteralPath "$overwrite_path\$repo_name" -PathType Container)) {

			set-location "$overwrite_path\$repo_name"
			git pull

		} else {
			
			set-location $overwrite_path
			git clone $push_url

		}

		$update_repo_path = $target_path + "\" + $repo_name

		# Set our desired back up folder
		copy-item -LiteralPath "$update_repo_path\gitversion.yml" -Destination "$overwrite_path\$repo_name" -Force -Recurse -Verbose
		copy-item -LiteralPath "$update_repo_path\.build" -Destination "$overwrite_path\$repo_name" -Force -Recurse -Verbose
		copy-item -LiteralPath "$update_repo_path\build" -Destination "$overwrite_path\$repo_name" -Force -Recurse -Verbose

		set-location "$overwrite_path\$repo_name"
		git add --all
		git commit -m "Scripted migration from Novafori TFS to CAG Azure Devops"
		git push

	}

	$repo_count = 0



}


if ($perform_update_source_from_target) {

	write-host "perform_source_clone = $perform_source_clone"

	$target_pat | az devops login --org $target_org

	# Backup Existing Repo's - Preserving Master Branch Only
	$repos = az repos list --org $target_org --project "$target_project" --output JSON | ConvertFrom-Json
	$repos_count = $repos.Count

	foreach ($repo in $repos) {

		$repo_count ++

		$repo_name = $repo.name
		$repo_path = $target_path + "\" + $repo_name
		$source_repo_path = $source_path + "\" + $repo_name
	
		# Set our desired back up folder
		copy-item -LiteralPath "$update_repo_path\gitversion.yml" -Destination $source_repo_path
		copy-item -LiteralPath "$update_repo_path\.build" -Destination $source_repo_path
		copy-item -LiteralPath "$update_repo_path\build" -Destination $source_repo_path


	}
	
}