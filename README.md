# Script Windows Desempenho

Otimizador interativo para **Windows 10** — deixa o sistema mais **leve e rápido**.
Cada otimização pergunta **Y (sim)** ou **N (não)** antes de aplicar, então você
tem controle total sobre o que muda.

## Arquivos

| Arquivo | Função |
|---|---|
| `Otimizar-Windows10.ps1` | Script principal de otimização |
| `Otimizar-Windows10.bat` | Duplo-clique → abre o script já como **Administrador** |
| `Restaurar-Inicializacao.ps1` | Reverte os programas de inicialização que você desativou |

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

## Requisitos

- Windows 10
- Executar como **Administrador** (o `.bat` já cuida disso)

## Aviso

As alterações mexem principalmente no perfil do usuário (`HKCU`) e são
reversíveis. Mesmo assim, aceite a criação do ponto de restauração no início
para ter uma camada extra de segurança.
