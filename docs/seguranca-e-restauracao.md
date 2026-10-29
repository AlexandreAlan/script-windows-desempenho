# Segurança e restauração

[← Voltar ao README](../README.md) · [Funcionalidades](funcionalidades.md)

## Princípios

- **Nada é aplicado sem confirmação.** No menu, cada item pede **Y/N**. Na GUI, só
  roda o que estiver marcado, e itens vermelhos pedem uma confirmação a mais.
- **Ponto de restauração antes.** As opções 9 (Máxima performance), 10 (Windows
  11), 12 (Aplicar tudo), 14 (Diagnóstico) e os perfis oferecem criar um ponto de
  restauração do Windows. A GUI tem o botão **Criar ponto de restauração**.
- **Backup do que pode ser desfeito.** Serviços, inicialização e ajustes de
  registro guardam o estado original antes de mudar.
- **Erros não quebram a tela.** Registro bloqueado por GPO, falta de permissão etc.
  viram um **aviso amarelo** e entram no relatório de auditoria.

## Onde ficam os backups

| Arquivo / chave | O que guarda | Usado por |
|---|---|---|
| `backup-servicos.json` (pasta do script) | Tipo de inicialização original de cada serviço desativado | Opção 13 e botão **Restaurar** da GUI |
| `HKCU\Software\OtimizadorBackup\Startup` | Programas tirados da inicialização | Opção 13 e botão **Restaurar** da GUI |
| `backup-registro.json` (pasta do script) | Valor antigo de cada ajuste de registro (ou que ele não existia) e as chaves criadas do zero | Opção 13 (só na versão de menu) |

Os backups são **compartilhados** entre as duas versões: dá para aplicar na GUI e
restaurar no menu, ou o contrário. Quando o script roda direto da web (`irm | iex`),
os arquivos `.json` vão para `%TEMP%`.

## O que é reversível

| Tipo de mudança | Desfeito pela opção 13? | Como desfazer |
|---|---|---|
| Serviços desativados | ✅ Sim (menu e GUI) | Opção 13 / botão Restaurar |
| Programas da inicialização | ✅ Sim (menu e GUI) | Opção 13 / botão Restaurar |
| Ajustes de registro **aplicados pelo menu** | ✅ Sim | Opção 13 |
| Ajustes de registro **aplicados pela GUI** | ❌ Ainda não | Ponto de restauração do Windows |
| Plano de energia / `powercfg` / `bcdedit` | ❌ Não | Ponto de restauração, ou Opções de Energia do Windows |
| DNS | ↩️ Pela própria opção 8 | Opção 8 → "3 = Voltar ao automático" |
| Apps removidos (bloatware) | ❌ Não | Reinstalar pela Microsoft Store |
| Limpeza (opções 2 e 16) | ❌ Não, os arquivos são apagados | Só apaga cache, temporários e logs que o Windows recria. Nenhum arquivo pessoal entra |
| SFC / DISM (opção 14) | ❌ Não, mexem em arquivos de sistema | Ponto de restauração |
| Relatório de hardware (15) | Nada para desfazer | Só lê informações |

## Respeito à Política de Grupo (GPO / Active Directory)

Serve tanto para **PC doméstico** quanto para **máquina corporativa**, com ou sem
**AD**:

- Se a máquina está **em domínio**, o script **não mexe na área `\Policies\`** do
  registro, que é território da GPO. Esses itens aparecem como **`[GPO]`** pulados
  no relatório.
- Mesmo fora de domínio, se um valor de política **já estiver definido** por um
  admin, ele é **respeitado**.
- Em PC doméstico, sem domínio e com a chave livre, o ajuste é aplicado
  normalmente.

O status **em domínio: SIM/NÃO** aparece no topo do menu, no relatório de auditoria
e no relatório de hardware.

> ⚠️ Não desative serviços essenciais às cegas. Cada item explica o impacto. Na
> dúvida, mantenha (**N**).
