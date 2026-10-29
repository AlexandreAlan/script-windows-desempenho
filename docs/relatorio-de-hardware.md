# Relatório de hardware (opção 15)

[← Voltar ao README](../README.md) · [Funcionalidades](funcionalidades.md)

Gera uma **página HTML** com o inventário completo do PC, pronta para mostrar,
imprimir ou salvar em PDF e entregar ao cliente. **Só lê informações**: nada é
alterado no computador.

- **Menu:** categoria **M**, opção **15**. Também roda no fim do "Aplicar tudo".
- **GUI:** botão azul **Relatório de hardware** na barra de cima. O relatório abre
  sozinho no navegador e os pontos de atenção aparecem no log da janela.

## Onde fica salvo

Na **Área de Trabalho** do usuário, como
`relatorio-hardware_<COMPUTADOR>_<data>_<hora>.html`. Se a Área de Trabalho não
existir (perfil redirecionado, por exemplo), o arquivo vai para a pasta do script.

Em notebooks, o Windows gera também o `relatorio-bateria_<COMPUTADOR>_<data>.html`
(`powercfg /batteryreport`), com o histórico de uso e de ciclos, e o relatório
principal tem um link para ele.

## O que entra

| Seção | Informações |
|---|---|
| **Pontos de atenção** | Resumo dos problemas encontrados, sempre no topo. |
| **Sistema** | Nome do PC, usuário, fabricante/modelo, domínio (AD), edição e build do Windows, data de instalação, tempo ligado e **status de ativação**. |
| **Placa-mãe e BIOS** | Fabricante/modelo da placa, versão e data da BIOS/UEFI, **número de série**. |
| **Processador** | Modelo, núcleos, threads, clock máximo e uso no momento. |
| **Memória RAM** | Cada pente: slot, capacidade, tipo (DDR3/4/5), velocidade, fabricante e modelo. Total instalado e **slots livres para upgrade**. |
| **Placa de vídeo** | Modelo, versão e data do driver, resolução e taxa de atualização. |
| **Discos físicos** | Modelo, tipo (SSD/HDD), conexão (NVMe/SATA/USB), tamanho, **saúde**, **temperatura**, **desgaste** (SSD) e **horas ligado**. |
| **Unidades** | Cada letra (C:, D:...) com tamanho, livre e % livre. |
| **Bateria** *(notebook)* | Carga atual, capacidade de fábrica × capacidade hoje e **saúde em %**. |
| **Rede** | Adaptadores físicos conectados: velocidade do link, MAC e IPv4. |
| **Drivers com problema** | Dispositivos com status *Error*, *Degraded* ou *Unknown* no Gerenciador de Dispositivos. |
| **Atualizações recentes** | As últimas 8 atualizações instaladas, com data. |

Temperatura, desgaste e horas ligado dependem de o disco e o driver informarem
esses dados. Quando não informam, a célula mostra `-`.

## Quando aparece um ponto de atenção

| Situação | Limite |
|---|---|
| Disco com saúde diferente de *Healthy* | qualquer *Warning*/*Unhealthy* |
| Disco quente | temperatura ≥ 60 °C |
| SSD perto do fim da vida útil | desgaste ≥ 80% |
| Pouco espaço numa unidade | < 10% livre (linha vermelha; entre 10% e 20%, amarela) |
| RAM esgotada no momento | < 10% livre |
| Pouca RAM instalada | < 8 GB |
| Bateria gasta | < 60% da capacidade original |
| Windows não ativado | status de licença diferente de "Ativado" |
| Driver com problema | 1 ou mais dispositivos com erro |
| Windows desatualizado | última atualização há mais de 60 dias |
| PC sem reiniciar | ligado há 14 dias ou mais |

No menu, os mesmos pontos aparecem na tela e vão para o
[relatório de auditoria](funcionalidades.md#relatório-de-auditoria) como `AVISO`.

## Privacidade

O relatório fica **só no seu PC**: nada é enviado para lugar nenhum. Ele contém
dados que identificam a máquina (nome, usuário, número de série, MAC, IP e os
últimos caracteres da chave do Windows). Antes de publicar o arquivo em algum lugar
público, confira o conteúdo.
