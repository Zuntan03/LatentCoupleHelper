Add-Type -AssemblyName System.Windows.Forms;

$config = [ordered]@{
	location    = $null;
	size        = "320, 496";
	divX        = 8;
	divY        = 12;
	maxDivX     = 32;
	maxDivY     = 32;
	posX0       = 0;
	posX1       = 0;
	posY0       = 0;
	posY1       = 0;
	formOpacity = 0.5;
	transColor  = "#777777";
};

$configPath = [System.IO.Path]::ChangeExtension($PSCommandPath, ".json");
function SaveConfig() {
	$json = ConvertTo-Json $config;
	Set-Content -Path $configPath -Value $json -Encoding UTF8;
}

if ([System.IO.File]::Exists($configPath)) {
	$json = Get-Content -Path $configPath -Encoding UTF8 -Raw | ConvertFrom-Json;
	foreach ($prop in $json.PsObject.Properties) { $config[$prop.Name] = $prop.Value; }
}
SaveConfig;

function GetConfig() { return $config; }

function GetPadding($l, $t, $r, $b) { return [System.Windows.Forms.Padding]::new($l, $t, $r, $b); }

function Activate() {
	$latentCoupleHelper.form.TransparencyKey = [System.Drawing.Color]::Empty;
	$latentCoupleHelper.isActive = $true;
	$latentCoupleHelper.canvas.Invalidate();
}
function Deactivate() {
	$cfg = GetConfig;
	$latentCoupleHelper.form.TransparencyKey = $cfg.transColor;
	$latentCoupleHelper.isActive = $false;
	$latentCoupleHelper.canvas.Invalidate();
}

class LatentCoupleHelper {
	$form;
	$canvas;
	$font;
	$divTextBox;
	$areaTextBox;

	$isActive = $false;
	$basePen;
	$activePen;

	$mDragX = -1;
	$mDragY = -1;

	[void] InitializeForm() {
		$cfg = GetConfig;
		$frm = New-Object System.Windows.Forms.Form;
		$frm.Text = "LatentCoupleHelper";
		$frm.Topmost = $true;
		$frm.Opacity = $cfg.formOpacity;
		$frm.TransparencyKey = $cfg.transColor;
		$frm.Padding = GetPadding 8 0 8 0;
		$frm.ClientSize = $cfg.size;
		if ($null -ne $cfg.location) {
			$frm.StartPosition = "Manual";
			$frm.Location = $cfg.location;
		}
		$frm.Tag = $this;
		$frm.add_ResizeEnd({
				$cfg = GetConfig;
				$cfg.location = "$($this.Location.X), $($this.Location.Y)";
				$cfg.size = "$($this.ClientSize.Width), $($this.ClientSize.Height)";
				SaveConfig;
				$this.Tag.canvas.Invalidate();
			});
		$frm.add_Resize({ $this.Tag.canvas.Invalidate(); });
		$frm.add_MouseEnter({ Deactivate; });
		$frm.add_Deactivate({ Deactivate; });
		$this.form = $frm;

		$cnvsPanel = New-Object System.Windows.Forms.Panel;
		$cnvsPanel.Dock = "Fill";
		$cnvsPanel.Padding = GetPadding 16 4 16 0; #36;
		$cnvsPanel.add_MouseEnter({ Activate; });
		$frm.Controls.Add($cnvsPanel);

		$cnvs = New-Object System.Windows.Forms.PictureBox;
		$this.canvas = $cnvs;
		$cnvs.BackColor = $cfg.transColor;
		$cnvs.Dock = "Fill";
		$cnvs.Tag = $this;
		$cnvs.add_MouseEnter({ Activate; });
		$cnvs.add_MouseLeave({ Deactivate; });
		$cnvs.Add_Paint({ $this.Tag.RepaintCanvas($_, $this.Tag.canvas); });
		$cnvs.add_MouseDown({ $this.Tag.MouseEvent($_, $this.Tag.canvas); });
		$cnvs.add_MouseMove({ $this.Tag.MouseEvent($_, $this.Tag.canvas); });
		$cnvsPanel.Controls.Add($cnvs);

		$pnl = New-Object System.Windows.Forms.Panel;
		$pnl.Dock = "Top";
		$pnl.Height = 32;
		$pnl.Tag = $frm;
		$pnl.add_MouseEnter({ Deactivate; });
		$frm.Controls.Add($pnl);

		$pnlPosX = 0;
		$pnlPosY = 0;
		$btnWidth = 28;
		$btnHeight = 28;

		$btnDivYUp = New-Object System.Windows.Forms.Button;
		$btnDivYUp.Size = "$btnWidth, $btnHeight";
		$btnDivYUp.Location = "$pnlPosX, $pnlPosY";
		$pnlPosX += $btnWidth;
		$btnDivYUp.Text = "═";
		$btnDivYUp.Tag = $this;
		$btnDivYUp.add_Click({
				$cfg = GetConfig;
				if ($cfg.divY -lt $cfg.maxDivY) { $cfg.divY++; SaveConfig; $this.Tag.SetDivText(); }
			});
		$pnl.Controls.Add($btnDivYUp);

		$btnDivYDown = New-Object System.Windows.Forms.Button;
		$btnDivYDown.Size = "$btnWidth, $btnHeight";
		$btnDivYDown.Location = "$pnlPosX, $pnlPosY";
		$pnlPosX += $btnWidth;
		$btnDivYDown.Text = "─";
		$btnDivYDown.Tag = $this;
		$btnDivYDown.add_Click({
				$cfg = GetConfig;
				if ($cfg.divY -gt 1) { $cfg.divY--; SaveConfig; $this.Tag.SetDivText(); }
			});
		$pnl.Controls.Add($btnDivYDown);

		$tbxDiv = New-Object System.Windows.Forms.TextBox;
		$this.divTextBox = $tbxDiv;
		$this.font = New-Object System.Drawing.Font($tbxDiv.Font.Name, 14.0);
		$this.SetDivText();
		$tbxDiv.Font = $this.font;
		$tbxDiv.Width = 52;
		$tbxDiv.Location = "$pnlPosX, $($pnlPosY + 2)";
		$pnlPosX += 52;
		$tbxDiv.Readonly = $true;
		$tbxDiv.add_Click({ $this.SelectAll(); $this.Copy(); });
		$pnl.Controls.Add($tbxDiv);

		$btnDivXUp = New-Object System.Windows.Forms.Button;
		$btnDivXUp.Size = "$btnWidth, $btnHeight";
		$btnDivXUp.Location = "$pnlPosX, $pnlPosY";
		$pnlPosX += $btnWidth;
		$btnDivXUp.Text = "║";
		$btnDivXUp.Tag = $this;
		$btnDivXUp.add_Click({
				$cfg = GetConfig;
				if ($cfg.divX -lt $cfg.maxDivX) { $cfg.divX++; SaveConfig; $this.Tag.SetDivText(); }
			});
		$pnl.Controls.Add($btnDivXUp);

		$btnDivXDown = New-Object System.Windows.Forms.Button;
		$btnDivXDown.Size = "$btnWidth, $btnHeight";
		$btnDivXDown.Location = "$pnlPosX, $pnlPosY";
		$pnlPosX += $btnWidth + 8;
		$btnDivXDown.Text = "│";
		$btnDivXDown.Tag = $this;
		$btnDivXDown.add_Click({
				$cfg = GetConfig;
				if ($cfg.divX -gt 1) { $cfg.divX--; SaveConfig; $this.Tag.SetDivText(); }
			}); $pnl.Controls.Add($btnDivXDown);

		$tbxArea = New-Object System.Windows.Forms.TextBox;
		$this.areaTextBox = $tbxArea;
		$this.SetAreaText();
		$tbxArea.Font = $this.font;
		$tbxArea.Width = 120;
		$tbxArea.Location = "$pnlPosX, $($pnlPosY + 2)";
		$tbxArea.Readonly = $true;
		$tbxArea.add_Click({ $this.SelectAll(); $this.Copy(); });
		$pnl.Controls.Add($tbxArea);

		$this.basePen = New-Object System.Drawing.Pen("#000000", 1.0);
		$this.activePen = New-Object System.Drawing.Pen("#FFFFFF", 1.0);
	
	}

	[void] SetDivText() {
		$cfg = GetConfig;
		$this.divTextBox.Text = "$($cfg.divY):$($cfg.divX)";
		$this.canvas.Invalidate();
	}

	[void] SetAreaText() {
		$cfg = GetConfig;
		$txt = "$($cfg.posY0)";
		if ($cfg.posY0 -ne $cfg.posY1) { $txt += "-$($cfg.posY1)"; }
		$txt += ":$($cfg.posX0)";
		if ($cfg.posX0 -ne $cfg.posX1) { $txt += "-$($cfg.posX1)"; }
		$this.areaTextBox.Text = $txt;
		$this.canvas.Invalidate();
	}

	[void] RepaintCanvas($e, $canvas) {
		$cfg = GetConfig;
		$gfx = $e.Graphics;
		$pad = 8;
		$cWidth = $canvas.Width - $pad * 2;
		$cHeight = $canvas.Height - $pad * 2;

		if ($this.isActive) {
			$gfx.DrawRectangle($this.basePen, $pad, $pad, $cWidth, $cHeight);

			$xSpan = $cWidth / $cfg.divX;
			for ($x = 1; $x -le $cfg.divX; $x++) {
				$xPos = $pad + $xSpan * $x;
				$gfx.DrawLine($this.basePen, $xPos, $pad, $xPos, $pad + $cHeight);
			}
			
			$ySpan = $cHeight / $cfg.divY;
			for ($y = 1; $y -le $cfg.divY; $y++) {
				$yPos = $pad + $ySpan * $y;
				$gfx.DrawLine($this.basePen, $pad, $yPos, $pad + $cWidth, $yPos);
			}

			$subX = $cfg.posX1 - $cfg.posX0;
			if ($subX -le 0) { $subX = 1; }
			$subY = $cfg.posY1 - $cfg.posY0;
			if ($subY -le 0) { $subY = 1; }
			$gfx.DrawRectangle($this.activePen,
				$pad + $cfg.posX0 * $xSpan, $pad + $cfg.posY0 * $ySpan,
				$xSpan * $subX , $ySpan * $subY);
		}
		else {
			$gfx.DrawRectangle($this.activePen, $pad, $pad, $cWidth, $cHeight);
		}
	}

	[void] MouseEvent($e, $canvas) {
		if ($e.Button -ne "Left") { 
			$this.mDragX = $this.mDragY = -1;
			return;
		}
		$clamp = {
			param([double] $value, [int] $maxValue)
			$val = [Math]::Truncate($value);
			if ($val -lt 0) { return 0; }
			if ($val -gt $maxValue) { return $maxValue; }
			return $val;
		}

		$cfg = GetConfig;
		$pad = 8;
		$cWidth = $canvas.Width - $pad * 2;
		$cHeight = $canvas.Height - $pad * 2;
		$xSpan = $cWidth / $cfg.divX;
		$ySpan = $cHeight / $cfg.divY;
		if ($this.mDragX -eq -1) {
			$this.mDragX = $e.X;
			$this.mDragY = $e.Y;
			$cfg.posX0 = $cfg.posX1 = &$clamp (($e.X - $pad) / $xSpan) ($cfg.divX - 1);
			$cfg.posY0 = $cfg.posY1 = &$clamp (($e.Y - $pad) / $ySpan) ($cfg.divY - 1);
			Write-Host "$($e.X - $pad) $xSpan $($cfg.posX0) $([int]1.3) $([int]1.8)"
		}
		else {
			if ($e.X -lt $this.mDragX) {
				$cfg.posX0 = &$clamp (($e.X - $pad) / $xSpan) ($cfg.divX - 1);
				$cfg.posX1 = &$clamp (($this.mDragX - $pad) / $xSpan + 1) $cfg.divX;
			}
			else {
				$cfg.posX0 = &$clamp (($this.mDragX - $pad) / $xSpan) ($cfg.divX - 1);
				$cfg.posX1 = &$clamp (($e.X - $pad) / $xSpan + 1) $cfg.divX;
			}
			if ($cfg.posX1 - $cfg.posX0 -eq 1) { $cfg.posX1 = $cfg.posX0; }

			if ($e.Y -lt $this.mDragY) {
				$cfg.posY0 = &$clamp (($e.Y - $pad) / $ySpan) ($cfg.divY - 1);
				$cfg.posY1 = &$clamp (($this.mDragY - $pad) / $ySpan + 1) $cfg.divY;
			}
			else {
				$cfg.posY0 = &$clamp (($this.mDragY - $pad) / $ySpan) ($cfg.divY - 1);
				$cfg.posY1 = &$clamp (($e.Y - $pad) / $ySpan + 1) $cfg.divY;
			}
			if ($cfg.posY1 - $cfg.posY0 -eq 1) { $cfg.posY1 = $cfg.posY0; }
		}
		SaveConfig;
		$this.SetAreaText();
	}
}

[System.Windows.Forms.Application]::EnableVisualStyles();
$latentCoupleHelper = New-Object LatentCoupleHelper;
$latentCoupleHelper.InitializeForm();

Add-Type -Name Window -Namespace Console -MemberDefinition '
	[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
	[DllImport("user32.dll")] public static extern void ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0);

[System.Windows.Forms.Application]::Run($latentCoupleHelper.form);
$latentCoupleHelper.form.Dispose();
