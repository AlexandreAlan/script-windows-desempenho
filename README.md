# Script Windows Desempenho

[![Lint PowerShell](https://github.com/AlexandreAlan/script-windows-desempenho/actions/workflows/lint.yml/badge.svg)](https://github.com/AlexandreAlan/script-windows-desempenho/actions/workflows/lint.yml)

**Otimizador Total** para **Windows 10 e 11** — deixa o sistema o mais **leve
e rápido** possível. Disponível em **duas versões**: uma **gráfica (janela
bonita, recomendada)** e a clássica de **menu no terminal**. Cada mudança
pergunta antes de aplicar, tudo é **reversível**, e a versão de menu detecta o
sistema automaticamente e libera os **ajustes do Windows 11** quando for o
caso.

## Versão gráfica (recomendada) 🖥️

Uma **janela** com tema escuro onde cada otimização aparece como um item
**colorido por risco**, indicando o que é bom desativar ou não:

- 🟢 **Verde — SEGURO:** pode desativar tranquilo (telemetria, SysMain, Fax…).
- 🟡 **Amarelo — CUIDADO:** só se você **não usar** aquele recurso (Xbox,
  geolocalização, teclado de toque…).
- 🔴 **Vermelho — RISCO:** só desative se souber o que faz (Spooler de
  impressão, Windows Search).

Marque os itens que quiser (os recomendados já vêm marcados), clique em
**Aplicar selecionados** e acompanhe o log. Tem botões para **marcar
recomendados**, **criar ponto de restauração**, **restaurar (desfazer)** e um
**painel de desempenho ao vivo** (RAM, processos, serviços) no topo.

> 👉 Dê **duplo-clique em `Otimizador-GUI.bat`** e aceite o aviso (UAC).

## ⚡ Rodar a versão de menu direto (sem baixar nada)

**Jeito mais rápido** para a versão de menu — abra o **PowerShell** (menu
Iniciar → digite *PowerShell*) e cole **uma linha**. Ela baixa o script pro
`%TEMP%` e abre **já como Administrador** (vai aparecer o aviso do UAC,
clique **Sim**):

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; $f="$env:TEMP\Otimizador-Total.ps1"; irm https://raw.githubusercontent.com/AlexandreAlan/script-windows-desempenho/main/Otimizador-Total.ps1 -OutFile $f; Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""
```

Se você **já estiver num PowerShell como Administrador**, dá pra rodar ainda mais
curto (sem abrir outra janela):

```powershell
irm https://raw.githubusercontent.com/AlexandreAlan/script-windows-desempenho/main/Otimizador-Total.ps1 | iex
```

> Não instala nada — o script roda na hora e os backups ficam no `%TEMP%`. Para
> guardar os backups junto do script (e reusar a opção **13 – Restaurar** depois),
> use o método clássico do `.bat` em **[Como usar](#como-usar)**.

## Arquivos

| Arquivo | Função |
|---|---|
| `Otimizador-GUI.ps1` | **Versão gráfica** (janela WPF, recomendada) |
| `Otimizador-GUI.bat` | Duplo-clique → abre a **janela** como Administrador |
| `Otimizador-Total.ps1` | Versão de **menu no terminal** (clássica) |
| `Otimizador-Total.bat` | Duplo-clique → abre o **menu** como Administrador |

> Os backups ficam em `backup-servicos.json` (serviços), no registro
> (inicialização) e em `backup-registro.json` (ajustes de registro) — usados
> pela opção **13 (Restaurar)** para desfazer. São **compartilhados** pelas
> duas versões — você pode aplicar na GUI e restaurar no menu, ou vice-versa.

## Como usar

**Versão gráfica:** duplo-clique em `Otimizador-GUI.bat`, aceite o UAC, marque
os itens e clique em **Aplicar selecionados**.

**Versão de menu:**

1. Dê **duplo-clique em `Otimizador-Total.bat`** e aceite o aviso (UAC).
2. Escolha uma opção do menu. Em cada item, digite **Y** ou **N**.

## Menu

```
1 - Aparencia / efeitos visuais
2 - Limpeza (temporarios + lixeira)
3 - Programas de inicializacao (startup)
4 - Servicos / processos em segundo plano
5 - Tarefas agendadas (telemetria)
6 - Remover apps inuteis (Candy Crush, etc.)
7 - Otimizar disco (HD/SSD automatico)
8 - Ajustes de rede (DNS rapido + throttling)
9 - Maxima performance (CPU + sistema, monitoring-safe)
10 - Ajustes do Windows 11 (menu classico, widgets, Teams)
11 - Ver melhora de desempenho (antes x depois)
12 - APLICAR TUDO (passa por todas as secoes)
13 - RESTAURAR (desfazer servicos + inicializacao + registro)
14 - Diagnostico e saude do sistema (disco/RAM + SFC/DISM)
0 - Sair
```

## O que cada seção faz

**1) Aparência** — melhor desempenho, sem animações, sem transparência, sem
sombras, menus instantâneos, plano de energia Alto Desempenho.

**2) Limpeza** — apaga Temp/Prefetch/cache (mostra os MB liberados) e esvazia
a Lixeira. Não toca nos seus arquivos.

**3) Inicialização** — lista cada programa que abre com o Windows e pergunta se
quer desativar. Salva backup para reverter.

**4) Serviços** — reduz processos em segundo plano, organizados por risco:
- **Seguros:** telemetria, SysMain, Fax, modo demo, registro remoto, etc.
- **Xbox:** desative se não joga via Xbox.
- **Cuidado:** Spooler (impressão), Windows Search, geolocalização.
- **Apps em 2º plano + telemetria** (registro).
Cada serviço mostra **o que você perde** e salva backup.

**5) Tarefas agendadas** — desativa tarefas conhecidas de coleta de dados e
compatibilidade.

**6) Remover apps inúteis** — lista bloatware instalado (Candy Crush, jogos
King, 3D Builder, etc.) e pergunta um por um. Apps essenciais não entram.

**7) Otimizar disco** — detecta se é HD ou SSD: desfragmenta HD comum e faz
TRIM (limpeza correta) no SSD, sem desfragmentar SSD à toa.

**8) Ajustes de rede** — troca o DNS por um mais rápido (Cloudflare 1.1.1.1 ou
Google 8.8.8.8, ou volta ao automático), desativa o "network throttling" e
limpa o cache de DNS.

**9) Máxima performance** — solta o máximo da máquina **sem fixar a CPU em 100%**:
libera o **turbo total sob carga** (max processor state 100%) e desliga o **core
parking**, mas **deixa o clock escalar pra baixo quando ocioso** — assim um
monitoramento (ex.: **Zabbix**) continua enxergando carga e gargalo reais. Garante
**todos os núcleos no boot** (o jeito certo, via `bcdedit` — o msconfig só *limita*)
e aplica ajustes de sistema reversíveis: prioridade pro app em foco, **Game DVR**
off, **HAGS** e startup sem atraso. Oferece **ponto de restauração** antes.

**10) Ajustes do Windows 11** — só aparece/aplica se o PC for Windows 11
(detecção automática pelo número do build). Oferece **ponto de restauração**
antes e inclui: **menu de contexto clássico** (igual ao Win10), **desativar os
widgets** da barra e **desativar o Chat/Teams** da barra. Em Windows 10, a opção
avisa que não se aplica.

**11) Medir desempenho** — mostra um comparativo **antes × depois** (RAM em
uso, RAM livre, número de processos e serviços ativos), com setas indicando o
que melhorou. O topo do menu também exibe esses números **em tempo real**.

**12) Aplicar tudo** — cria ponto de restauração, passa por todas as seções
(inclusive os ajustes do W11, quando for o caso) e no final mostra automaticamente
a comparação de desempenho.

**13) Restaurar** — desfaz **serviços**, **inicialização** e **ajustes de registro**
(aparência, throttling de rede, menu/widgets/Teams do W11) usando os backups. Ou
seja, dá pra reverter **tudo** que o script alterou.

**14) Diagnóstico e saúde do sistema** — roda **antes** de otimizar, pra saber se
algum problema é da máquina e não do script (útil como comprovante em atendimento a
cliente). Mostra **espaço livre em disco**, **RAM livre** e a **saúde física de cada
disco** (S.M.A.R.T., via `Get-PhysicalDisk` — Healthy/Warning/Unhealthy), e oferece
rodar **`SFC /scannow`** (verifica/repara arquivos de sistema) e **`DISM /ScanHealth`
+ `/RestoreHealth`** (verifica/repara a imagem do Windows, pode baixar arquivos via
Windows Update). Só lê informações e pergunta antes de cada verificação/reparo — pode
demorar alguns minutos, por isso **não entra sozinho** na opção 12 (só se você
confirmar cada passo).

### Relatório de auditoria

Ao **sair** (opção 0), o script gera um **`otimizador-log_<data>.txt` na Área de
Trabalho** listando tudo que foi feito (aplicado / pulado / com aviso), com data,
máquina, usuário e sistema. Serve como **comprovante de serviço** — útil pra quem
usa em manutenção de clientes.

## Segurança

- Tudo pede **Y/N** — nada é aplicado sem você confirmar.
- As opções 12 (Aplicar Tudo), 10 (Windows 11) e 9 (Máxima performance) oferecem
  criar um **ponto de restauração** do Windows no início.
- Serviços, inicialização **e ajustes de registro** têm **backup** e podem ser
  revertidos pela opção 13 — nada fica sem volta.
- Falhas (registro bloqueado por GPO, permissão, etc.) viram **aviso amarelo** e
  vão pro relatório — **não quebram a tela** com erro vermelho.
- Os reparos da opção 14 (**SFC** e **DISM /RestoreHealth**) mexem em **arquivos de
  sistema**, não em registro — por isso **não são desfeitos** pela opção 13. Por
  garantia, a opção 14 também oferece **ponto de restauração** antes.

### Respeita Política de Grupo (GPO / Active Directory)

Serve tanto pra **PC doméstico** quanto pra **máquina profissional** — com ou sem
**AD**. O script detecta se a máquina está **em domínio** e, nesse caso, **não mexe
na área de `\Policies\`** do registro (território da GPO): esses ajustes ficam a
cargo da Política de Grupo e aparecem como **`[GPO]`** pulados no relatório. Mesmo
fora de domínio, se um valor de política **já estiver definido** (admin/GPO no
controle), ele é **respeitado** e não é sobrescrito. Em PC doméstico, sem domínio e
com a chave livre, os ajustes são aplicados normalmente. O status (**em domínio:
SIM/NÃO**) também sai no relatório de auditoria.

> ⚠️ Não desative serviços essenciais às cegas. Cada item explica o impacto;
> em caso de dúvida, mantenha (N).

## Requisitos

- Windows 10 ou Windows 11
- Executar como **Administrador** (o `.bat` já cuida disso)

## Auto-hospedar (Docker)

Prefere servir os scripts do seu próprio servidor em vez de depender do
`raw.githubusercontent.com`? A imagem publicada em
`ghcr.io/alexandrealan/script-windows-desempenho` serve os quatro arquivos
(`.ps1` + `.bat`) via nginx:

```bash
docker compose up -d
```

Isso sobe um mirror em `http://localhost:8081` — ajuste a porta no
`docker-compose.yml` conforme necessário.

## Histórico de versões

- **v1.2.0** — versão **gráfica** agora detecta **Windows 10/11** automaticamente (título e
  subtítulo da janela mostram o sistema real, antes ficava fixo em "Windows 10") e ganhou as
  seções **Máxima Performance** e **Ajustes do Windows 11** (esta última só aparece na lista
  quando o PC realmente é Windows 11), alcançando paridade com a versão de menu nos itens de
  otimização. Ajustes de **registro** na GUI ainda não têm backup/restauração própria (diferente
  da versão de menu) — use o botão "Criar ponto de restauração" antes, ou a versão de menu se
  precisar de reversão garantida; isso deve ser corrigido numa próxima versão.
- **v1.1.0** — nova opção **14 (Diagnóstico e saúde do sistema)** nas duas versões:
  espaço em disco, RAM, saúde física do disco (S.M.A.R.T.) e verificação/reparo de
  arquivos de sistema (SFC + DISM). Recomendado rodar antes de otimizar.
- **v1.0.0** — primeira versão estável: menu de terminal completo (13 opções,
  restauração total) + versão gráfica (WPF), CI de lint (sintaxe +
  PSScriptAnalyzer) para as duas versões, e mirror Docker auto-hospedável.

## Licença

[MIT](LICENSE) — use, modifique e redistribua livremente.
