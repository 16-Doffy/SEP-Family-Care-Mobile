# Script huong dan tu test flow Task theo 3 vai tro (Manager/Deputy/Member).
# Chi in checklist - ban tu bam tay tren may that/may ao, doi chieu ket qua.
#
# Cach chay: mo PowerShell tai D:\Desktop\mobile-sep, go:
#   .\scripts\test_task_role_flow.ps1

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " TEST FLOW TASK THEO VAI TRO - Manager / Deputy / Member" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Da cai ban APK moi nhat (co fix 24/08: loc nguoi nhan theo vai tro +" -ForegroundColor Yellow
Write-Host "fix banner thuong phia Member khong hien duoc)." -ForegroundColor Yellow
Write-Host ""
Write-Host "LUU Y QUAN TRONG: FE moi chi chan o GIAO DIEN (an bot lua chon trong" -ForegroundColor Yellow
Write-Host "danh sach nguoi nhan). BE HIEN CHUA ENFORCE that o server - da test" -ForegroundColor Yellow
Write-Host "truc tiep bang API, ca 2 chieu deu qua duoc (201). Neu goi thang API" -ForegroundColor Yellow
Write-Host "(khong qua app) van se giao duoc sai luat - cho BE tra loi." -ForegroundColor Yellow
Write-Host ""

Write-Host "=== BUOC 1: Dang nhap MANAGER (ngophamnhutduy050302@gmail.com) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1.1 Tao 1 task AD_HOC (khong lap lai) -> bam Giao viec" -ForegroundColor White
Write-Host "      Ky vong: danh sach nguoi nhan CO Member, CO chinh Manager (tu giao)," -ForegroundColor White
Write-Host "      KHONG CO Deputy (vi task khong phai dinh ky)." -ForegroundColor White
Write-Host ""
Write-Host "  1.2 Tao 1 task DINH KY (RECURRING) -> bam Giao viec / tao phan cong" -ForegroundColor White
Write-Host "      Ky vong: lan nay CO thay Deputy trong danh sach (dung luat: Manager" -ForegroundColor White
Write-Host "      chi giao dinh ky duoc cho Deputy)." -ForegroundColor White
Write-Host ""
Write-Host "  1.3 Tu giao 1 task AD_HOC cho chinh minh (Manager)" -ForegroundColor White
Write-Host "      Ky vong: giao duoc binh thuong (khong bi chan)." -ForegroundColor White
Write-Host ""
Write-Host "  1.4 Lam xong task tu giao o buoc 1.3, nop bai -> vao xem co tu duyet" -ForegroundColor White
Write-Host "      duoc bai nop cua chinh minh khong" -ForegroundColor White
Write-Host "      Ky vong: KHONG tu duyet duoc (nut Duyet/Tu choi phai an hoac bao loi -" -ForegroundColor White
Write-Host "      code da co check 'Reviewer va nguoi thuc hien phai khac nhau')." -ForegroundColor White
Write-Host ""

Write-Host "=== BUOC 2: Dang nhap DEPUTY (duynpnse161783@fpt.edu.vn) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2.1 Tao 1 task bat ky -> bam Giao viec" -ForegroundColor White
Write-Host "      Ky vong: danh sach nguoi nhan CO Member, CO chinh Deputy (tu giao)," -ForegroundColor White
Write-Host "      KHONG CO Manager (dung luat: Deputy chi giao duoc cho Member)." -ForegroundColor White
Write-Host ""
Write-Host "  2.2 Thu tu giao task cho chinh minh (Deputy)" -ForegroundColor White
Write-Host "      Ky vong HIEN TAI: BE tra loi 403 'Deputy member cannot perform this" -ForegroundColor White
Write-Host "      action for their own assignment' - se thay loi ngay khi bam Giao." -ForegroundColor White
Write-Host "      Day la diem dang cho BE xac nhan co dung y hay khong (xem cuoi file)." -ForegroundColor White
Write-Host ""
Write-Host "  2.3 Deputy duyet bai cua Member (khong phai cua chinh minh)" -ForegroundColor White
Write-Host "      Ky vong: duyet/tu choi binh thuong, kem duoc ghi chu (Deputy co quyen" -ForegroundColor White
Write-Host "      duyet nhu Manager)." -ForegroundColor White
Write-Host ""

Write-Host "=== BUOC 3: Dang nhap MEMBER (tai khoan thanh vien thuong bat ky) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3.1 Nhan task tu Manager hoac Deputy kem phan thuong -> lam va nop bai" -ForegroundColor White
Write-Host ""
Write-Host "  3.2 Sau khi Manager/Deputy duyet bai (task chuyen APPROVED), mo lai chi" -ForegroundColor White
Write-Host "      tiet task do tu phia Member" -ForegroundColor White
Write-Host "      Ky vong: thay khoi 'Phan thuong: ... - Cho xac nhan' (truoc day khoi" -ForegroundColor White
Write-Host "      nay KHONG BAO GIO hien ra du trang thai gi - da fix 24/08)." -ForegroundColor White
Write-Host ""
Write-Host "  3.3 Quay lai tai khoan Manager/Deputy, vao muc Quan ly thuong, bam nut" -ForegroundColor White
Write-Host "      'Huy' tren settlement vua tao (KHONG bam Danh dau da tra)" -ForegroundColor White
Write-Host ""
Write-Host "  3.4 Quay lai tai khoan Member, mo lai chi tiet task do lan nua" -ForegroundColor White
Write-Host "      Ky vong: khoi phan thuong doi thanh 'Phan thuong: ... - Da huy' -" -ForegroundColor White
Write-Host "      day chinh la truong hop ban bao loi luc truoc, gio phai hien ra roi." -ForegroundColor White
Write-Host ""

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Test xong bao lai ket qua tung buoc, dac biet 1.4 (tu duyet) va 3.4" -ForegroundColor Cyan
Write-Host " (banner thuong) - 2 cho de sai nhat neu code lech gia dinh." -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
