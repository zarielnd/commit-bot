# Path to your Git repository
$repoPath = "I:\commit-bot"

# Path to a log file where you can check what happened
$logFile = "I:\commit-bot\commit_log.txt"

# Specify the full path to the Git executable (adjust if needed)
$gitPath = "C:\Program Files\Git\cmd\git.exe"

# Verify that the repository path exists; if not, log an error and exit.
if (-not (Test-Path $repoPath)) {
    Add-Content $logFile "[$(Get-Date)] ERROR: Repository path '$repoPath' does not exist!`n"
    exit
}

Set-Location $repoPath

# Randomly choose the number of commits for the day (between 5 and 10)
$NumCommits = Get-Random -Minimum 5 -Maximum 11  # Maximum is exclusive
Add-Content $logFile "[$(Get-Date)] Scheduling ${NumCommits} commits for today.`n"

# Loop to schedule each commit as a background job
for ($i = 1; $i -le $NumCommits; $i++) {
    # Generate a random offset in minutes (0 to 1440 minutes = 24 hours)
    $offsetMinutes = Get-Random -Minimum 0 -Maximum 1440
    $delaySeconds = $offsetMinutes * 60
    Add-Content $logFile "[$(Get-Date)] Scheduling commit #${i} in ${offsetMinutes} minute(s).`n"
    
    # Schedule the commit job as a background job
    Start-Job -ScriptBlock {
        param($repoPath, $i, $NumCommits, $delaySeconds, $logFile, $gitPath)
        
        Start-Sleep -Seconds $delaySeconds
        
        # Mapped drives may not be available in this job; try remapping if needed.
        if (-not (Test-Path $repoPath)) {
            # Extract drive letter (assumes repoPath starts with a drive letter)
            $driveLetter = $repoPath.Substring(0,2)
            Add-Content $logFile "[$(Get-Date)] Repository path '$repoPath' not found. Attempting to remap drive $driveLetter.`n"
            net use $driveLetter /persistent:no | Out-Null
        }
        
        # Change to the repository folder
        Set-Location $repoPath
        Add-Content $logFile "[$(Get-Date)] Current directory in job: $(Get-Location).`n"
        
        # Build the full path for the update file
        $updateFile = Join-Path $repoPath "update.txt"
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $fileContent = "Last updated: $timestamp"
        
        # Overwrite the file with the new timestamp
        $fileContent | Out-File -FilePath $updateFile -Force
        
        Add-Content $logFile "[$(Get-Date)] Commit #${i}: Updated file ${updateFile} with content: ${fileContent}`n"
        
        $commitMessage = "Auto commit ${i} of ${NumCommits} on $timestamp"
        
        # Use the full Git path for commands
        & "$gitPath" add . | Out-File -FilePath $logFile -Append
        $status = & "$gitPath" status --porcelain
        if (-not [string]::IsNullOrWhiteSpace($status)) {
            & "$gitPath" commit -m $commitMessage | Out-File -FilePath $logFile -Append
            $commitType = "commit"
        } else {
            & "$gitPath" commit --allow-empty -m $commitMessage | Out-File -FilePath $logFile -Append
            $commitType = "empty commit"
        }
        
        $pushOutput = & "$gitPath" push origin main 2>&1 | Out-File -FilePath $logFile -Append
        $logEntry = "[$(Get-Date)] Executed ${commitType}: '${commitMessage}'.`n"
        Add-Content $logFile $logEntry
    } -ArgumentList $repoPath, $i, $NumCommits, $delaySeconds, $logFile, $gitPath
}  # <-- This closes the for loop

Add-Content $logFile "[$(Get-Date)] All commit jobs scheduled for today.`n"
