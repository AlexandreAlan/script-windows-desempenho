# Guia de desenvolvimento

[← Voltar ao README](../README.md)

Como o projeto está organizado e como adicionar uma otimização nova sem quebrar
nada.

## Estrutura

```
Otimizador-Total.ps1   versao de menu (terminal) - script unico, autossuficiente
Otimizador-Total.bat   abre o menu como admin
Otimizador-GUI.ps1     versao grafica (WPF) - script unico, autossuficiente
Otimizador-GUI.bat     abre a GUI como admin
docs/                  documentacao detalhada + print da GUI
Dockerfile, nginx.conf, docker-compose.yml   mirror auto-hospedado dos scripts
.github/workflows/     lint, print da GUI e publicacao da imagem Docker
```

Cada `.ps1` é **um arquivo só, sem dependências**. Isso permite rodar direto da web
(`irm ... | iex`) e copiar para um pendrive. Por isso alguns helpers (detecção de
perfil, backup de serviço, limpeza avançada, relatório de hardware) aparecem
**duplicados** nos dois scripts. Ao mudar um deles, mude o outro igual.

## Convenções

- **Sem acentos dentro dos `.ps1`.** O Windows PowerShell 5.1 lê arquivo sem BOM como
  ANSI, e acento vira lixo na tela. Na documentação (`.md`), acentos à vontade.
- **Compatível com Windows PowerShell 5.1**, que é o que vem no Windows: nada de
  operador ternário, `??` ou `ForEach-Object -Parallel`.
- **Nunca quebrar a tela com erro vermelho:** ações rodam dentro de `Item` (menu) ou
  `Run` do catálogo (GUI), que capturam a exceção e transformam em aviso + log.
  Dentro da ação, use `-ErrorAction Stop` quando a falha tiver que aparecer.
- **Registro sempre por `Definir-Registro`.** No menu, ele faz backup para a opção 13
  e respeita GPO (`\Policies\` em máquina de domínio).
- **Serviço sempre por `Desativar-Servico` (menu) / `Apl-Servico` (GUI)**, que
  salvam o tipo de inicialização original em `backup-servicos.json`.
- **Paridade:** toda otimização nova entra nas duas versões, com o mesmo texto de
  "o que você perde".

## Adicionando uma otimização

### Na versão de menu (`Otimizador-Total.ps1`)

Dentro da função `Secao-...` da área certa:

```powershell
Item "Desativar a coisa X" `
    "Perde: o recurso Y deixa de funcionar." {
    Definir-Registro "HKCU:\Software\...\Chave" "Valor" 0
}
```

`Item` mostra o título e a descrição, pergunta **Y/N**, roda o bloco, conta em
Aplicadas/Puladas e registra no log de auditoria.

Para uma **seção nova**: crie `function Secao-NomeNovo`, coloque uma entrada no
`Mostrar-Submenu` da categoria (`@{Num="17"; Rotulo="..."; Acao={ Secao-NomeNovo }}`),
atualize o comentário `.DESCRIPTION` no topo e, se fizer sentido, chame a seção em
`Aplicar-Tudo`.

### Na versão gráfica (`Otimizador-GUI.ps1`)

No catálogo:

```powershell
Add-Tweak "Categoria" "Desativar a coisa X" "O recurso Y deixa de funcionar" "Verde" $true {
    Definir-Registro "HKCU:\Software\...\Chave" "Valor" 0
    "ok"   # texto que aparece no log da janela
} @("Gamer")   # opcional: perfis que marcam este item
```

| Parâmetro | Valores |
|---|---|
| Risco | `"Verde"`, `"Amarelo"`, `"Vermelho"` (vermelho pede confirmação extra) |
| Rec | `$true` = vem marcado e entra em "Marcar recomendados" |
| Perfis | `"Gamer"`, `"Escritorio"`, `"Servidor"`: o botão do perfil marca o item |

Itens consecutivos com a mesma categoria ficam agrupados sob um cabeçalho.

## CI (GitHub Actions)

| Workflow | Quando roda | O que faz |
|---|---|---|
| `lint.yml` | push na `main`, PR | Parser do PowerShell (sintaxe) + **PSScriptAnalyzer** nos dois scripts. Falha em qualquer *Error*; *Warning* só aparece no log. |
| `screenshot.yml` | push que muda a GUI | Abre a GUI num Windows real, tira um print e publica como artefato. Para atualizar `docs/screenshot-gui.png`, baixe o artefato e faça commit. |
| `docker-publish.yml` | push na `main` | Constrói e publica a imagem do mirror em `ghcr.io`. |

Para validar localmente (no Windows ou com o `pwsh` instalado):

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path .\Otimizador-Total.ps1, .\Otimizador-GUI.ps1 -Severity Warning,Error -ExcludeRule PSAvoidUsingWriteHost
```

## Mirror Docker

A imagem `ghcr.io/alexandrealan/script-windows-desempenho` serve os quatro arquivos
(`.ps1` + `.bat`) por nginx, com listagem de diretório:

```bash
docker compose up -d   # sobe em http://localhost:8081
```

Para usar seu mirror no lugar do GitHub, troque o endereço no comando de uma linha
do README por `http://SEU-SERVIDOR:8081/Otimizador-Total.ps1`.

## Publicando uma versão

1. Atualize o [`CHANGELOG.md`](../CHANGELOG.md).
2. Faça commit na `main` e espere o **Lint** passar.
3. Crie a tag: `git tag v1.X.0 && git push --tags`.
