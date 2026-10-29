# Histórico de versões

Todas as mudanças relevantes do **Otimizador Total**. O formato segue a ideia do
[Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as versões seguem
[SemVer](https://semver.org/lang/pt-BR/).

## [1.5.0] — 2026-10-29

### Adicionado
- **Relatório de hardware em HTML** (opção **15** no menu, botão **Relatório de
  hardware** na GUI). Gera uma página na Área de Trabalho com sistema e ativação do
  Windows, placa-mãe e BIOS (com número de série), processador, **RAM pente a pente**
  (slots livres para upgrade), placa de vídeo e driver, **discos físicos com saúde,
  temperatura, desgaste e horas ligado**, espaço livre por unidade, **bateria** (saúde
  em %, mais o `powercfg /batteryreport` oficial), rede, **drivers com problema** e
  atualizações recentes. No topo aparece um bloco de **pontos de atenção** (disco
  falhando, pouco espaço, Windows não ativado, bateria gasta etc.). A página pode ser
  impressa ou salva em PDF. Só lê informações, não altera nada.
  → [docs/relatorio-de-hardware.md](docs/relatorio-de-hardware.md)
- **Limpeza avançada** (opção **16** no menu, categoria **Limpeza avançada** na GUI):
  cache do Windows Update, cache da Otimização de Entrega e de miniaturas/ícones,
  relatórios de erro, dumps de memória e logs com mais de 30 dias, **cache dos
  navegadores** (Chrome, Edge, Brave e Firefox, sem tocar em histórico, senhas ou
  cookies), limpeza de componentes do Windows (`DISM /StartComponentCleanup`, **sem**
  `/ResetBase`) e uma **lista dos maiores arquivos** da pasta do usuário, que só mostra
  e não apaga nada. Cada item informa quanto espaço liberou de verdade.
- **"Aplicar tudo"** (opção T/12) agora inclui a limpeza avançada, item a item com
  Y/N, e gera o relatório de hardware no final como comprovante.
- Documentação reorganizada: o README ficou enxuto, os detalhes foram para a pasta
  [`docs/`](docs/) (funcionalidades, perfis, segurança/restauração, relatório, FAQ e
  guia de desenvolvimento) e este `CHANGELOG.md` passou a ser um arquivo separado.

## [1.4.0]

### Adicionado
- **Menu reorganizado em categorias** (Sistema, Serviços, Performance, Rede,
  Diagnóstico) na versão de terminal. As seções continuam as mesmas, só a navegação
  passou a ter dois níveis.
- **Perfis Prontos** (Gamer/Escritório/Servidor). Na versão de terminal, o perfil
  aplica de uma vez a lista certa de otimizações, sem perguntar item a item. Na versão
  **gráfica**, cada botão marca só as caixinhas **exclusivas** daquele perfil (a base
  comum de limpeza, serviços seguros e bloatware fica para marcar à parte) e você
  revisa antes de clicar em "Aplicar selecionados".
- Ajuste novo para servidor: prioridade para os serviços em 2º plano, em vez de para
  o app em foco.

## [1.3.0]

### Adicionado
- **Detecção adaptativa do perfil da máquina** nas duas versões: notebook x desktop
  (bateria/tipo de chassi), GPU dedicada x integrada e uso de Xbox (controle
  detectado). O script **recomenda, com o motivo, só o que faz sentido para aquele
  PC**. Isso afeta o grupo Xbox (seção 4) e os itens de CPU máximo, Alto Desempenho
  e HAGS (seção 9).

### Alterado
- O **Spooler de impressão** sempre aparece como "não recomendado", com ou sem
  detecção.

## [1.2.0]

### Adicionado
- A versão **gráfica** detecta **Windows 10/11** (título e subtítulo mostram o
  sistema real) e ganhou as seções **Máxima Performance** e **Ajustes do Windows 11**,
  esta última só quando o PC é Windows 11. Com isso, a GUI alcançou a versão de menu
  nos itens de otimização.

### Conhecido
- Na GUI, ajustes de **registro** ainda não têm backup próprio. Use o botão "Criar
  ponto de restauração" antes, ou a versão de menu, que reverte o registro pela
  opção 13.

## [1.1.0]

### Adicionado
- Opção **14 (Diagnóstico e saúde do sistema)** nas duas versões: espaço em disco,
  RAM, saúde física dos discos (S.M.A.R.T.) e verificação/reparo de arquivos de
  sistema (SFC + DISM).

## [1.0.0]

### Adicionado
- Primeira versão estável: menu de terminal completo (13 opções, restauração total),
  versão gráfica (WPF), CI de lint (parser + PSScriptAnalyzer) para as duas versões e
  mirror Docker auto-hospedável.

[1.5.0]: https://github.com/AlexandreAlan/script-windows-desempenho/compare/v1.2.0...main
[1.2.0]: https://github.com/AlexandreAlan/script-windows-desempenho/releases/tag/v1.2.0
[1.1.0]: https://github.com/AlexandreAlan/script-windows-desempenho/releases/tag/v1.1.0
[1.0.0]: https://github.com/AlexandreAlan/script-windows-desempenho/releases/tag/v1.0.0
