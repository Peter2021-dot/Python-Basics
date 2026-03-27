# --------------------------------------------------------------
# sync-and-push.ps1
# --------------------------------------------------------------
# 1️⃣  Paths – adjust only if your folders move
$sourceRoot = "C:\Users\butea\FlutterProjects\WETHERE\WETHERE-main"
$targetRoot = "C:\Users\butea\FlutterProjects\WETHERE-main"

# 2️⃣  Helper: compute relative path of a file inside $sourceRoot
function Get-RelativePath([string]$fullPath, [string]$base) {
    $uriFull = New-Object System.Uri($fullPath)
    $uriBase = New-Object System.Uri($base + [IO.Path]::DirectorySeparatorChar)
    return $uriBase.MakeRelativeUri($uriFull).ToString().Replace('/', [IO.Path]::DirectorySeparatorChar)
}

# 3️⃣  Gather all files in the source folder (recursively)
$sourceFiles = Get-ChildItem -Path $sourceRoot -Recurse -File

foreach ($srcFile in $sourceFiles) {
    # Compute where the file *should* be in the target folder
    $relPath = Get-RelativePath $srcFile.FullName $sourceRoot
    $destPath = Join-Path $targetRoot $relPath

    # 4️⃣  If the file does NOT exist in target OR its content differs → copy
    $copyNeeded = $false
    if (-not (Test-Path $destPath)) {
        $copyNeeded = $true
    } else {
        # Compare hashes (fast, reliable)
        $srcHash = Get-FileHash -Path $srcFile.FullName -Algorithm SHA256
        $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256
        if ($srcHash.Hash -ne $dstHash.Hash) {
            $copyNeeded = $true
        }
    }

    if ($copyNeeded) {
        # Ensure destination directory exists
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Copy the file (overwrite if it already exists)
        Copy-Item -Path $srcFile.FullName -Destination $destPath -Force

        # ------------------------------------------------------
        # 5️⃣  Stage, commit, and push this single file
        # ------------------------------------------------------
        git add "$destPath"
        $commitMsg = "Sync: copy $relPath from sibling folder"
        git commit -m "$commitMsg"

        # Push the new commit (one‑by‑one as requested)
        git push origin main

        Write-Host "`n✅  $relPath synced, committed & pushed." -ForegroundColor Green
    } else {
        Write-Host "🔎  $relPath is already up‑to‑date – skipping."
    }
}
