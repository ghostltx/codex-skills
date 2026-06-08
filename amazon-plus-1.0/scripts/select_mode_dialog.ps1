Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Amazon Plus - 生图方式选择"
$form.Size = New-Object System.Drawing.Size(520, 320)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 18)
$label.Size = New-Object System.Drawing.Size(470, 55)
$label.Text = "请选择生图方式（单选），然后点击确认："
$label.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
$form.Controls.Add($label)

$font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)

$rbA = New-Object System.Windows.Forms.RadioButton
$rbA.Text = "A: 内置 Image Gen - (1K-free) Official Stable"
$rbA.Location = New-Object System.Drawing.Point(28, 78)
$rbA.Size = New-Object System.Drawing.Size(450, 24)
$rbA.Font = $font
$form.Controls.Add($rbA)

$rbB = New-Object System.Windows.Forms.RadioButton
$rbB.Text = "B: RunningHub RH I2I - (2K-0.04/pic)"
$rbB.Location = New-Object System.Drawing.Point(28, 108)
$rbB.Size = New-Object System.Drawing.Size(450, 24)
$rbB.Font = $font
$form.Controls.Add($rbB)

$rbC = New-Object System.Windows.Forms.RadioButton
$rbC.Text = 'C: RunningHub API - (1K/2K-0.16/pic , 100-Connection)'
$rbC.Location = New-Object System.Drawing.Point(28, 138)
$rbC.Size = New-Object System.Drawing.Size(450, 24)
$rbC.Font = $font
$form.Controls.Add($rbC)

$rbD = New-Object System.Windows.Forms.RadioButton
$rbD.Text = "D: RunningHub GPT Image 2 Official Stable - (2K/4K)"
$rbD.Location = New-Object System.Drawing.Point(28, 168)
$rbD.Size = New-Object System.Drawing.Size(470, 24)
$rbD.Font = $font
$form.Controls.Add($rbD)

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = "确认"
$btnOk.Location = New-Object System.Drawing.Point(290, 220)
$btnOk.Size = New-Object System.Drawing.Size(90, 32)
$btnOk.Font = $font
$form.Controls.Add($btnOk)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Location = New-Object System.Drawing.Point(390, 220)
$btnCancel.Size = New-Object System.Drawing.Size(90, 32)
$btnCancel.Font = $font
$form.Controls.Add($btnCancel)

$selection = $null

$btnOk.Add_Click({
    if ($rbA.Checked) { $script:selection = "A" }
    elseif ($rbB.Checked) { $script:selection = "B" }
    elseif ($rbC.Checked) { $script:selection = "C" }
    elseif ($rbD.Checked) { $script:selection = "D" }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "请先选择一个选项。",
            "提示",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})

$btnCancel.Add_Click({
    $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Close()
})

$form.AcceptButton = $btnOk
$form.CancelButton = $btnCancel

$result = $form.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $selection) {
    Write-Output $selection
    exit 0
}

Write-Output "CANCEL"
exit 1
