**Nota:** Si aparece un error de política de ejecución, ejecute PowerShell como administrador y ejecute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Requisitos para SFTP

Para usar SFTP, necesita instalar el módulo Posh-SSH:

```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser
```
