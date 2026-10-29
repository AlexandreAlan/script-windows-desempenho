# Funcionalidades — o que cada opção faz

[← Voltar ao README](../README.md)

As duas versões (gráfica e menu) têm as mesmas otimizações. Os números abaixo são
os da **versão de menu**. Na **GUI**, os mesmos itens aparecem agrupados por
categoria, com cor de risco:

| Cor | Significado |
|---|---|
| 🟢 Verde, **SEGURO** | Pode desativar tranquilo. |
| 🟡 Amarelo, **CUIDADO** | Só se você **não usa** aquele recurso. |
| 🔴 Vermelho, **RISCO** | Só desative se souber o que faz. |

## Navegação do menu

O menu de terminal é organizado em categorias. Os números das opções são sempre os
mesmos, só a navegação por cima muda:

```
A - Sistema e limpeza        (aparencia, limpeza, limpeza avancada, inicializacao, disco)
B - Servicos e privacidade   (servicos, tarefas agendadas, bloatware)
C - Performance e jogos      (maxima performance, ajustes Windows 11)
D - Rede                     (DNS, throttling)
P - PERFIS PRONTOS           (Gamer / Escritorio / Servidor)
M - Diagnostico e manutencao (diagnostico, relatorio de hardware, comparar, restaurar)
T - APLICAR TUDO (passa por todas as secoes)
0 - Sair
```

| Categoria | Opções |
|---|---|
| **A** Sistema e limpeza | [1](#1-aparência), [2](#2-limpeza), [16](#16-limpeza-avançada), [3](#3-inicialização), [7](#7-otimizar-disco) |
| **B** Serviços e privacidade | [4](#4-serviços), [5](#5-tarefas-agendadas), [6](#6-remover-apps-inúteis) |
| **C** Performance e jogos | [9](#9-máxima-performance), [10](#10-ajustes-do-windows-11) |
| **D** Rede | [8](#8-ajustes-de-rede) |
| **P** Perfis prontos | ver [perfis.md](perfis.md) |
| **M** Diagnóstico e manutenção | [14](#14-diagnóstico-e-saúde-do-sistema), [15](#15-relatório-de-hardware), [11](#11-medir-desempenho), [13](#13-restaurar) |
| **T** Aplicar tudo | [12](#12-aplicar-tudo) |

---

## 1) Aparência

Ajusta para **melhor desempenho**: sem animações de janela e da barra de tarefas,
sem transparência, sem sombras/Aero Peek, só o contorno ao arrastar janelas, menus
instantâneos e sem dicas/propaganda do Windows. Também oferece o plano de energia
**Alto Desempenho**, que vem recomendado em desktop e **não** em notebook, porque
reduz a bateria.

*Reversível* pela opção 13 (o registro tem backup). Para ver o efeito, reinicie o
Explorer (o próprio menu oferece).

## 2) Limpeza

Apaga arquivos temporários (`%TEMP%`, `Windows\Temp`, `Prefetch`, cache do
Internet Explorer/Edge legado), mostra quantos MB saíram e esvazia a Lixeira.
**Não toca nos seus arquivos.** Para liberar mais espaço, use a
[16](#16-limpeza-avançada).

## 3) Inicialização

Lista cada programa que abre com o Windows (chaves `Run` do usuário e da máquina)
e pergunta se quer desativar. O item desativado é guardado em
`HKCU\Software\OtimizadorBackup\Startup` e pode ser reativado pela opção 13.

## 4) Serviços

Reduz processos em segundo plano. Os serviços estão agrupados por risco e cada um
mostra **o que você perde**:

- **Seguros:** telemetria (DiagTrack), SysMain, Fax, modo demonstração de loja,
  registro remoto, relatório de erros, mapas offline, compartilhamento do Windows
  Media.
- **Xbox:** com **detecção adaptativa**. Se houver controle Xbox conectado, a
  desativação vem como "não recomendado"; se não houver, como "recomendado", sempre
  com o motivo.
- **Cuidado:** teclado de toque, telefone, geolocalização, **Spooler de impressão**
  (sempre "não recomendado") e Windows Search.
- **Apps em 2º plano + telemetria** (registro).

O tipo de inicialização original de cada serviço vai para `backup-servicos.json`
(opção 13).

## 5) Tarefas agendadas

Desativa tarefas conhecidas de coleta de dados e de compatibilidade (Compatibility
Appraiser, CEIP, Feedback, DiskDiagnostic, Windows Error Reporting).

## 6) Remover apps inúteis

Lista o *bloatware* que está **instalado** neste PC (Candy Crush e jogos da King,
3D Builder, Mixed Reality, Skype, notícias/clima do Bing, Clipchamp, apps de
streaming pré-instalados etc.) e pergunta um por um. Apps essenciais não entram na
lista. Um app removido pode ser reinstalado pela Microsoft Store.

## 7) Otimizar disco

Detecta o tipo de cada unidade fixa: no **HD** comum faz desfragmentação, no **SSD**
faz **TRIM** e nunca desfragmenta. Se o tipo for desconhecido, usa a otimização
padrão do Windows.

## 8) Ajustes de rede

- Troca o **DNS** para Cloudflare (1.1.1.1) ou Google (8.8.8.8), ou volta ao
  automático do provedor.
- Desativa o **network throttling** (limitação de rede em 2º plano).
- Limpa o cache de DNS.

## 9) Máxima performance

Solta o máximo da máquina **sem fixar a CPU em 100%**. O turbo fica liberado sob
carga e o *core parking* desligado, mas o clock continua baixando quando ocioso, então
um monitoramento (Zabbix, por exemplo) segue enxergando a carga real. Também:

- garante **todos os núcleos no boot** (via `bcdedit`; o msconfig só *limita*);
- prioridade para o app em foco;
- **Game DVR** desligado;
- **HAGS** (agendamento de GPU por hardware), que avisa se a GPU é dedicada ou só
  integrada;
- startup sem atraso artificial.

**Detecção adaptativa:** em **notebook**, os itens de CPU no máximo e Alto
Desempenho avisam que gastam bateria e não vêm recomendados. Antes de aplicar, a
opção oferece criar um **ponto de restauração**.

## 10) Ajustes do Windows 11

Só se aplica a Windows 11 (detectado pelo build ≥ 22000):
- **menu de contexto clássico** (igual ao do Windows 10);
- **widgets** fora da barra de tarefas;
- **Chat/Teams** fora da barra de tarefas.

No Windows 10, o menu avisa que não se aplica e a GUI nem mostra a categoria.

## 11) Medir desempenho

Mostra um comparativo **antes × depois** (RAM em uso, RAM livre, número de
processos e de serviços ativos), com setas indicando o que melhorou. O topo do menu
exibe esses números em tempo real. O ganho completo aparece depois de **reiniciar**.

## 12) Aplicar tudo

Cria um ponto de restauração, passa por todas as seções (inclusive a limpeza
avançada e os ajustes do Windows 11, quando for o caso), mostra a comparação de
desempenho e, no fim, gera o [relatório de hardware](#15-relatório-de-hardware) como
comprovante. Mesmo aqui, **cada item pergunta Y/N**.

## 13) Restaurar

Desfaz **serviços**, **inicialização** e **ajustes de registro** a partir dos
backups. Detalhes sobre o que é e o que não é reversível em
[seguranca-e-restauracao.md](seguranca-e-restauracao.md).

## 14) Diagnóstico e saúde do sistema

Serve para rodar **antes** de otimizar e saber se algum problema é da máquina, não
do script:

- perfil detectado (notebook/desktop, GPU, RAM, Xbox);
- espaço livre em cada disco e RAM livre, em verde, amarelo ou vermelho;
- **saúde física de cada disco** (S.M.A.R.T., via `Get-PhysicalDisk`);
- **`SFC /scannow`** (verifica e repara arquivos de sistema) e **`DISM
  /ScanHealth` + `/RestoreHealth`** (verifica e repara a imagem do Windows).

Cada verificação pergunta antes, porque pode demorar alguns minutos.

## 15) Relatório de hardware

Gera uma **página HTML** na Área de Trabalho com o inventário completo do PC e um
bloco de **pontos de atenção** no topo. Só lê informações. Na GUI, é o botão azul
**Relatório de hardware**.

→ O que entra no relatório e quando ele dá alerta: [relatorio-de-hardware.md](relatorio-de-hardware.md)

## 16) Limpeza avançada

Vai além da opção 2 e mostra quanto espaço **realmente** saiu (arquivo em uso que não
pode ser apagado não conta):

| Item | O que apaga | Você perde |
|---|---|---|
| Cache do Windows Update | `SoftwareDistribution\Download` (para/reinicia `wuauserv` e `bits`) | Nada: o Windows baixa de novo se precisar. |
| Miniaturas e Otimização de Entrega | `thumbcache_*.db`, `iconcache_*.db` e o cache de Delivery Optimization | Nada: as miniaturas são recriadas ao abrir a pasta. |
| Relatórios de erro, dumps e logs antigos | WER (`ReportArchive`/`ReportQueue`), `CrashDumps`, `Minidump`, `MEMORY.DMP`, `LiveKernelReports\*.dmp` e logs de `Windows\Logs` com **mais de 30 dias** | Os arquivos para investigar telas azuis **antigas**. Os logs recentes ficam. |
| Cache dos navegadores | `Cache`, `Code Cache` e `GPUCache` de cada perfil do Chrome, Edge e Brave; `cache2` e `startupCache` do Firefox | Nada importante: **histórico, senhas, cookies, favoritos e abas ficam**. Navegador aberto é pulado, então feche antes. |
| Componentes do Windows | `DISM /Online /Cleanup-Image /StartComponentCleanup` (WinSxS) | Nada. **Sem `/ResetBase`**, então as atualizações instaladas continuam podendo ser desinstaladas. Pode demorar vários minutos. |
| Maiores arquivos | **Não apaga nada.** Lista os 15 maiores arquivos acima de 100 MB da sua pasta de usuário (Desktop, Downloads, Documentos, Vídeos...) | Nada. Você decide o que fazer com eles. |

## Relatório de auditoria

Ao **sair** do menu (opção 0), o script grava `otimizador-log_<data>.txt` na Área de
Trabalho com tudo o que foi feito (aplicado, pulado, aviso, ignorado por GPO),
junto com data, máquina, usuário, sistema e status de domínio. Serve como
**comprovante de serviço** para manutenção de clientes.
