#create_source_zip.ps1
# Script to create a ZIP compliant with BakkesMod review requirements

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

$outputPath = "$solutionDir\$projectName" + "_source.zip"
Write-Host "Output will be saved to: $outputPath" -ForegroundColor Cyan

# Create a temporary folder for source files
$tempDir = "$solutionDir\temp_package"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Define required folders structure as an array for easier management
$requiredFolders = @(
    "source",
    "plugins"
)

# Create the required folder structure
foreach ($folder in $requiredFolders) {
    New-Item -ItemType Directory -Path "$tempDir\$folder" -Force | Out-Null
}

# Copy source files to the source folder
Write-Host "Copying source code files..." -ForegroundColor Yellow

# Solution-level file patterns to copy
$solutionLevelPatterns = @(
    "*.sln",
    "vcpkg.json"
)

foreach ($pattern in $solutionLevelPatterns) {
    $files = Get-ChildItem -Path $solutionDir -Filter $pattern -File
    foreach ($file in $files) {
        Copy-Item -Path $file.FullName -Destination "$tempDir\source\" -Force
        Write-Host " - $($file.Name)" -ForegroundColor Green
    }
}

# Project-level file patterns to copy
$projectLevelPatterns = @(
    "*.cpp",
    "*.h",
    "*.rc",
    "*.vcxproj",
    "*.vcxproj.filters",
    "*.vcxproj.user",
    "BakkesMod.props",
    "*.ps1"
)

# Handle copying based on the project structure
if ($projectStructure -eq "Combined") {
    # For combined structure, copy directly to source/ without project subfolder
    foreach ($pattern in $projectLevelPatterns) {
        $files = Get-ChildItem -Path $projectDir -Filter $pattern -File -Recurse
        foreach ($file in $files) {
            # Preserve relative path structure within project folder
            $relativePath = $file.FullName.Substring($projectDir.Length + 1)
            $destinationPath = Join-Path -Path "$tempDir\source" -ChildPath $relativePath
            
            # Ensure destination directory exists
            $destinationDir = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
            Write-Host " - source\$relativePath" -ForegroundColor Green
        }
    }
} elseif ($projectStructure -eq "ProjectOnly") {
    # For project-only structure, copy to source/ProjectName/
    foreach ($pattern in $projectLevelPatterns) {
        $files = Get-ChildItem -Path $projectDir -Filter $pattern -File -Recurse
        foreach ($file in $files) {
            # Preserve relative path structure within project folder
            $relativePath = $file.FullName.Substring($projectDir.Length + 1)
            $destinationPath = Join-Path -Path "$tempDir\source\$projectName" -ChildPath $relativePath
            
            # Ensure destination directory exists
            $destinationDir = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
            Write-Host " - $projectName\$relativePath" -ForegroundColor Green
        }
    }
}
elseif ($projectStructure -eq "SolutionOnly") {
    # For solution-only structure, handle all project folders
    $projectFolders = Get-ChildItem -Path $solutionDir -Directory | Where-Object {
        (Get-ChildItem -Path $_.FullName -Filter "*.vcxproj" -Recurse | Measure-Object).Count -gt 0
    }
    
    foreach ($projectFolder in $projectFolders) {
        foreach ($pattern in $projectLevelPatterns) {
            $files = Get-ChildItem -Path $projectFolder.FullName -Filter $pattern -File -Recurse
            foreach ($file in $files) {
                # Preserve relative path structure within project folder
                $relativePath = $file.FullName.Substring($projectFolder.FullName.Length + 1)
                $destinationPath = Join-Path -Path "$tempDir\source\$($projectFolder.Name)" -ChildPath $relativePath
                
                # Ensure destination directory exists
                $destinationDir = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path $destinationDir)) {
                    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
                }
                
                Copy-Item -Path $file.FullName -Destination $destinationPath -Force
                Write-Host " - $($projectFolder.Name)\$relativePath" -ForegroundColor Green
            }
        }
    }
}

# Folders to copy to the source directory (can be easily extended)
# This allows selective copying of specific folders while avoiding unwanted ones like .git
$sourceFolders = @("IMGUI")
foreach ($folder in $sourceFolders) {
    # Check in project directory first (or all project directories if in solution folder)
    $folderFound = $false
    
    if ($projectStructure -eq "SolutionOnly") {
        # If we're in the solution directory with separate project folders, check in each project folder
        $projectFolders = Get-ChildItem -Path $solutionDir -Directory | Where-Object {
            (Get-ChildItem -Path $_.FullName -Filter "*.vcxproj" -Recurse | Measure-Object).Count -gt 0
        }
        
        foreach ($projectFolder in $projectFolders) {
            if (Test-Path "$($projectFolder.FullName)\$folder") {
                $destinationFolder = "$tempDir\source\$($projectFolder.Name)\$folder"
                
                # Remove the destination folder if it already exists (to avoid nested folders)
                if (Test-Path $destinationFolder) {
                    Remove-Item -Path $destinationFolder -Recurse -Force
                }
                
                # Create the directory and copy its contents
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                Copy-Item -Path "$($projectFolder.FullName)\$folder\*" -Destination $destinationFolder -Recurse -Force
                Write-Host " - $($projectFolder.Name)\$folder (replaced and copied)" -ForegroundColor Green
                $folderFound = $true
            }
        }
    } elseif ($projectStructure -eq "Combined") {
        # For combined structure (solution and project in same folder)
        if (Test-Path "$projectDir\$folder") {
            # For combined structure, place folders directly in source/
            $destinationFolder = "$tempDir\source\$folder"
            
            # Remove the destination folder if it already exists (to avoid nested folders)
            if (Test-Path $destinationFolder) {
                Remove-Item -Path $destinationFolder -Recurse -Force
            }
            
            # Create the directory and copy its contents
            New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            Copy-Item -Path "$projectDir\$folder\*" -Destination $destinationFolder -Recurse -Force
            Write-Host " - source\$folder (replaced and copied)" -ForegroundColor Green
            $folderFound = $true
        }
    } else {
        # For project-only structure
        if (Test-Path "$projectDir\$folder") {
            $destinationFolder = "$tempDir\source\$projectName\$folder"
            
            # Remove the destination folder if it already exists (to avoid nested folders)
            if (Test-Path $destinationFolder) {
                Remove-Item -Path $destinationFolder -Recurse -Force
            }
            
            # Create the directory and copy its contents
            New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            Copy-Item -Path "$projectDir\$folder\*" -Destination $destinationFolder -Recurse -Force
            Write-Host " - $projectName\$folder (replaced and copied)" -ForegroundColor Green
            $folderFound = $true
        }
    }
    
    # If not found in project directory, check in solution directory
    if (-not $folderFound -and (Test-Path "$solutionDir\$folder")) {
        $destinationFolder = "$tempDir\source\$folder"
        
        # Remove the destination folder if it already exists (to avoid nested folders)
        if (Test-Path $destinationFolder) {
            Remove-Item -Path $destinationFolder -Recurse -Force
        }
        
        # Create the directory and copy its contents
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        Copy-Item -Path "$solutionDir\$folder\*" -Destination $destinationFolder -Recurse -Force
        Write-Host " - $folder (replaced and copied)" -ForegroundColor Green
        $folderFound = $true
    }
    
    if (-not $folderFound) {
        Write-Host " - $folder (not found)" -ForegroundColor Red
    }
}

# Copy only the DLL to the root plugins folder
Write-Host "Managing plugin files..." -ForegroundColor Yellow

$dllPath = "$solutionDir\plugins\$projectName.dll"
if (Test-Path $dllPath) {
    Copy-Item -Path $dllPath -Destination "$tempDir\plugins\$projectName.dll" -Force
    Write-Host " - plugins/$projectName.dll" -ForegroundColor Green
} else {
    Write-Host " - plugins/$projectName.dll (not found in source plugins folder)" -ForegroundColor Red
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
Write-Host "Creating ZIP..." -ForegroundColor Yellow
Compress-Archive -Path "$tempDir\*" -DestinationPath $outputPath -Force

# Remove temporary folder
Remove-Item -Path $tempDir -Recurse -Force

# Verify that the ZIP was created successfully
if (Test-Path $outputPath) {
    $zipSize = (Get-Item $outputPath).Length
    Write-Host "Source ZIP created successfully: $($outputPath) ($([math]::Round($zipSize/1KB, 2)) KB)" -ForegroundColor Green
    Write-Host "ZIP structure:" -ForegroundColor Cyan
    Write-Host " - ./source/ [project source files]" -ForegroundColor White
    Write-Host " - ./plugins/$projectName.dll" -ForegroundColor White
    Write-Host " - ./data/ [data files, if exists]" -ForegroundColor White
    Write-Host " - ./cfg/ [configuration files, if exists]" -ForegroundColor White
    Write-Host " - ./plugins/settings/ [plugin settings, if exists]" -ForegroundColor White
} else {
    Write-Host "ERROR: Failed to create source ZIP" -ForegroundColor Red
}