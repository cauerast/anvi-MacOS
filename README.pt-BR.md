# anvi.

[English](README.md) · **Português (Brasil)**

<img src="Anvi/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Ícone do Anvi" width="128" align="right">

**Um app de flashcards tranquilo e local para o Mac.**

O Anvi é um app nativo de flashcards para macOS com repetição espaçada. Crie decks, adicione
cards com texto e imagens e estude um pouco todo dia. O Anvi agenda cada card com o
[FSRS-6](https://github.com/open-spaced-repetition), a mesma família de algoritmos usada no Anki
moderno. Seus dados ficam em arquivos JSON simples no seu Mac. Não tem conta, servidor nem
assinatura.

> **Status:** versão inicial (0.1).

---

## Download

1. Baixe o `Anvi-x.y.z.dmg` na página de [**Releases**](../../releases).
2. Abra o DMG e arraste o **Anvi** para **Aplicativos**.
3. Abra o Anvi. Na primeira vez, o macOS vai dizer que não consegue verificar o desenvolvedor,
   porque o Anvi é software livre e não é notarizado pela Apple. Para abrir mesmo assim:
   - Vá em **Ajustes do Sistema → Privacidade e Segurança**, role para baixo e clique em
     **Abrir Mesmo Assim** ao lado da mensagem sobre o Anvi, depois confirme.
   - Ou, no Terminal: `xattr -dr com.apple.quarantine /Applications/Anvi.app`

Você só precisa fazer isso uma vez.

**Requisitos:** macOS 15 (Sequoia) ou mais recente, em Apple Silicon ou Intel.

---

## Usando o Anvi

- **Hoje** mostra o que estudar agora, sua sequência de dias e as últimas semanas de atividade.
- **Decks** guardam seus cards. Um deck pode ter quantos cards você quiser. Cards podem ter
  **tags**, e cada tag ganha um item na barra lateral, para você estudar uma tag em todos os decks.
- **Cards** têm frente e verso. Cada lado pode ter texto com Markdown simples (`**negrito**`,
  `*itálico*`, `` `código` ``, `~~riscado~~`, `[links](https://…)`) e uma imagem. Arraste um
  arquivo de imagem para o editor, clique para escolher um ou cole um print.
- **Estudando:** aperte **Espaço** para ver a resposta, depois **1** Errei, **2** Difícil,
  **3** Bom ou **4** Fácil. Cada botão mostra quando o card vai voltar. **⌘Z** desfaz a última
  resposta; **Esc** encerra a sessão.
- **Limites diários** (Ajustes → Estudar): cards novos e revisões por dia, por deck. Você também
  pode mudar a retenção desejada usada pelo FSRS.
- **Sequência:** um dia conta quando você responde pelo menos um card.

### Atalhos de teclado

| Ação | Atalho |
| --- | --- |
| Novo card | ⌘N |
| Novo deck | ⇧⌘N |
| Adicionar card e começar o próximo (no editor) | ⌘↩ |
| Estudar o deck, a tag selecionada ou tudo | ⌘↩ |
| Mostrar resposta | Espaço |
| Errei / Difícil / Bom / Fácil | 1 / 2 / 3 / 4 |
| Desfazer última resposta | ⌘Z |
| Encerrar sessão | Esc |
| Importar deck | ⌘O |
| Exportar deck | ⇧⌘E |
| Ajustes | ⌘, |

---

## Seus dados

Tudo fica em uma pasta, por padrão `~/Library/Application Support/Anvi`:

```text
Anvi/
├── library.json        ajustes e atividade diária (sequência)
├── decks/<id>.json     um arquivo por deck: cards, agendamento e histórico de revisões
├── media/              imagens usadas nos cards
└── backups/<data>/     cópia diária automática do library.json e de decks/ (últimos 7 dias)
```

- **Ajustes → Geral → Mostrar no Finder** abre a pasta. **Alterar…** move sua biblioteca para
  outra pasta (ou abre uma biblioteca que já esteja lá). Uma pasta dentro do iCloud Drive ou do
  Dropbox permite usar a mesma biblioteca em outro Mac. Abra em um Mac por vez, porque o Anvi não
  junta alterações feitas em dois Macs ao mesmo tempo.
- **Exportar deck…** grava um único arquivo `.json` com o deck, as imagens e o seu progresso.
  **Importar deck…** lê esse arquivo de volta. Se o deck já existir, os cards são mesclados e
  vale a cópia alterada mais recentemente de cada card.
- Você pode escrever um deck à mão (ou gerar um) e importá-lo. Só `front` e `back` são
  obrigatórios:

```json
{
  "deck": {
    "name": "Capitais do Mundo",
    "cards": [
      { "front": "França", "back": "Paris", "tags": ["europa"] },
      { "front": "Japão", "back": "**Tóquio**" }
    ]
  }
}
```

O que você deixar de fora (ids, datas, progresso) é preenchido na importação.

---

## Em breve

- Compartilhar decks por um catálogo da comunidade (um repositório público de arquivos de deck).
- Estatísticas: retenção e previsão das próximas revisões.
- Tipos de card além de frente/verso (lacunas, cards invertidos) e áudio.
- Um app para iPhone!!!

---

## Licença

O Anvi é software livre, licenciado sob a **GNU General Public License v3.0**. Veja o [LICENSE](LICENSE).

O agendamento usa o [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) (licença MIT).

Feito com calma por @cauerast
