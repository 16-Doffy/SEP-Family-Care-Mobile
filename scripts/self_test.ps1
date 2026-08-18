# Script tu kiem tra mobile sau khi Claude gom 4 provider ve SubscriptionProvider.
# Chi chay analyze + test (KHONG tu bam thu tren may ao). Ban tu chay app that
# theo huong dan o cuoi file.
#
# Cach chay: mo PowerShell tai D:\Desktop\mobile-sep, go:
#   .\scripts\self_test.ps1

Set-Location "D:\Desktop\mobile-sep"

Write-Host "=== BUOC 1: flutter analyze (phai 0 error) ===" -ForegroundColor Cyan
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Host "ANALYZE LOI - dung lai." -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "=== BUOC 2: flutter test (toan bo suite) ===" -ForegroundColor Cyan
flutter test
$testExit = $LASTEXITCODE
Write-Host ""

if ($testExit -ne 0) {
    Write-Host "CO TEST FAIL - xem ten test in do o tren." -ForegroundColor Red
    Write-Host "Test can chu y: wear_providers_registered_test.dart" -ForegroundColor Yellow
    Write-Host "  (kiem tra main_wear.dart co khai du provider ma man wear doc khong -" -ForegroundColor Yellow
    Write-Host "   da them SubscriptionProvider vao do, chay lai xem con fail khong)" -ForegroundColor Yellow
    exit 1
}
Write-Host "Test OK." -ForegroundColor Green
Write-Host ""

Write-Host "=== BUOC 3: Ban tu bam thu tren may that/may ao ===" -ForegroundColor Cyan
Write-Host "Nhung cho da doi hom nay, moi thu can xac nhan lai bang tay:" -ForegroundColor Yellow
Write-Host "  1. Man Tro ly AI mo binh thuong, gui duoc cau hoi (kiem canUseAssistant" -ForegroundColor Yellow
Write-Host "     doc dung tu SubscriptionProvider, khong con bi khoa nham)." -ForegroundColor Yellow
Write-Host "  2. Man Album: tai video len (neu goi co quyen) khong bi chan nham." -ForegroundColor Yellow
Write-Host "  3. Man Album chi tiet anh: goi y khuon mat AI van hien dung." -ForegroundColor Yellow
Write-Host "  4. Man Lich: tao su kien, dat nhac, tao su kien lap lai - dung theo" -ForegroundColor Yellow
Write-Host "     dung quyen goi hien tai, khong bi khoa nham gioi han cu." -ForegroundColor Yellow
Write-Host "  5. Wear OS (neu co may ao dong ho): mo trang chu dong ho, mo man" -ForegroundColor Yellow
Write-Host "     Lich tren dong ho - khong duoc nay ProviderNotFoundException." -ForegroundColor Yellow
Write-Host "     Chay bang: flutter run --target lib/wear/main_wear.dart" -ForegroundColor Yellow
