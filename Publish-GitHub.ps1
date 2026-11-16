#requires -Version 5.1
# Run only after extracting the ZIP and reviewing these scripts.
# Creates a NEW public repo after confirmation. Never overwrites a repository.
[CmdletBinding()]
param([string]$RepositoryName = 'my-snake-arcade')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    Get-Command $Program -ErrorAction Stop | Out-Null
    $previous = $ErrorActionPreference
    try {
        # Native tools often write successful progress to stderr on PowerShell 5.1.
        $ErrorActionPreference = 'Continue'
        & $Program @Arguments
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "$Program failed (exit $code). Read the message above." }
}
function Invoke-Probe {
    param([string]$Program, [string[]]$Arguments)
    Get-Command $Program -ErrorAction Stop | Out-Null
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Program @Arguments 2>$null)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    return [PSCustomObject]@{ ExitCode = $code; Output = $output }
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}
function Ensure-Tool {
    param([string]$Command, [string]$PackageId)
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    Write-Host "The free prerequisite '$Command' is not installed."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Install Git (git-scm.com) and GitHub CLI (cli.github.com), then run this file again.'
    }
    $answer = Read-Host "Install $PackageId using Windows Package Manager? Type YES to approve"
    if ($answer -cne 'YES') { throw 'Stopped without installing prerequisites.' }
    Invoke-Checked 'winget' @('install','--id',$PackageId,'-e','--source','winget')
    Refresh-Path
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw 'Installation finished, but PATH has not refreshed. Close this window and run Publish-GitHub.cmd again.'
    }
}
try {
    if ($RepositoryName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$') { throw 'Invalid repository name.' }
    foreach ($required in @('Web/index.html','iOS/MySnake.xcodeproj/project.pbxproj','.github/workflows/build-ios.yml','PUBLISH-MANIFEST.json')) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing $required. Extract the entire ZIP first." }
    }
    Write-Host ''
    Write-Host 'MY SNAKE - PUBLISH A NEW PUBLIC GITHUB REPOSITORY'
    Write-Host 'This will make the game source and unsigned native builds publicly downloadable.'
    Write-Host 'It does not enroll in an Apple paid plan, change Vercel billing, or publish to the App Store.'
    Write-Host 'A standard free public macOS job will run after the initial push.'
    Write-Host ''
    if ((Read-Host 'Continue with PUBLIC publishing? Type PUBLISH') -cne 'PUBLISH') { throw 'Cancelled. Nothing was published.' }
    Ensure-Tool 'git' 'Git.Git'
    Ensure-Tool 'gh' 'GitHub.cli'

    # Use GitHub browser sign-in; never ask for a token or save credentials in a file.
    $auth = Invoke-Probe 'gh' @('auth','status','--hostname','github.com')
    if ($auth.ExitCode -ne 0) {
        Invoke-Checked 'gh' @('auth','login','--hostname','github.com','--web','--git-protocol','https','--scopes','repo,workflow')
    } else {
        # Existing logins may lack permission to push workflow files.
        Invoke-Checked 'gh' @('auth','refresh','--hostname','github.com','--scopes','workflow')
    }
    Invoke-Checked 'gh' @('auth','setup-git','--hostname','github.com')
    $userResult = Invoke-Probe 'gh' @('api','user')
    if ($userResult.ExitCode -ne 0) { throw 'Unable to verify the authenticated GitHub account.' }
    $account = ($userResult.Output -join [Environment]::NewLine) | ConvertFrom-Json
    $login = [string]$account.login
    $fullName = "$login/$RepositoryName"
    Write-Host "Signed in as $login. New PUBLIC repository: $fullName"
    if ((Read-Host "Type your GitHub username ($login) to confirm the destination") -cne $login) { throw 'Destination not confirmed.' }

    $existing = Invoke-Probe 'gh' @('repo','view',$fullName,'--json','name')
    if ($existing.ExitCode -eq 0) { throw "$fullName already exists. Stopped without changing it. Use another repository name or send its link for review." }
    # Refuse to operate inside any existing Git repository, including an ancestor.
    $existingLocal = Invoke-Probe 'git' @('rev-parse','--show-toplevel')
    if ($existingLocal.ExitCode -eq 0) { throw 'This folder is already inside a Git repository. Extract a fresh copy elsewhere and retry.' }

    # Commit only the original reviewed manifest, never an unrelated or added file.
    $manifest = Get-Content -LiteralPath 'PUBLISH-MANIFEST.json' -Raw | ConvertFrom-Json
    foreach ($entry in $manifest.files) {
        $relative = [string]$entry.path
        if ($relative.StartsWith('/') -or $relative.Contains('..') -or $relative.Contains(':')) { throw 'Unsafe manifest entry.' }
        if (-not (Test-Path -LiteralPath $relative -PathType Leaf)) { throw "Missing package file: $relative" }
        $actual = (Get-FileHash -LiteralPath $relative -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne [string]$entry.sha256) { throw "Package file changed: $relative. Review the change before publishing manually." }
    }
    Invoke-Checked 'git' @('init','-b','main')
    Invoke-Checked 'git' @('config','user.name',$login)
    Invoke-Checked 'git' @('config','user.email',"$($account.id)+$login@users.noreply.github.com")
    Invoke-Checked 'git' @('config','core.autocrlf','false')
    foreach ($entry in $manifest.files) { Invoke-Checked 'git' @('add','--',[string]$entry.path) }
    Invoke-Checked 'git' @('add','--','PUBLISH-MANIFEST.json')
    Invoke-Checked 'git' @('commit','-m','Publish My Snake web source and unsigned native iOS build workflow')
    Invoke-Checked 'gh' @('repo','create',$fullName,'--public','--source','.','--remote','origin','--push','--description','Snake arcade: web game and native SwiftUI iPhone source with unsigned cloud builds')
    Write-Host ''
    Write-Host "Repository created: https://github.com/$fullName"
    Write-Host "Build progress: https://github.com/$fullName/actions"
    Write-Host "After a successful build, get the unsigned IPA: https://github.com/$fullName/releases"
    Write-Host 'Your Vercel browser game is already live; this script does not alter its deployment.'
    Write-Host 'The IPA still needs signing for your iPhone. See docs/INSTALL-WINDOWS.md.'
    Start-Process "https://github.com/$fullName/actions"
} catch {
    Write-Host ''
    Write-Host ('STOPPED: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No existing GitHub repository was overwritten. No paid plan was enabled.'
    exit 1
}
