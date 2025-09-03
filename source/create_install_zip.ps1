#create_install_zip.ps1
# Script to create an installation ZIP file for BakkesMod plugin

# Get the directory where the script is located
$scriptDir = $PSScriptRoot

# Define different project structures
$projectStructure = $null
$solutionDir = $null
$projectDir = $null
$projectName = $null

# Check if we're in a project folder, solution folder, or combined folder
$hasSolutionFile = (Get-ChildItem -Path $scriptDir -Filter "*.sln" | Measure-Object).Count -gt 0
$hasProjectFile = (Get-ChildItem -Path $scriptDir -Filter "*.vcxproj" | Measure-Object).Count -gt 0

if ($hasSolutionFile -and $hasProjectFile) {
    # Case 1: Combined solution and project folder (VS "Place solution and project in the same folder")
    $projectStructure = "Combined"
    $solutionDir = $scriptDir
    $projectDir = $scriptDir
    
    # Get project name from vcxproj file
    $projectFile = Get-ChildItem -Path $scriptDir -Filter "*.vcxproj" | Select-Object -First 1
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($projectFile.Name)
    
    Write-Host "Detected combined solution/project folder structure." -ForegroundColor Cyan
    Write-Host "Project name: $projectName" -ForegroundColor Cyan
}
elseif ($hasSolutionFile) {
    # Case 2: Solution folder with separate project folders
    $projectStructure = "SolutionOnly"
    $solutionDir = $scriptDir
    
    # Get solution name as default project name
    $solutionFile = Get-ChildItem -Path $solutionDir -Filter "*.sln" | Select-Object -First 1
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($solutionFile.Name)
    
    # Find project folders
    $projectFolders = Get-ChildItem -Path $solutionDir -Directory | Where-Object {
        (Get-ChildItem -Path $_.FullName -Filter "*.vcxproj" -Recurse | Measure-Object).Count -gt 0
    }
    
    Write-Host "Detected solution folder with separate project folders." -ForegroundColor Cyan
    Write-Host "Solution name: $([System.IO.Path]::GetFileNameWithoutExtension($solutionFile.Name))" -ForegroundColor Cyan
    Write-Host "Found $(($projectFolders | Measure-Object).Count) project(s)" -ForegroundColor Cyan
    
    # List found projects
    $projectFolders | ForEach-Object {
        $projectFilePath = Get-ChildItem -Path $_.FullName -Filter "*.vcxproj" -Recurse | Select-Object -First 1
        if ($projectFilePath) {
            $projName = [System.IO.Path]::GetFileNameWithoutExtension($projectFilePath.Name)
            Write-Host " - $projName" -ForegroundColor White
        }
    }
    
    # Use first project as default if no specific selection
    if ($projectFolders.Count -gt 0) {
        $firstProjectFolder = $projectFolders | Select-Object -First 1
        $firstProjectFile = Get-ChildItem -Path $firstProjectFolder.FullName -Filter "*.vcxproj" -Recurse | Select-Object -First 1
        if ($firstProjectFile) {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($firstProjectFile.Name)
            $projectDir = $firstProjectFolder.FullName
            Write-Host "Using '$projectName' as the target project" -ForegroundColor Cyan
        }
    }
}
else {
    # Case 3: Project folder (inside a solution folder)
    $projectStructure = "ProjectOnly"
    $projectDir = $scriptDir
    $projectName = Split-Path -Path $projectDir -Leaf
    $solutionDir = Split-Path -Path $projectDir -Parent
    
    # Verify this is actually a project folder
    if (-not (Get-ChildItem -Path $projectDir -Filter "*.vcxproj" -Recurse | Measure-Object).Count -gt 0) {
        Write-Host "Warning: No .vcxproj file found in current directory. This may not be a valid project folder." -ForegroundColor Yellow
    }
    
    Write-Host "Detected project folder within a solution." -ForegroundColor Cyan
    Write-Host "Project name: $projectName" -ForegroundColor Cyan
}

# Extract version from version.h file
$versionFile = "$projectDir\version.h"
$versionMajor = "1"
$versionMinor = "0"
$versionBuild = "0"
if (Test-Path $versionFile) {
    $versionContent = Get-Content $versionFile -Raw
    
    # Extract version numbers using regex
    if ($versionContent -match 'VERSION_MAJOR\s+(\d+)') { $versionMajor = $matches[1] }
    if ($versionContent -match 'VERSION_MINOR\s+(\d+)') { $versionMinor = $matches[1] }
    if ($versionContent -match 'VERSION_BUILD\s+(\d+)') { $versionBuild = $matches[1] }
    
    Write-Host "Detected version: $versionMajor.$versionMinor.$versionBuild" -ForegroundColor Cyan
} else {
    Write-Host "Warning: version.h file not found, using default version" -ForegroundColor Yellow
}

# Format version string for the filename
$versionString = "$versionMajor-$versionMinor-$versionBuild"
$outputPath = "$solutionDir\${projectName}_install_$versionString.zip"

Write-Host "Output will be saved to: $outputPath" -ForegroundColor Cyan

# Create a temporary folder for installation files
$tempDir = "$solutionDir\temp_install_package"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Define required folders structure as an array for easier management
# Note: we don't include "source" since this is an installation ZIP
$requiredFolders = @(
    "plugins"
)

# Create the required folder structure
foreach ($folder in $requiredFolders) {
    New-Item -ItemType Directory -Path "$tempDir\$folder" -Force | Out-Null
}

# Copy only the DLL to the plugins folder
Write-Host "Copying plugin files..." -ForegroundColor Yellow

$dllPath = "$solutionDir\plugins\$projectName.dll"
if (Test-Path $dllPath) {
    Copy-Item -Path $dllPath -Destination "$tempDir\plugins\$projectName.dll" -Force
    Write-Host " - plugins/$projectName.dll" -ForegroundColor Green
} else {
    Write-Host " - Error: plugins/$projectName.dll (not found in plugins folder)" -ForegroundColor Red
    Write-Host " - Installation package cannot be created without the plugin DLL" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force
    exit 1
}

# Function to copy folders if they exist
function Copy-FolderIfExists {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$FolderName
    )
    
    if (Test-Path $SourcePath) {
        # Check if the source folder has any content
        $hasContent = (Get-ChildItem -Path $SourcePath -Force).Count -gt 0
        
        if ($hasContent) {
            # First create the destination directory explicitly to ensure it exists
            if (-not (Test-Path $DestinationPath)) {
                New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            }
            
            # Then copy all items, both files and folders
            Get-ChildItem -Path $SourcePath -Force | ForEach-Object {
                $destItem = Join-Path -Path $DestinationPath -ChildPath $_.Name
                Copy-Item -Path $_.FullName -Destination $destItem -Recurse -Force
                Write-Host " - $FolderName/$($_.Name) (copied)" -ForegroundColor Green
            }
            return $true
        } else {
            Write-Host " - $FolderName (folder exists but is empty, skipping)" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host " - $FolderName (folder not found, skipping)" -ForegroundColor Yellow
        return $false
    }
}

# Copy additional folders if they exist (data, cfg, plugins/settings)
$additionalFolders = @(
    @{Source = "$solutionDir\data"; Destination = "$tempDir\data"; Name = "data"},
    @{Source = "$solutionDir\cfg"; Destination = "$tempDir\cfg"; Name = "cfg"},
    @{Source = "$solutionDir\plugins\settings"; Destination = "$tempDir\plugins\settings"; Name = "plugins/settings"}
)

Write-Host "Copying additional folders..." -ForegroundColor Yellow
foreach ($folder in $additionalFolders) {
    Copy-FolderIfExists -SourcePath $folder.Source -DestinationPath $folder.Destination -FolderName $folder.Name
}

# Create ZIP archive
if (Test-Path $outputPath) {
    Remove-Item -Path $outputPath -Force
}
Write-Host "Creating installation ZIP..." -ForegroundColor Yellow
Compress-Archive -Path "$tempDir\*" -DestinationPath $outputPath -Force

# Remove temporary folder
Remove-Item -Path $tempDir -Recurse -Force

# Verify that the ZIP was created successfully
if (Test-Path $outputPath) {
    $zipSize = (Get-Item $outputPath).Length
    Write-Host "Installation ZIP created successfully: $($outputPath) ($([math]::Round($zipSize/1KB, 2)) KB)" -ForegroundColor Green
    Write-Host "ZIP structure:" -ForegroundColor Cyan
    Write-Host " - ./plugins/$projectName.dll" -ForegroundColor White
    
    # List additional folders that were included
    $additionalFolders | ForEach-Object {
        $folderName = $_.Name
        $sourcePath = $_.Source
        if (Test-Path $sourcePath) {
            if ((Get-ChildItem -Path $sourcePath -Force).Count -gt 0) {
                Write-Host " - ./$folderName/" -ForegroundColor White
            }
        }
    }
} else {
    Write-Host "ERROR: Failed to create installation ZIP" -ForegroundColor Red
}