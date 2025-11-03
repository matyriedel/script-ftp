# Script para descargar archivos .rar desde servidor FTP/SFTP
# Ejecutar: .\download_files.ps1

# ============================================
# CONFIGURACIÓN - MODIFICAR ESTOS VALORES
# ============================================
$Protocol = "FTP"  # Cambiar a "SFTP" si es necesario
$Server = "ftp.ejemplo.com"  # Dirección del servidor
$Username = "usuario"  # Usuario FTP/SFTP
$Password = "contraseña"  # Contraseña FTP/SFTP
$RemotePath = "/ruta/remota/archivos"  # Ruta remota donde están los archivos .rar
$Port = 21  # Puerto FTP (21) o SFTP (22)

# ============================================
# NO MODIFICAR A PARTIR DE AQUÍ
# ============================================

# Obtener el directorio donde está el script
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptPath

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Descarga de archivos .rar desde servidor" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Protocolo: $Protocol" -ForegroundColor Yellow
Write-Host "Servidor: $Server" -ForegroundColor Yellow
Write-Host "Ruta remota: $RemotePath" -ForegroundColor Yellow
Write-Host "Directorio destino: $ScriptPath" -ForegroundColor Yellow
Write-Host ""

if ($Protocol -eq "FTP") {
    try {
        Write-Host "Conectando al servidor FTP..." -ForegroundColor Green
        
        # Construir la URI FTP
        $FtpUri = "ftp://${Server}:${Port}${RemotePath}"
        
        # Crear credenciales
        $FtpRequest = [System.Net.FtpWebRequest]::Create($FtpUri)
        $FtpRequest.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        $FtpRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $FtpRequest.UseBinary = $true
        $FtpRequest.UsePassive = $true
        
        # Obtener lista de archivos
        Write-Host "Obteniendo lista de archivos..." -ForegroundColor Green
        $Response = $FtpRequest.GetResponse()
        $ResponseStream = $Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Files = $Reader.ReadToEnd()
        $Reader.Close()
        $Response.Close()
        
        # Filtrar archivos .rar
        $RarFiles = $Files -split "`r`n" | Where-Object { $_ -match "\.rar$" -and $_ -ne "" }
        
        if ($RarFiles.Count -eq 0) {
            Write-Host "No se encontraron archivos .rar en la ruta especificada." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Archivos .rar encontrados: $($RarFiles.Count)" -ForegroundColor Green
        
        # Descargar cada archivo .rar
        foreach ($FileName in $RarFiles) {
            $FileName = $FileName.Trim()
            if ([string]::IsNullOrWhiteSpace($FileName)) { continue }
            
            $RemoteFile = "$RemotePath/$FileName".Replace("//", "/")
            $LocalFile = Join-Path $ScriptPath $FileName
            $FileUri = "ftp://${Server}:${Port}${RemoteFile}"
            
            Write-Host "Descargando: $FileName..." -ForegroundColor Yellow
            
            try {
                $FtpRequest = [System.Net.FtpWebRequest]::Create($FileUri)
                $FtpRequest.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
                $FtpRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
                $FtpRequest.UseBinary = $true
                $FtpRequest.UsePassive = $true
                
                $Response = $FtpRequest.GetResponse()
                $ResponseStream = $Response.GetResponseStream()
                $FileStream = New-Object System.IO.FileStream($LocalFile, [System.IO.FileMode]::Create)
                $ResponseStream.CopyTo($FileStream)
                $FileStream.Close()
                $ResponseStream.Close()
                $Response.Close()
                
                $FileSize = (Get-Item $LocalFile).Length / 1MB
                Write-Host "  ✓ Descargado: $FileName ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ Error al descargar $FileName : $_" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Write-Host "Proceso completado!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error al conectar al servidor FTP: $_" -ForegroundColor Red
        Write-Host "Verifique la configuración del servidor, usuario y contraseña." -ForegroundColor Yellow
        exit 1
    }
}
elseif ($Protocol -eq "SFTP") {
    # Para SFTP necesitamos usar un módulo de PowerShell o WinSCP
    Write-Host "Conectando al servidor SFTP..." -ForegroundColor Green
    
    # Intentar usar Posh-SSH si está instalado
    $PoshSSHAvailable = $false
    try {
        Import-Module Posh-SSH -ErrorAction Stop
        $PoshSSHAvailable = $true
        Write-Host "Usando módulo Posh-SSH..." -ForegroundColor Green
    }
    catch {
        Write-Host "Módulo Posh-SSH no encontrado. Intentando con WinSCP..." -ForegroundColor Yellow
    }
    
    if ($PoshSSHAvailable) {
        try {
            # Crear credenciales
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
            
            # Conectar al servidor SFTP
            Write-Host "Conectando..." -ForegroundColor Green
            $Session = New-SFTPSession -ComputerName $Server -Port $Port -Credential $Credential -AcceptKey
            
            if ($Session) {
                Write-Host "Conectado exitosamente!" -ForegroundColor Green
                Write-Host "Obteniendo lista de archivos..." -ForegroundColor Green
                
                # Listar archivos en la ruta remota
                $Files = Get-SFTPChildItem -SessionId $Session.SessionId -Path $RemotePath | Where-Object { $_.Name -match "\.rar$" }
                
                if ($Files.Count -eq 0) {
                    Write-Host "No se encontraron archivos .rar en la ruta especificada." -ForegroundColor Red
                    Remove-SFTPSession -SessionId $Session.SessionId
                    exit 1
                }
                
                Write-Host "Archivos .rar encontrados: $($Files.Count)" -ForegroundColor Green
                
                # Descargar cada archivo
                foreach ($File in $Files) {
                    $RemoteFile = "$RemotePath/$($File.Name)".Replace("//", "/")
                    $LocalFile = Join-Path $ScriptPath $File.Name
                    
                    Write-Host "Descargando: $($File.Name)..." -ForegroundColor Yellow
                    
                    try {
                        Get-SFTPFile -SessionId $Session.SessionId -RemoteFile $RemoteFile -LocalFile $LocalFile
                        $FileSize = (Get-Item $LocalFile).Length / 1MB
                        Write-Host "  ✓ Descargado: $($File.Name) ($([math]::Round($FileSize, 2)) MB)" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  ✗ Error al descargar $($File.Name) : $_" -ForegroundColor Red
                    }
                }
                
                # Cerrar sesión
                Remove-SFTPSession -SessionId $Session.SessionId
                Write-Host ""
                Write-Host "Proceso completado!" -ForegroundColor Green
            }
            else {
                Write-Host "Error: No se pudo establecer la conexión SFTP." -ForegroundColor Red
                exit 1
            }
        }
        catch {
            Write-Host "Error al conectar al servidor SFTP: $_" -ForegroundColor Red
            Write-Host "Verifique la configuración del servidor, usuario y contraseña." -ForegroundColor Yellow
            exit 1
        }
    }
    else {
        # Intentar usar WinSCP si está disponible
        Write-Host ""
        Write-Host "Para usar SFTP, necesita instalar uno de los siguientes:" -ForegroundColor Yellow
        Write-Host "1. Módulo Posh-SSH: Install-Module -Name Posh-SSH -Scope CurrentUser" -ForegroundColor Cyan
        Write-Host "2. WinSCP (versión COM)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Alternativamente, puede usar un cliente SFTP gráfico como WinSCP o FileZilla." -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "Protocolo no válido. Use 'FTP' o 'SFTP'." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Presione cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

