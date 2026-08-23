# GitHub Pages 주간 배포 동기화 스크립트
# 로컬에서 매주 한 번 실행: .\sync-deploy.ps1
# 또는: pwsh sync-deploy.ps1

Write-Host "📦 주간 단어장 배포 동기화 시작..." -ForegroundColor Green

# 현재 디렉토리 확인
if (!(Test-Path "data/vocab.json")) {
    Write-Host "❌ 오류: data/vocab.json을 찾을 수 없습니다. 저장소 루트에서 실행해주세요." -ForegroundColor Red
    exit 1
}

# 변경 사항이 있는지 확인
$status = git status -s data/vocab.json
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "⏭️  data/vocab.json에 변경 사항이 없습니다. 스킵합니다." -ForegroundColor Yellow
    exit 0
}

# 스테이징 + 커밋 + 푸시
try {
    git add data/vocab.json
    Write-Host "✅ data/vocab.json 스테이징 완료" -ForegroundColor Green

    $date = Get-Date -Format "yyyy-MM-dd"
    git commit -m "data: weekly vocab sync ($date)"
    Write-Host "✅ 커밋 완료: data/vocab.json ($date)" -ForegroundColor Green

    git push
    Write-Host "✅ 원격 저장소 푸시 완료. 배포되었습니다!" -ForegroundColor Green
    Write-Host "📱 확인: https://whatnews72.github.io/ana-starter/" -ForegroundColor Cyan
} catch {
    Write-Host "❌ 오류: $_" -ForegroundColor Red
    exit 1
}
