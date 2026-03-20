<#
.SYNOPSIS
    Script de instalação automática para infraestrutura Windows Server (ADDC, DNS, DHCP e File Server).
    
.DESCRIPTION
    Este script automatiza a configuração de um novo servidor Windows, incluindo promoção a Controlador de Domínio,
    configuração de DNS, instalação de DHCP e serviços de ficheiros.
    
    Autor: Especialista Windows Server (Antigravity)
    Data: 20/03/2026
#>

# --- CONFIGURAÇÕES DO AMBIENTE (ALTERAR CONFORME NECESSÁRIO) ---
$DomainName = "aster.local"
$NetbiosName = "ASTER"
$SafeModePassword = ConvertTo-SecureString "1V@neus@." -AsPlainText -Force
$IPAddress = "10.0.0.1"
$SubnetMask = "255.255.255.0"
$Gateway = "10.0.0.1" # Geralmente o próprio DC se for o Gateway, ou ajustar conforme rede
$DNSServer = "127.0.0.1"
$InterfaceAlias = "Ethernet0" # Verifique o nome da sua interface com Get-NetAdapter

# --- ETAPA 1: CONFIGURAÇÃO DE REDE E HOSTNAME ---
Write-Host "Configurando rede e nome do servidor..." -ForegroundColor Cyan
try {
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServer
    Rename-Computer -NewName "DC01" -Restart -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Algumas configurações de rede já podem estar presentes ou requerem execução manual."
}

# --- ETAPA 2: INSTALAÇÃO DO ADDS E DNS ---
Write-Host "Instalando ADDS e DNS..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promoção a Controlador de Domínio (Novo Forest)
# NOTA: O servidor reiniciará após esta etapa. O script deve ser continuado após o reboot.
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -SafeModeAdministratorPassword $SafeModePassword `
    -InstallDns:$true `
    -Force:$true `
    -NoRebootOnCompletion:$false

# --- ETAPA 3: CONFIGURAÇÃO DO DHCP (EXECUTAR APÓS REBOOT) ---
# Se o script for executado novamente após o reboot, estas etapas serão processadas.
if ((Get-WindowsFeature -Name DHCP).Installed) {
    Write-Host "Configurando DHCP Server..." -ForegroundColor Cyan
    Add-DhcpServerv4Scope -Name "Escopo Principal" -StartRange "10.0.0.100" -EndRange "10.0.0.200" -SubnetMask $SubnetMask
    Set-DhcpServerv4OptionValue -ScopeId 10.0.0.0 -DnsServer $IPAddress -Router $Gateway
    Add-DhcpServerInDC -DnsName "DC01.$DomainName" -IPAddress $IPAddress
} else {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
}

# --- ETAPA 4: FILE SERVER ---
Write-Host "Configurando File Server..." -ForegroundColor Cyan
Install-WindowsFeature -Name File-Services, FS-Resource-Manager -IncludeManagementTools

# Criação de estrutura de pastas e partilhas
$SharePath = "C:\Shares\Corporativo"
if (!(Test-Path $SharePath)) {
    New-Item -Path $SharePath -ItemType Directory
    New-SmbShare -Name "Corporativo" -Path $SharePath -FullAccess "Everyone"
}

Write-Host "Instalação concluída com sucesso!" -ForegroundColor Green
