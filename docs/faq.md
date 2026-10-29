# Perguntas frequentes e solução de problemas

[← Voltar ao README](../README.md)

### O Windows mostrou "O Windows protegeu o computador" (SmartScreen)
Isso acontece com qualquer `.bat` baixado da internet que não tem assinatura
digital. Clique em **Mais informações → Executar assim mesmo**. Se preferir, abra o
`.ps1` num editor de texto antes e confira o que ele faz: o código é aberto.

### Aparece "a execução de scripts foi desabilitada neste sistema"
Use o `.bat`: ele já roda o PowerShell com `-ExecutionPolicy Bypass` só para aquela
execução, sem mudar a política do sistema. Rodando o `.ps1` na mão, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Otimizador-Total.ps1
```

### O antivírus reclamou do script
Ferramentas que mexem em serviços, registro e tarefas agendadas às vezes caem em
heurística de antivírus. O script não baixa nem executa nada de fora: todo o
código está no `.ps1`. Na dúvida, confira o arquivo ou rode a versão publicada aqui
no GitHub.

### Precisa ser Administrador?
Sim. Desativar serviços, mexer em `HKLM`, limpar o cache do Windows Update e rodar
SFC/DISM exigem admin. Os `.bat` pedem a elevação (UAC) sozinhos e a GUI se
autoeleva.

### Qual versão eu uso, a gráfica ou a de menu?
- **GUI:** para escolher visualmente, com cores de risco e perfis que só marcam as
  caixinhas.
- **Menu:** para atendimento ou uso remoto, quando você quer o relatório de auditoria
  ao sair, a restauração de **registro** (opção 13) ou os perfis aplicados direto.

As duas usam os mesmos backups.

### Rodei pelo `irm | iex` e não acho os backups
Sem arquivo `.ps1` em disco, os backups vão para `%TEMP%`. Para guardá-los junto do
script e usar a opção 13 depois com segurança, baixe o repositório e use o `.bat`.

### A janela da GUI "congelou"
Itens demorados (SFC, DISM, limpeza de componentes do Windows) rodam na mesma
thread da janela, então ela para de responder até terminar. A saída desses comandos
aparece na janela de console atrás da GUI. Espere a mensagem **CONCLUIDO** no log.

### A limpeza de navegadores disse "está aberto, feche e rode de novo"
O navegador trava os arquivos de cache enquanto está aberto. Feche **todas** as
janelas dele. O Edge costuma continuar rodando em segundo plano: desative em
*Configurações → Sistema → "Continuar executando extensões e aplicativos em segundo
plano"* ou encerre o `msedge.exe` pelo Gerenciador de Tarefas.

### O relatório de hardware mostra "-" na temperatura/desgaste do disco
Esses dados vêm do próprio disco via driver (`Get-StorageReliabilityCounter`).
Discos USB, alguns RAIDs e controladores antigos não informam. Não significa que o
disco tem problema: a coluna **Saúde** continua valendo.

### Funciona em Windows Server?
Os scripts foram pensados para Windows 10/11, mas a maior parte funciona em
Windows Server 2016+. O perfil **Servidor** existe justamente para isso. Itens que
não existem no Server (apps da Store, Xbox, widgets) aparecem como pulados ou nem
são listados.

### Desfiz tudo e algo continua diferente
Veja a tabela **O que é reversível** em
[seguranca-e-restauracao.md](seguranca-e-restauracao.md). Plano de energia, `bcdedit`
e apps removidos não voltam pela opção 13. Para esses, use o **ponto de
restauração** criado antes.
