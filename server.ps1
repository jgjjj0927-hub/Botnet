# wormcontrol server — экран + управление, без внешних зависимостей
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Core

# P/Invoke один раз
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, int f, int e);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
}
"@

$port = 50506
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Start()
Write-Host "[*] wormcontrol слушает $port"

function Send-Frame($stream) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $data = $ms.ToArray()
    $len = [BitConverter]::GetBytes([int]$data.Length)
    $stream.Write($len, 0, 4)
    $stream.Write($data, 0, $data.Length)
    $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
}

function Recv-Exact($stream, $n) {
    $buf = New-Object byte[] $n
    $read = 0
    while ($read -lt $n) {
        $r = $stream.Read($buf, $read, $n - $read)
        if ($r -le 0) { throw "disconnect" }
        $read += $r
    }
    return $buf
}

function Handle-Client($client) {
    $stream = $client.GetStream()
    $sending = $true

    # поток отправки кадров
    $sendThread = {
        param($s, [ref]$flag)
        while ($flag.Value) {
            try { Send-Frame $s; Start-Sleep -Milliseconds 66 } catch { $flag.Value = $false }
        }
    }
    $ps = [PowerShell]::Create()
    $ps.AddScript($sendThread).AddArgument($stream).AddArgument([ref]$sending) | Out-Null
    $ps.BeginInvoke() | Out-Null

    # приём событий
    try {
        while ($true) {
            $t = Recv-Exact $stream 1
            switch ($t[0]) {
                77 { # 'M' — движение мыши
                    $d = Recv-Exact $stream 8
                    $x = [BitConverter]::ToInt32($d, 0)
                    $y = [BitConverter]::ToInt32($d, 4)
                    [Win32]::SetCursorPos($x, $y) | Out-Null
                }
                66 { # 'B' — кнопка мыши
                    $d = Recv-Exact $stream 2
                    $btn = $d[0]; $st = $d[1]
                    $flag = if ($btn -eq 1) { if ($st -eq 1) { 0x0002 } else { 0x0004 } } else { if ($st -eq 1) { 0x0008 } else { 0x0010 } }
                    [Win32]::mouse_event($flag, 0, 0, 0, 0)
                }
                75 { # 'K' — клавиатура
                    $d = Recv-Exact $stream 2
                    $vk = $d[0]; $st = $d[1]
                    if ($st -eq 1) { [Win32]::keybd_event($vk, 0, 0, 0) }
                    else { [Win32]::keybd_event($vk, 0, 2, 0) }
                }
            }
        }
    } catch { }
    $sending = $false
    $ps.Stop(); $client.Close()
}

# основной цикл — каждый клиент в своём runspace
while ($true) {
    $client = $listener.AcceptTcpClient()
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript(${function:Handle-Client}).AddArgument($client) | Out-Null
    $ps.BeginInvoke() | Out-Null
}
