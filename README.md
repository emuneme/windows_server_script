# Windows Server Infrastructure Script

Este repositório contém um script PowerShell para a instalação e configuração automática dos serviços essenciais no Windows Server.

## Serviços Cobertos
- **ADDC (Active Directory Domain Controller)**: Promoção a novo Forest (`aster.local`).
- **DNS**: Configuração automática integrada no AD.
- **DHCP**: Instalação, criação de Scope (`10.0.0.100-200`) e autorização.
- **File Server**: Instalação de serviços de ficheiros e criação de partilhas.
- **Gestão de Utilizadores**: Script para criação automática de OUs e importação massiva de utilizadores via CSV.

## Como Executar
### 1. Instalação da Infraestrutura
1. Abra o PowerShell como Administrador.
2. Execute o script: `.\Install-WindowsInfrastructure.ps1`
3. O servidor irá reiniciar durante o processo.

### 2. Gestão de Utilizadores
1. Garanta que o domínio já está configurado.
2. Edite o ficheiro `usuarios.csv` com os dados desejados.
3. Execute o script: `.\Manage-AdUsers.ps1`

## Aviso
Certifique-se de que a interface de rede (NIC) está configurada corretamente no script antes de executar.
