<#
.SYNOPSIS
    Script para criação de OUs e importação massiva de utilizadores a partir de um CSV.
    
.DESCRIPTION
    Este script lê um ficheiro CSV e cria utilizadores no Active Directory dentro de uma OU específica.
    
    Autor: Especialista Windows Server (Antigravity)
    Data: 20/03/2026
#>

# --- CONFIGURAÇÕES ---
$CSVPath = ".\usuarios.csv"
$DefaultOU = "OU=Utilizadores,DC=aster,DC=local" # Ajuste conforme o seu domínio
$DefaultPassword = ConvertTo-SecureString "TempP@ss2026!" -AsPlainText -Force

# Verificação do Módulo Active Directory
if (!(Get-Module -ListAvailable ActiveDirectory)) {
    Write-Error "O módulo Active Directory não está instalado."
    exit
}

# --- ETAPA 1: CRIAÇÃO DA OU ---
$OUPath = "OU=Utilizadores,DC=aster,DC=local"
if (!(Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'" -ErrorAction SilentlyContinue)) {
    Write-Host "Criando Unidade Organizativa: $OUPath" -ForegroundColor Cyan
    New-ADOrganizationalUnit -Name "Utilizadores" -Path "DC=aster,DC=local" -ProtectedFromAccidentalDeletion $false
}

# --- ETAPA 2: IMPORTAÇÃO DO CSV ---
if (Test-Path $CSVPath) {
    $Users = Import-Csv -Path $CSVPath -Delimiter ","
    
    foreach ($User in $Users) {
        Write-Host "Processando utilizador: $($User.SamAccountName)" -ForegroundColor Yellow
        
        try {
            $UserParams = @{
                Name                  = $User.Name
                GivenName             = $User.GivenName
                Surname               = $User.Surname
                SamAccountName        = $User.SamAccountName
                UserPrincipalName     = "$($User.SamAccountName)@aster.local"
                Path                  = $OUPath
                AccountPassword       = $DefaultPassword
                Enabled               = $true
                ChangePasswordAtLogon = $true
            }
            
            if (!(Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'" -ErrorAction SilentlyContinue)) {
                New-ADUser @UserParams
                Write-Host "Utilizador $($User.SamAccountName) criado com sucesso!" -ForegroundColor Green
            } else {
                Write-Warning "O utilizador $($User.SamAccountName) já existe."
            }
        } catch {
            Write-Error "Erro ao criar o utilizador $($User.SamAccountName): $($_.Exception.Message)"
        }
    }
} else {
    Write-Error "Ficheiro CSV não encontrado em $CSVPath"
}
