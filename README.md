# Script Windows Desempenho

**Otimizador Total** para **Windows 10** — deixa o sistema o mais **leve e
rápido** possível. Disponível em **duas versões**: uma **gráfica (janela
bonita, recomendada)** e a clássica de **menu no terminal**. Tudo é
**reversível** e nada é aplicado sem você confirmar.

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

## Arquivos

| Arquivo | Função |
|---|---|
| `Otimizador-GUI.ps1` | **Versão gráfica** (janela WPF, recomendada) |
| `Otimizador-GUI.bat` | Duplo-clique → abre a **janela** como Administrador |
| `Otimizador-Total.ps1` | Versão de **menu no terminal** (clássica) |
| `Otimizador-Total.bat` | Duplo-clique → abre o **menu** como Administrador |

> Os backups (`backup-servicos.json` + registro) são **compartilhados** pelas
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
9 - Otimizar disco (HD/SSD automatico)
10 - Ajustes de rede (DNS rapido + throttling)
11 - Ver melhora de desempenho (antes x depois)
7 - APLICAR TUDO (passa por todas as secoes)
8 - RESTAURAR (desfazer servicos + inicializacao)
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

**9) Otimizar disco** — detecta se é HD ou SSD: desfragmenta HD comum e faz
TRIM (limpeza correta) no SSD, sem desfragmentar SSD à toa.

**10) Ajustes de rede** — troca o DNS por um mais rápido (Cloudflare 1.1.1.1 ou
Google 8.8.8.8, ou volta ao automático), desativa o "network throttling" e
limpa o cache de DNS.

**11) Medir desempenho** — mostra um comparativo **antes × depois** (RAM em
uso, RAM livre, número de processos e serviços ativos), com setas indicando o
que melhorou. O topo do menu também exibe esses números **em tempo real**.

**7) Aplicar tudo** — cria ponto de restauração, passa por todas as seções e
no final mostra automaticamente a comparação de desempenho.

**8) Restaurar** — desfaz serviços e inicialização usando os backups.

## Segurança

- Tudo pede **Y/N** — nada é aplicado sem você confirmar.
- A opção 7 oferece criar um **ponto de restauração** do Windows no início.
- Serviços e inicialização têm **backup** e podem ser revertidos (opção 8).

> ⚠️ Não desative serviços essenciais às cegas. Cada item explica o impacto;
> em caso de dúvida, mantenha (N).

## Requisitos

- Windows 10
- Executar como **Administrador** (o `.bat` já cuida disso)
