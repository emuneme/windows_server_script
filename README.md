# Windows Server Infrastructure Script

Este repositório contém um script PowerShell para a instalação e configuração automática dos serviços essenciais no Windows Server.

## Serviços Cobertos
- **ADDC (Active Directory Domain Controller)**: Promoção a novo Forest.
- **DNS**: Configuração automática integrada no AD.
- **DHCP**: Instalação, criação de Scope e autorização.
- **File Server**: Instalação de serviços de ficheiros e criação de partilhas.

## Como Executar
1. Abra o PowerShell como Administrador.
2. Execute o script: `.\Install-WindowsInfrastructure.ps1`
3. O servidor irá reiniciar durante o processo.

## Aviso
Certifique-se de que a interface de rede (NIC) está configurada corretamente no script antes de executar.
