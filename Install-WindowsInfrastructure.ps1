<#
.SYNOPSIS
    Script Avançado de Infraestrutura Windows Server (ADDC, DNS, DHCP e File Server).
    
.DESCRIPTION
    Versão profissional com logging em ficheiro, funções modulares e auto-resume após reinicios.
    
    Autor: Especialista Windows Server (Antigravity)
    Data: 20/03/2026
#>

# --- CONFIGURAÇÕES DO AMBIENTE ---
$DomainName = "aster.local"
$NetbiosName = "ASTER"
$SafeModePasswordString = "P@ssw0rd2026!"
$IPAddress = "10.0.0.1"
$SubnetMask = "255.255.255.0"
$Gateway = "10.0.0.1"
$DNSServer = "127.0.0.1"
$InterfaceAlias = "Ethernet0"
$LogPath = "C:\Logs\Infrastructure_Setup.log"
$StageFile = "C:\Logs\SetupStage.txt"

# Criar pasta de logs se não existir
if (!(Test-Path "C:\Logs")) { New-Item -Path "C:\Logs" -ItemType Directory | Out-Null }

# --- FUNÇÃO DE LOGGING ---
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Stamp] [$Level] $Message"
    Write-Host $LogMessage -ForegroundColor (switch($Level){"INFO"{"Cyan"};"WARN"{"Yellow"};"ERROR"{"Red"};Default{"White"}})
    $LogMessage | Out-File -FilePath $LogPath -Append
}

# --- FUNÇÃO: CONFIGURAÇÃO DE REDE ---
function Set-NetworkConfig {
    Write-Log "Iniciando configuração de rede..."
    try {
        New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServer
        Rename-Computer -NewName "DC01" -Force -ErrorAction SilentlyContinue
        Write-Log "Rede configurada e Hostname definido para DC01."
    } catch {
        Write-Log "Erro na configuração de rede: $($_.Exception.Message)" "ERROR"
    }
}

# --- FUNÇÃO: INSTALAR ADDS ---
function Install-ADDSComponent {
    Write-Log "Instalando a feature ADDS..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    
    Write-Log "Promovendo o servidor a DC (Novo Forest)..."
    "2" | Out-File $StageFile # Guardar que a próxima etapa é a fase 2 (Pós-Reboot)
    
    # Adicionar script ao RunOnce para continuar após reboot
    $ScriptPath = $MyInvocation.MyCommand.Path
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ResumeInfrastructureSetup" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`""

    $Password = ConvertTo-SecureString $SafeModePasswordString -AsPlainText -Force
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetbiosName `
        -SafeModeAdministratorPassword $Password `
        -InstallDns:$true `
        -Force:$true `
        -NoRebootOnCompletion:$false
}

# --- FUNÇÃO: CONFIGURAR DHCP ---
function Configure-DHCPComponent {
    Write-Log "Iniciando configuração do DHCP..."
    if (!((Get-WindowsFeature -Name DHCP).Installed)) {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools
    }
    
    try {
        Add-DhcpServerv4Scope -Name "Escopo Principal" -StartRange "10.0.0.100" -EndRange "10.0.0.200" -SubnetMask $SubnetMask -ErrorAction SilentlyContinue
        Set-DhcpServerv4OptionValue -ScopeId 10.0.0.0 -DnsServer $IPAddress -Router $Gateway
        Set-DhcpServerv4OptionValue -DnsServer "8.8.8.8","8.8.4.4" # Google DNS como forwarders opcionais
        Add-DhcpServerInDC -DnsName "DC01.$DomainName" -IPAddress $IPAddress -ErrorAction SilentlyContinue
        Write-Log "DHCP configurado e autorizado no AD."
    } catch {
        Write-Log "Erro no DHCP: $($_.Exception.Message)" "ERROR"
    }
}

# --- FUNÇÃO: FILE SERVER ---
function Configure-FileServerComponent {
    Write-Log "Configurando o File Server..."
    Install-WindowsFeature -Name File-Services, FS-Resource-Manager -IncludeManagementTools
    
    $SharePath = "C:\Shares\Corporativo"
    if (!(Test-Path $SharePath)) {
        New-Item -Path $SharePath -ItemType Directory
        New-SmbShare -Name "Corporativo" -Path $SharePath -FullAccess "Everyone"
        Write-Log "Partilha 'Corporativo' criada em $SharePath"
    }
}

# --- LÓGICA PRINCIPAL (AUTO-RESUME) ---
Clear-Host
Write-Log "=== INÍCIO DA CONFIGURAÇÃO DE INFRAESTRUTURA ==="

if (!(Test-Path $StageFile)) {
    # FASE 0: Início Real
    "1" | Out-File $StageFile
    Set-NetworkConfig
    Write-Log "Reinicie o servidor manualmente ou aguarde o próximo passo se a rede não for interrompida."
    Install-ADDSComponent
} else {
    $CurrentStage = Get-Content $StageFile
    if ($CurrentStage -eq "2") {
        # FASE 2: Pós-Reboot do AD
        Write-Log "A retomar a configuração após o reinício (Promoção AD concluída)."
        Configure-DHCPComponent
        Configure-FileServerComponent
        "COMPLETO" | Out-File $StageFile
        Write-Log "=== CONFIGURAÇÃO CONCLUÍDA COM SUCESSO ==="
        # Limpar RunOnce
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ResumeInfrastructureSetup" -ErrorAction SilentlyContinue
    }
}
