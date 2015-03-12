<#
.NOTES
    Author: Ted Spinks
    Created: 12/28/2014
    Updated: 3/11/2015
    Provided for demonstration / non-production use only!
.SYNOPSIS
    Assigns the specified vSphere tag/category to the specified target VM.
.DESCRIPTION 
	Loads the VMware PowerCLI core snapin and opens a VMware PowerCLI connection to the specified vCenter, using the specified credentials.
	
	Assigns the specified vSphere tag/category to the specified target VM.  Creates the tag if it doesn't already exist.  Removes existing tag if one already exists.

	Closes the vCenter connection.
	
    Requirements:
    1) Expects the tag Category to already be created in vCenter
    2) Expects the tag Category's multiple cardinality set to NO (i.e. single caridinality)
.EXAMPLE
    .\AssignOneTagOnly.ps1 myvcenter administrator@vsphere.local vmware1! "Ted Spinks" Owner labserver01
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcServer,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$vcUser,
    [Parameter(Mandatory=$True,Position=3)]
    [string]$vcPass,
    [Parameter(Mandatory=$True,Position=4)]
    [string]$tagValue,
    [Parameter(Mandatory=$True,Position=5)]
    [string]$tagCatValue,
    [Parameter(Mandatory=$True,Position=6)]
    [string]$targetVm
)

#For any unhandled errors, stop the script and return an error
$ErrorActionPreference = "Stop"

#Start logging
echo ("Beginning Tag Assignment Script for VM: " + $targetVM)

#Add the core VMware PowerCLI snapin
add-pssnapin VMware.VimAutomation.Core

#Connect to the vCenter Server
echo "Connecting to vCenter..."
Connect-VIServer -Server $vcServer -Force -User $vcUser -Password $vcPass

#Make sure the tag Category exists (an error will stop this script)
$tagCat = Get-TagCategory -Name $tagCatValue

#Make sure the tag Category's cardinality is single
if ($tagCat.Cardinality -ne "Single") {
    throw ("Tag Category, " + $tagCatValue + ", is not configured with Multiple Cardinality=No/One tag per object.")
}

#See if the specified tag already exists in vCenter
$newTag = get-tag $tagValue -ErrorAction SilentlyContinue

#If the specified tag wasn't found in vCenter, then create it
if (!$?) {
    echo ("Tag, " + $tagValue + ", wasn't found, creating it now.")
    $newTag = new-tag -Name $tagValue -category $tagCatValue
    echo ("Tag, " + $tagValue + ", successfully created.")
}

#Read tag from the target VM.  Expects 0 or 1 results (not a collection), since we've already validated  
# that the cardinality of its category is single.
$tagAssignment = Get-TagAssignment $targetVm -Category $tagCatValue -ErrorAction SilentlyContinue

#If a non-null value was returned, then there was already a tag for this category assigned 
# to the target VM, so see if it's the one we want.
if ($tagAssignment -ne $null) { 

    #See if it's the right tag 
    if ($tagAssignment.Tag -eq $newTag) {
        Write-Warning ("Tag, " + $tagValue + ", was already assigned to the target VM. No action taken.")
    } else {
    #If it wasn't the right tag, then remove the old tag and assign the new one
        echo ("Removing existing tag, " + $tagAssignment.Tag.Name + ".")
        Remove-TagAssignment -tag $tagAssignment -Confirm:$false
        echo ("Adding new tag, " + $tagValue + ", to the target VM")
        New-TagAssignment -tag $newTag -entity $targetVm
    }
}
#Otherwise, a tag wasn't already assigned, so go ahead and assign our new tag
else {
    echo ("Adding new tag, " + $tagValue + ", to the target VM")
    New-TagAssignment -tag $newTag -entity $targetVm
    echo "Success!"
}

#Disconnect from the vCenter Server already!
echo "Disconnecting from vCenter..."
Disconnect-VIServer -server $vcServer -Force -Confirm:$False
echo "Disconnected."