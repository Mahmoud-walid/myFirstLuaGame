# /scripts/run.ps1
# Get the absolute path to the project root
$projectRoot = Resolve-Path "$PSScriptRoot/.."

# Build full path to `src` directory
$srcPath = Join-Path $projectRoot "src"

# Define log paths
$logOutPath = Join-Path $projectRoot "/scripts/logs/main-logs-out.txt"
$logErrPath = Join-Path $projectRoot "/scripts/logs/main-logs-err.txt"
$logMergedPath = Join-Path $projectRoot "/scripts/logs/main-logs.txt"

Write-Host "Project path: $projectRoot"
Write-Host "src path: $srcPath"

function ColorizeLine {
    param ([string]$line)

    # regex pattern that captures all parts of the coloring {{red}} ... {{end}}
    $pattern = "{{red}}(.*?){{end}}"

    # Start from the begin line
    $pos = 0

    while ($true) {
        $match = [regex]::Match($line.Substring($pos), $pattern)
        if (-not $match.Success) {
            # Print the rest of the line without coloring.
            Write-Host -NoNewline $line.Substring($pos)
            break
        }

        # Print text before the colored part
        Write-Host -NoNewline $line.Substring($pos, $match.Index)

        # Print the red colored part
        Write-Host -NoNewline $match.Groups[1].Value -ForegroundColor Red

        # Move past the colored part
        $pos += $match.Index + $match.Length
    }
}

# Make sure the log files exist, and if they don't exist, create empty ones.
if (-not (Test-Path $logOutPath)) {
    New-Item -Path $logOutPath -ItemType File -Force | Out-Null
}
if (-not (Test-Path $logErrPath)) {
    New-Item -Path $logErrPath -ItemType File -Force | Out-Null
}
if (-not (Test-Path $logMergedPath)) {
    New-Item -Path $logMergedPath -ItemType File -Force | Out-Null
}

# Check if love.exe exists
$loveExePath = Join-Path $projectRoot "engine\love.exe"
if (-not (Test-Path $loveExePath)) {
    Write-Error "❌ love.exe not found in: $loveExePath"
    Read-Host "➡️ Press Enter to continue..."
    exit 1
}

# Check if src directory exists
if (-not (Test-Path $srcPath)) {
    Write-Error "❌ src not found in: $srcPath"
    Read-Host "➡️ Press Enter to continue..."
    exit 1
}

# Check if main.lua exists
$mainLuaPath = Join-Path $srcPath "main.lua"
if (-not (Test-Path $mainLuaPath)) {
    Write-Error "❌ main.lua not found in: $mainLuaPath"
    Read-Host "➡️ Press Enter to continue..."
    exit 1
}

# Clear previous logs
Remove-Item -ErrorAction Ignore $logOutPath, $logErrPath, $logMergedPath

Write-Host "🔃 Running Love2D..."
Write-Host "Path Love2D: $loveExePath"
Write-Host "Path main.lua: $mainLuaPath"

# Run Love2D with output redirection to separate files
try {
    Start-Process -FilePath $loveExePath `
        -ArgumentList "`"$srcPath`"" `
        -RedirectStandardOutput $logOutPath `
        -RedirectStandardError $logErrPath `
        -Wait

    Write-Host "🏁 Love2D has finished running."
} catch {
    Write-Error "😡 Love2D startup error: $_"
    Read-Host "➡️ Press Enter to close..."
    exit 1
}

# Merge logs into one file
if (Test-Path $logOutPath) {
    Get-Content $logOutPath | Out-File -FilePath $logMergedPath -Encoding utf8
}
if (Test-Path $logErrPath) {
    Add-Content -Path $logMergedPath -Value "`n--- STDERR ---`n"
    Get-Content $logErrPath | Add-Content -Path $logMergedPath
}

# Show logs in terminal (if any)
if (Test-Path $logMergedPath) {
    $logs = Get-Content $logMergedPath

    if ($logs.Count -gt 0) {
        # Define how many spaces a tab character should represent
        $tabSpaces = 4 

        # Process logs: replace tabs with spaces and find max length
        $processedLogs = @()
        $maxLength = 0

        foreach ($line in $logs) {
            # Replace tabs with defined number of spaces
            $processedLine = $line.Replace("`t", " " * $tabSpaces)
            $processedLogs += $processedLine

            # Update max length
            if ($processedLine.Length -gt $maxLength) {
                $maxLength = $processedLine.Length
            }
        }

        function Get-VisibleLength {
            param([string]$text)

            # Remove special tags like {{red}} and {{end}}
            $cleanText = $text -replace "{{.*?}}", ""

            return $cleanText.Length
        }

        $horizontalLine = "-" * ($maxLength + 4)
        Write-Host ""
        Write-Host $horizontalLine
        foreach ($line in $processedLogs) {
            $visibleLength = Get-VisibleLength $line
            $padding = ' ' * ($maxLength - $visibleLength)

            Write-Host -NoNewline "| "
            ColorizeLine ($line + $padding)
            Write-Host " |"
        }
        Write-Host $horizontalLine

    } else {
        Write-Host "ℹ️ No logs were written to $logMergedPath"
    }
} else {
    Write-Host "❌ Log file not found: $logMergedPath"
}

Read-Host "➡️ Press Enter to close..."