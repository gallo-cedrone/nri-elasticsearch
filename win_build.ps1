<#
    .SYNOPSIS
        This script verifies, tests, builds and packages a New Relic Infrastructure Integration
#>
param (
    # IntegrationName
    [string]$integration=$(throw "-integration is required"),
    # Target architecture: amd64 (default) or 386
    [ValidateSet("amd64", "386")]
    [string]$arch="amd64",
    [string]$version="0.0.0",
    # Creates a signed installer
    [switch]$installer=$false,
    # Skip tests
    [switch]$skipTests=$false
)

echo "debug testutils"
go build -v ./testutils#debug

$integrationName = $integration.Replace("nri-", "")
$executable = "nri-$integrationName.exe"

.\windows_set_version.ps1 -integration $integration -version $version

echo "--- Checking dependencies"

echo "Checking Go..."
go version
if (-not $?)
{
    echo "Can't find Go"
    exit -1
}

$env:GOOS="windows"
$env:GOARCH=$arch

echo "--- Collecting files"

$goFiles = go list ./...

echo "--- Format check"

$wrongFormat = go fmt $goFiles

if ($wrongFormat -and ($wrongFormat.Length -gt 0))
{
    echo "ERROR: Wrong format for files:"
    echo $wrongFormat
    exit -1
}

if (-Not $skipTests) {
    echo "--- Running tests"

    go test $goFiles
    if (-not $?)
    {
        echo "Failed running tests"
        exit -1
    }    
}

echo "--- Running Build"
go build -v $goFiles
echo "--- Build completed, checking status"
if (-not $?)
{
    echo "Failed building files"
    exit -1
}

echo "--- Collecting Go main files"
$packages = go list -f "{{.ImportPath}} {{.Name}}" ./...  | ConvertFrom-String -PropertyNames Path, Name
$mainPackage = $packages | ? { $_.Name -eq "main" } | % { $_.Path }
#$mainPackage = "github.com/gallo-cedrone/nri-elasticsearch/src" 
echo "main package found: $mainPackage"

echo "generating $integrationName"
go generate $mainPackage
$fileName = ([io.fileinfo]$mainPackage).BaseName

echo "creating $executable"
go build -ldflags "-X main.buildVersion=$version" -o ".\target\bin\windows_$arch\$executable" $mainPackage

If (-Not $installer) {
    exit 0
}

echo "--- Building Installer"

Push-Location -Path "pkg\windows\nri-$arch-installer"
$env:integration = $integration
msbuild nri-installer.wixproj

if (-not $?)
{
    echo "Failed building installer"
    Pop-Location
    exit -1
}

echo "Making versioned installed copy"

cd bin\Release

cp "$integration-$arch.msi" "$integration-$arch.$version.msi"
cp "$integration-$arch.msi" "$integration.msi"

Pop-Location
