<#
    .SYNOPSIS
        This script performs the needed replacement of the placeholders in  Product.wxs and versioninfo.json
#>
param (
	# IntegrationName
    [string]$integration = $(throw "-integration is required"),
	[string]$version="0.0.0",
	[int]$build = 0
)
echo "--- This script performs the needed replacement of the placeholders in  Product.wxs and versioninfo.json"

# verifying version number format
$v = $version.Split(".")

if ($v.Length -ne 3) {
    echo "-version must follow a numeric major.minor.patch semantic versioning schema (received: $version)"
    exit -1
}

$wrong = $v | ? { (-Not [System.Int32]::TryParse($_, [ref]0)) -or ( $_.Length -eq 0) -or ([int]$_ -lt 0)} | % { 1 }
if ($wrong.Length  -ne 0) {
    echo "-version major, minor and patch must be valid positive integers (received: $version)"
    exit -1
}
$major = $v[0]
$minor = $v[1]
$patch = $v[2]
$integrationName = $integration.Replace("nri-", "")
$executable = "nri-$integrationName.exe"

if (-not (Test-Path env:GOPATH)) {
	Write-Error "GOPATH not defined."
}
$projectRootPath = Join-Path -Path $env:GOPATH -ChildPath "src\github.com\gallo-cedrone\$integration"
echo "--- projectRootPath=$projectRootPath"

$versionInfoTempl = Get-Childitem -Path $projectRootPath -Include "versioninfo.json.template" -Recurse -ErrorAction SilentlyContinue
echo "--- versionInfoTempl=$versionInfoTempl"
if ("$versionInfoTempl" -eq "") {
	Write-Error "$versionInfoTempl not found."
	exit 0
}
$versionInfoPath = $versionInfoTempl.DirectoryName + "\versioninfo.json"
Copy-Item -Path $versionInfoTempl -Destination $versionInfoPath -Force

$versionInfo = Get-Content -Path $versionInfoPath -Encoding UTF8
$versionInfo = $versionInfo -replace "{MajorVersion}", $major
$versionInfo = $versionInfo -replace "{MinorVersion}", $minor
$versionInfo = $versionInfo -replace "{PatchVersion}", $patch
$versionInfo = $versionInfo -replace "{BuildVersion}", $build
$versionInfo = $versionInfo -replace "{Integration}", $integration
$versionInfo = $versionInfo -replace "{IntegrationExe}", $executable
$versionInfo = $versionInfo -replace "{Year}", (Get-Date).year
Set-Content -Path $versionInfoPath -Value $versionInfo

$wix386Path = Join-Path -Path $projectRootPath -ChildPath "pkg\windows\nri-386-installer\Product.wxs"
$wixAmd64Path = Join-Path -Path $projectRootPath -ChildPath "pkg\windows\nri-amd64-installer\Product.wxs"

Function ProcessProductFile($productPath) {
	if ((Test-Path "$productPath.template" -PathType Leaf) -eq $False) {
		Write-Error "$productPath.template not found."
	}
	Copy-Item -Path "$productPath.template" -Destination $productPath -Force

	$product = Get-Content -Path $productPath -Encoding UTF8
	$product = $product -replace "{IntegrationVersion}", "$major.$minor.$patch"
	$product = $product -replace "{Year}", (Get-Date).year
	$product = $product -replace "{IntegrationExe}", $executable
	$product = $product -replace "{IntegrationName}", $integrationName
	Set-Content -Value $product -Path $productPath
}

ProcessProductFile($wix386Path)
ProcessProductFile($wixAmd64Path)
