<#
.SYNOPSIS
    Builds the KitchenOwl backend and/or web Docker images and pushes them
    to Docker Hub under the custom tag used for self-hosting.

.PARAMETER DockerHubUser
    Docker Hub namespace/username to push under. Default: d4wn89

.PARAMETER Tag
    Image tag to build and push. Default: custom

.PARAMETER SkipBackend
    Skip building/pushing the backend image.

.PARAMETER SkipWeb
    Skip building/pushing the web (frontend) image.

.EXAMPLE
    ./build-and-push.ps1
    Builds and pushes both backend and web images with the default tag.

.EXAMPLE
    ./build-and-push.ps1 -SkipWeb
    Only builds and pushes the backend image (faster - skips the Flutter web build).

.EXAMPLE
    ./build-and-push.ps1 -Tag v1.2.3
    Builds and pushes both images under a specific version tag instead of "custom".
#>
param(
    [string]$DockerHubUser = "d4wn89",
    [string]$Tag = "custom",
    [switch]$SkipBackend,
    [switch]$SkipWeb
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Checked {
    param([string]$Description, [scriptblock]$Command)
    Write-Host "==> $Description" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Description (exit code $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

if (-not $SkipBackend) {
    $backendImage = "$DockerHubUser/kitchenowl-backend`:$Tag"
    Push-Location (Join-Path $RepoRoot "backend")
    try {
        Invoke-Checked "Building backend image ($backendImage)" {
            docker build -t kitchenowl-backend:latest .
        }
        Invoke-Checked "Tagging backend image" {
            docker tag kitchenowl-backend:latest $backendImage
        }
        Invoke-Checked "Pushing backend image" {
            docker push $backendImage
        }
    } finally {
        Pop-Location
    }
    Write-Host "Backend done: $backendImage`n" -ForegroundColor Green
}

if (-not $SkipWeb) {
    $webImage = "$DockerHubUser/kitchenowl-web`:$Tag"
    Push-Location (Join-Path $RepoRoot "kitchenowl")
    try {
        Invoke-Checked "Building web image ($webImage) - this clones Flutter and can take several minutes" {
            docker build -t kitchenowl-web:latest .
        }
        Invoke-Checked "Tagging web image" {
            docker tag kitchenowl-web:latest $webImage
        }
        Invoke-Checked "Pushing web image" {
            docker push $webImage
        }
        Invoke-Checked "Removing local :latest tag" {
            docker rmi kitchenowl-web:latest
        }
    } finally {
        Pop-Location
    }
    Write-Host "Web done: $webImage`n" -ForegroundColor Green
}

Write-Host "All done. Redeploy the affected service(s) in Dokploy to pick up the new image(s)." -ForegroundColor Green
