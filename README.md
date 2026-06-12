# Script Windows Desempenho

Otimizador interativo para **Windows 10** — deixa o sistema mais **leve e rápido**.
Cada otimização pergunta **Y (sim)** ou **N (não)** antes de aplicar, então você
tem controle total sobre o que muda.

## Arquivos

| Arquivo | Função |
|---|---|
| `Otimizar-Windows10.ps1` | Script principal (aparência, limpeza, inicialização) |
| `Otimizar-Windows10.bat` | Duplo-clique → abre o script já como **Administrador** |
| `Restaurar-Inicializacao.ps1` | Reverte os programas de inicialização que você desativou |
| `Otimizar-Servicos.ps1` | **Reduz processos/serviços** em segundo plano (modo leve) |
| `Otimizar-Servicos.bat` | Duplo-clique → abre o de serviços como **Administrador** |
| `Restaurar-Servicos.ps1` | Reverte os serviços desativados (lê o backup salvo) |

## Como usar

1. Baixe os arquivos para o seu PC com Windows 10.
2. Dê **duplo-clique em `Otimizar-Windows10.bat`** e aceite o aviso de
   Controle de Conta de Usuário (UAC).
3. Para cada item, digite **Y** para aplicar ou **N** para pular.

> Dica: o script oferece criar um **ponto de restauração** logo no início.
> Recomendado aceitar para poder desfazer tudo se precisar.

## O que ele faz (tudo opcional, item por item)

**Aparência / efeitos visuais**
- Ajustar para melhor desempenho (desliga efeitos visuais em massa)
- Desativar animações de janelas (minimizar/maximizar)
- Desativar transparência da barra de tarefas / menu Iniciar
- Desativar sombras e Aero Peek
- Mostrar só o contorno ao arrastar janelas
- Menus instantâneos (sem delay/fade)
- Desativar animações da barra de tarefas
- Desativar dicas, sugestões e propaganda do Windows
- Menu Iniciar sem animação

**Desempenho**
- Plano de energia em Alto Desempenho
- Reinicia o Explorer para aplicar as mudanças

**Limpeza**
- Limpa arquivos temporários (Temp / Prefetch / cache) e mostra os MB liberados
- Esvazia a Lixeira

**Inicialização (startup)**
- Lista cada programa que abre com o Windows e pergunta se quer desativar
- Tudo que for desativado fica salvo em backup e pode ser revertido com
  `Restaurar-Inicializacao.ps1`

## Reduzir processos/serviços (modo leve agressivo)

Para deixar o sistema com **o mínimo de processos rodando**, use o
`Otimizar-Servicos.bat`. Ele desativa serviços em segundo plano, sempre
mostrando **o que você perde** em cada um e perguntando **Y/N**. Os
serviços vêm organizados por nível de risco:

- **Grupo 1 — Seguros:** telemetria, SysMain/Superfetch, Fax, modo demo,
  registro remoto, relatório de erros, mapas, etc.
- **Grupo 2 — Xbox/Game Bar:** desative se não joga via Xbox.
- **Grupo 3 — Cuidado:** Spooler (impressão), Windows Search, teclado de
  toque, geolocalização — só desative se tem certeza que não usa.
- **Grupo 4 — Apps em segundo plano + telemetria** (via registro).

O estado original de cada serviço é salvo em `backup-servicos.json` e pode
ser revertido a qualquer momento com `Restaurar-Servicos.ps1`.

> ⚠️ Não desative serviços às cegas. Desligar o serviço errado pode quebrar
> recursos (impressão, som, rede). Por isso cada item explica o impacto.

## Requisitos

- Windows 10
- Executar como **Administrador** (o `.bat` já cuida disso)

## Aviso

As alterações mexem principalmente no perfil do usuário (`HKCU`) e são
reversíveis. Mesmo assim, aceite a criação do ponto de restauração no início
para ter uma camada extra de segurança.
