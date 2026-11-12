param([string]$OwnerKeyPath = '', [string]$PreviewPath = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Issuer.Core.ps1')
[System.Windows.Forms.Application]::EnableVisualStyles()
$keyPath = $OwnerKeyPath
if (!$keyPath) { $keyPath = Join-Path $env:LOCALAPPDATA 'DinhDuocVoiceStudioIssuer\owner-key.dpapi' }
try { $rsa = Get-DDVSOwnerKey $keyPath }
catch {
    [System.Windows.Forms.MessageBox]::Show('Không đọc được khóa cấp mã. Hãy dùng đúng tài khoản Windows đã tạo khóa. Không xóa hoặc thay thế file khóa. Chi tiết: ' + $_.Exception.Message, 'ĐÌNH ĐƯỢC- VOICE STUDIO') | Out-Null
    exit 1
}
$form = New-Object System.Windows.Forms.Form
$form.Text = 'ĐÌNH ĐƯỢC- VOICE STUDIO | Công cụ cấp mã (chỉ chủ app giữ)'
$form.Size = New-Object Drawing.Size(960,780)
$form.MinimumSize = New-Object Drawing.Size(800,650)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'; $layout.Padding = New-Object Windows.Forms.Padding(16)
$layout.ColumnCount = 1; $layout.RowCount = 7
@(100,32,0,48,28,0,32) | ForEach-Object {
    $style = New-Object Windows.Forms.RowStyle
    if ($_ -eq 0) { $style.SizeType='Percent'; $style.Height=50 } else { $style.SizeType='Absolute'; $style.Height=$_ }
    $layout.RowStyles.Add($style) | Out-Null
}
$form.Controls.Add($layout)
$header = New-Object Windows.Forms.FlowLayoutPanel
$header.Dock='Fill';$header.WrapContents=$false;$header.FlowDirection='TopDown'
$export = New-Object Windows.Forms.Button
$export.Text='1. Xuất KHÓA CÔNG KHAI để tạo app'; $export.AutoSize=$true; $export.Padding=New-Object Windows.Forms.Padding(8)
$header.Controls.Add($export)
$tip = New-Object Windows.Forms.Label
$tip.Text='Lần đầu: bấm xuất khóa công khai và gửi file JSON để đóng gói app. Khóa bí mật được giữ trên máy này.'
$tip.AutoSize=$true;$tip.Padding=New-Object Windows.Forms.Padding(0,8,0,0)
$header.Controls.Add($tip); $layout.Controls.Add($header,0,0)
$label = New-Object Windows.Forms.Label
$label.Text='Dán mã máy (mỗi dòng một máy; có thể thêm tên sau mã: A1B2-C3D4-E5F6-0718 Nguyễn Văn A):'
$label.Dock='Fill';$layout.Controls.Add($label,0,1)
$inputBox = New-Object Windows.Forms.TextBox
$inputBox.Multiline=$true;$inputBox.ScrollBars='Both';$inputBox.WordWrap=$false;$inputBox.Dock='Fill';$inputBox.AcceptsReturn=$true
$layout.Controls.Add($inputBox,0,2)
$options = New-Object Windows.Forms.FlowLayoutPanel
$options.Dock='Fill';$options.Padding=New-Object Windows.Forms.Padding(0,8,0,0)
$forever = New-Object Windows.Forms.RadioButton
$forever.Text='Vĩnh viễn';$forever.AutoSize=$true;$options.Controls.Add($forever)
$timed = New-Object Windows.Forms.RadioButton
$timed.Text='Hết hạn sau';$timed.Checked=$true;$timed.AutoSize=$true;$options.Controls.Add($timed)
$days = New-Object Windows.Forms.NumericUpDown
$days.Minimum=1;$days.Maximum=36500;$days.Value=30;$days.Width=70;$options.Controls.Add($days)
$daysLabel = New-Object Windows.Forms.Label
$daysLabel.Text='ngày';$daysLabel.AutoSize=$true;$daysLabel.Padding=New-Object Windows.Forms.Padding(0,4,10,0);$options.Controls.Add($daysLabel)
$generate = New-Object Windows.Forms.Button
$generate.Text='Tạo mã';$generate.AutoSize=$true;$options.Controls.Add($generate)
$copy = New-Object Windows.Forms.Button
$copy.Text='Copy kết quả';$copy.AutoSize=$true;$options.Controls.Add($copy)
$save = New-Object Windows.Forms.Button
$save.Text='Lưu kết quả TXT';$save.AutoSize=$true;$options.Controls.Add($save)
$layout.Controls.Add($options,0,3)
$resultLabel = New-Object Windows.Forms.Label
$resultLabel.Text='Kết quả:';$resultLabel.Dock='Fill';$layout.Controls.Add($resultLabel,0,4)
$outputBox = New-Object Windows.Forms.TextBox
$outputBox.Multiline=$true;$outputBox.ReadOnly=$true;$outputBox.ScrollBars='Vertical';$outputBox.WordWrap=$true;$outputBox.Dock='Fill'
$layout.Controls.Add($outputBox,0,5)
$status = New-Object Windows.Forms.Label
$status.Text='Hạn sử dụng tính từ lúc tạo mã. Bạn bè chỉ nhận mã kích hoạt, không nhận công cụ này.'
$status.Dock='Fill';$status.AutoEllipsis=$true;$layout.Controls.Add($status,0,6)
$export.Add_Click({
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Filter='Khóa công khai JSON (*.json)|*.json';$dialog.FileName='DINH-DUOC-PUBLIC-KEY.json'
    if ($dialog.ShowDialog() -eq 'OK') {
        try {
            [IO.File]::WriteAllText($dialog.FileName, ((Get-DDVSPublicKey $rsa) | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
            $status.Text='Đã xuất khóa công khai: ' + $dialog.FileName + ' — gửi file này để đóng gói app.'
        } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Không xuất được khóa') | Out-Null }
    }
    $dialog.Dispose()
})
$forever.Add_CheckedChanged({$days.Enabled = !$forever.Checked})
$generate.Add_Click({
    try {
        $machines = @(Read-DDVSMachineLines $inputBox.Text)
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $expiryText='Vĩnh viễn'
        if (!$forever.Checked) { $expiryText=[DateTimeOffset]::FromUnixTimeSeconds($now + [long]$days.Value * 86400).ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss zzz') }
        $blocks = @()
        foreach ($machine in $machines) {
            $key=New-DDVSLicense -Rsa $rsa -Machine $machine.machine -Days ([int]$days.Value) -Perpetual:$forever.Checked -Note $machine.note -Now $now
            $blocks += ('Mã máy: ' + $machine.machine + ' ' + $machine.note + "`r`nHết hạn: " + $expiryText + "`r`nMã kích hoạt:`r`n" + $key)
        }
        $outputBox.Text=$blocks -join "`r`n`r`n--------------------`r`n`r`n"
        $status.Text='Đã tạo mã cho ' + $machines.Count + ' máy. Hạn tính từ thời điểm tạo mã.'
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Không tạo được mã') | Out-Null }
})
$copy.Add_Click({ if ($outputBox.Text) { [Windows.Forms.Clipboard]::SetText($outputBox.Text);$status.Text='Đã copy kết quả.' } })
$save.Add_Click({
    if (!$outputBox.Text) { return }
    $dialog=New-Object Windows.Forms.SaveFileDialog
    $dialog.Filter='Văn bản (*.txt)|*.txt';$dialog.FileName='MA-KICH-HOAT.txt'
    if ($dialog.ShowDialog() -eq 'OK') { [IO.File]::WriteAllText($dialog.FileName,$outputBox.Text,(New-Object Text.UTF8Encoding($true))) }
    $dialog.Dispose()
})
try {
    if ($PreviewPath) {
        $inputBox.Text="A1B2-C3D4-E5F6-0718 Nguyen Van A`r`n1122-3344-5566-7788 Tran Van B"
        $form.Show(); [Windows.Forms.Application]::DoEvents(); $generate.PerformClick(); [Windows.Forms.Application]::DoEvents()
        $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
        try { $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png) }
        finally { $bitmap.Dispose() }
        if (!$outputBox.Text.Contains('DDVS1.')) { throw 'Preview generation did not produce activation codes' }
        $form.Close()
    } else { [Windows.Forms.Application]::Run($form) }
} finally { $rsa.Dispose();$form.Dispose() }
