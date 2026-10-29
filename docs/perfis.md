# Perfis Prontos (Gamer / Escritório / Servidor)

[← Voltar ao README](../README.md) · [Funcionalidades](funcionalidades.md)

Em vez de passar item por item, um perfil escolhe de uma vez as otimizações
certas para o uso da máquina.

## Os três perfis

### 🎮 Gamer
Foco em **responsividade e FPS**:
- aparência leve;
- Máxima Performance completa (núcleos liberados, *core parking* off, turbo 100% e
  Alto Desempenho, que é **pulado sozinho em notebook** para não acabar com a
  bateria);
- prioridade para o app em foco;
- **HAGS**, se houver GPU dedicada;
- DNS Cloudflare.

**O Xbox continua ligado.**

### 💼 Escritório
Foco em **produtividade**, de forma conservadora:
- limpeza, serviços seguros e remoção de bloatware;
- menu de contexto clássico (Windows 11);
- **mantém o Teams**;
- **não mexe** em plano de energia nem em DNS, porque costuma ser rede corporativa.

### 🖥️ Servidor
Foco em **throughput e estabilidade**:
- mesma base segura do Escritório;
- prioridade para os **serviços em segundo plano** (em servidor não há "app em
  foco");
- núcleos e turbo liberados;
- sem os enfeites de interface.

## Como funciona em cada versão

| | Menu (terminal) | GUI (janela) |
|---|---|---|
| Onde fica | Categoria **P** | Botões roxos **Gamer / Escritório / Servidor** |
| O que faz | **Aplica** a lista do perfil com uma confirmação geral (mais o ponto de restauração), sem Y/N item a item | **Só marca** as caixinhas do perfil. Você revisa e clica em **Aplicar selecionados** |
| Base comum (limpeza, serviços seguros, bloatware) | Incluída | **Não** é marcada pelo botão: marque à parte se quiser |

Na GUI, o botão marca só os itens **exclusivos** daquele perfil para não esconder,
no meio de dezenas de caixinhas, o que realmente muda entre um perfil e outro.

> Nenhum perfil inclui a [limpeza avançada](funcionalidades.md#16-limpeza-avançada)
> nem o [relatório de hardware](relatorio-de-hardware.md): eles são ferramentas à
> parte, que você roda quando quiser.
