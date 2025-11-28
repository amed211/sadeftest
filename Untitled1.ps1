# Yönetici yetkisi kontrolü
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Bu script yönetici yetkisi gerektirir!"
    exit
}

# Önce eski servisi kaldır
$existingService = Get-Service -Name "Tor" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Eski Tor servisi kaldırılıyor..."
    Stop-Service -Name "Tor" -Force -ErrorAction SilentlyContinue
    sc.exe delete Tor
    Start-Sleep -Seconds 2
}

# Değişkenler - GÜNCEL LİNK
$torUrl = "https://archive.torproject.org/tor-package-archive/torbrowser/13.5.7/tor-expert-bundle-windows-x86_64-13.5.7.tar.gz"
$downloadPath = "$env:TEMP\tor-expert-bundle.tar.gz"
$extractPath = "C:\Tor"
$torDataPath = "$extractPath\data"

# Eski kurulumu temizle
if (Test-Path $extractPath) {
    Write-Host "Eski kurulum temizleniyor..."
    Remove-Item -Path $extractPath -Recurse -Force
}

# Tor Expert Bundle'ı indir
Write-Host "Tor Expert Bundle indiriliyor..."
try {
    Invoke-WebRequest -Uri $torUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "Indirme tamamlandi." -ForegroundColor Green
} catch {
    Write-Error "Indirme basarisiz: $_"
    exit
}

# Dosyaları çıkart
Write-Host "Dosyalar cikartiliyor..."
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null

try {
    tar -xzf $downloadPath -C $extractPath
    Write-Host "Cikartma tamamlandi." -ForegroundColor Green
} catch {
    Write-Error "Cikartma basarisiz: $_"
    exit
}

# Tor klasör yapısını kontrol et
$torExePath = Get-ChildItem -Path $extractPath -Filter "tor.exe" -Recurse | Select-Object -First 1
if (-not $torExePath) {
    Write-Error "tor.exe bulunamadi!"
    exit
}

$torFolder = $torExePath.DirectoryName
Write-Host "Tor.exe bulundu: $torFolder"

# Data klasörü oluştur
New-Item -ItemType Directory -Force -Path $torDataPath | Out-Null

# torrc yapılandırma dosyası oluştur
Write-Host "Yapilandirma dosyasi olusturuluyor..."
$torrcPath = Join-Path $torFolder "torrc"
$torrcContent = "DataDirectory $torDataPath
SocksPort 9050
ControlPort 9051
Log notice file $extractPath\tor.log"

$torrcContent | Out-File -FilePath $torrcPath -Encoding ASCII

# Windows servisi olarak kaydet
Write-Host "Tor servisi olusturuluyor..."
$torExe = Join-Path $torFolder "tor.exe"
$binPath = "`"$torExe`" -f `"$torrcPath`""

sc.exe create Tor binPath= $binPath DisplayName= "Tor Service" start= auto
sc.exe description Tor "Tor anonymity network service"

# Servisi başlat
Write-Host "Tor servisi baslatiliyor..."
Start-Sleep -Seconds 2
Start-Service -Name "Tor"

# Durum kontrolü
Start-Sleep -Seconds 3
$service = Get-Service -Name "Tor"

if ($service.Status -eq "Running") {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "Tor servisi basariyla kuruldu ve calisiyor!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "SOCKS proxy: localhost:9050"
    Write-Host "Control port: localhost:9051"
    Write-Host "Log dosyasi: $extractPath\tor.log"
    Write-Host ""
    Write-Host "Servis komutlari:"
    Write-Host "  Baslatma: net start Tor"
    Write-Host "  Durdurma: net stop Tor"
    Write-Host "  Durum: Get-Service Tor"
} else {
    Write-Warning "Servis kuruldu ama baslamadi. Log dosyasini kontrol edin:"
    Write-Host "$extractPath\tor.log"
    Write-Host ""
    Write-Host "Manuel baslatma:"
    Write-Host "net start Tor"
}