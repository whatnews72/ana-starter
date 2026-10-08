# Create the "ANA Server Autostart" scheduled task
# Usage: powershell -File "create-server-autostart-task.ps1"
# This task starts the dashboard server at system startup.

param(
    [string]$AnaDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

# 관리자 권한 확인: 작업 스케줄러 등록/삭제에는 관리자 권한이 필요하다 (없으면 0x80070005 액세스 거부)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required." -ForegroundColor Red
    Write-Host "Right-click PowerShell -> 'Run as administrator', then run this script again." -ForegroundColor Yellow
    exit 1
}

$taskName = "ANA Server Autostart"
$autoStartPs1 = Join-Path $AnaDir "autostart-server.ps1"
$autoStartBat = $autoStartPs1

Write-Host "Creating scheduled task: $taskName" -ForegroundColor Cyan
Write-Host "Script directory: $AnaDir"
Write-Host "Batch file: $autoStartBat"

# Verify the batch file exists
if (!(Test-Path $autoStartBat)) {
    Write-Host "ERROR: $autoStartBat not found!" -ForegroundColor Red
    exit 1
}

# Check if task already exists and delete it
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Write-Host "Existing task found. Removing..." -ForegroundColor Yellow
    try {
        # -ErrorAction Stop: 삭제 실패 시 성공 메시지가 출력되지 않도록 즉시 중단
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Failed to remove existing task: $_" -ForegroundColor Red
        exit 1
    }
    Start-Sleep -Seconds 1
}

# Create the task
try {
    # WorkingDirectory 지정 필수(미지정 시 cwd=System32)
    # 숨김 창 PowerShell이 node를 포그라운드로 실행하고 서버가 사는 동안 대기한다 (autostart-server.ps1).
    # 예전에는 Start-Process로 띄우고 즉시 반환했는데, 작업이 끝나며 스케줄러가 자식(node)을 정리해 서버가 죽었다.
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$autoStartPs1`"" `
        -WorkingDirectory $AnaDir
    # Interactive 로그온 유형은 사용자 로그온이 있어야 실행되므로 부팅(AtStartup) 트리거는 동작하지 않는다 → 로그온 트리거 사용
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -StartWhenAvailable `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Starts the ANA dashboard server at system startup" `
        -Force -ErrorAction Stop | Out-Null

    # 실제로 등록됐는지 재확인 (등록 실패를 성공으로 오인하지 않도록)
    if ($null -eq (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        throw "Task was not found after registration."
    }

    Write-Host "✓ Task '$taskName' created successfully!" -ForegroundColor Green
    Write-Host "  Trigger: At user logon" -ForegroundColor Green
    Write-Host "  Status: Ready" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    exit 1
}
