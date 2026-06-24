# Script Windows Desempenho

[![Lint PowerShell](https://github.com/AlexandreAlan/script-windows-desempenho/actions/workflows/lint.yml/badge.svg)](https://github.com/AlexandreAlan/script-windows-desempenho/actions/workflows/lint.yml)

**Otimizador Total** para **Windows 10 e 11** — tudo em um único script, com menu,
para deixar o sistema o mais **leve e rápido** possível. Cada mudança pergunta
**Y (sim)** ou **N (não)** antes de aplicar, e tudo é **reversível**. Detecta o
sistema automaticamente e libera os **ajustes do Windows 11** quando for o caso.

## ⚡ Rodar direto (sem baixar nada)

**Jeito mais rápido** — abra o **PowerShell** (menu Iniciar → digite *PowerShell*)
e cole **uma linha**. Ela baixa o script pro `%TEMP%` e abre **já como Administrador**
(vai aparecer o aviso do UAC, clique **Sim**):

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; $f="$env:TEMP\Otimizador-Total.ps1"; irm https://raw.githubusercontent.com/AlexandreAlan/script-windows-desempenho/main/Otimizador-Total.ps1 -OutFile $f; Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""
```

Se você **já estiver num PowerShell como Administrador**, dá pra rodar ainda mais
curto (sem abrir outra janela):

```powershell
irm https://raw.githubusercontent.com/AlexandreAlan/script-windows-desempenho/main/Otimizador-Total.ps1 | iex
```

> Não instala nada — o script roda na hora e os backups ficam no `%TEMP%`. Para
> guardar os backups junto do script (e reusar a opção **12 – Restaurar** depois),
> use o método clássico do `.bat` em **[Como usar](#como-usar)**.

## Arquivos

| Arquivo | Função |
|---|---|
| `Otimizador-Total.ps1` | **O script completo** (menu com tudo) |
| `Otimizador-Total.bat` | Duplo-clique → abre já como **Administrador** |

> Os backups ficam em `backup-servicos.json` (serviços), no registro
> (inicialização) e em `backup-registro.json` (ajustes de registro) — todos
> usados pela opção **12 (Restaurar)** para desfazer.

## Como usar

1. Baixe `Otimizador-Total.ps1` e `Otimizador-Total.bat` para o seu PC.
2. Dê **duplo-clique em `Otimizador-Total.bat`** e aceite o aviso (UAC).
3. Escolha uma opção do menu. Em cada item, digite **Y** ou **N**.

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
