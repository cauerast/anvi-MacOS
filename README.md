# anvi.

**English** · [Português (Brasil)](README.pt-BR.md)

<img src="Anvi/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Anvi’s icon" width="128" align="right">

**A calm, local flashcard app for the Mac.**

Anvi is a native macOS flashcard app with spaced repetition. Make decks, add cards with text and
images, and study a little every day. Anvi schedules each card with [FSRS-6](https://github.com/open-spaced-repetition),
the same family of algorithms used by modern Anki. Your data lives in plain JSON files on your Mac.
There is no account, no server and no subscription.

> **Status:** early version (0.1).

---

## Download

1. Download `Anvi-x.y.z.dmg` from the [**Releases**](../../releases) page.
2. Open the DMG and drag **Anvi** to **Applications**.
3. Open Anvi. The first time, macOS will say it cannot verify the developer, because Anvi is
   free software that isn’t notarized by Apple. To open it anyway:
   - Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to
     the message about Anvi, then confirm.
   - Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Anvi.app`

You only need to do this once.

**Requirements:** macOS 15 (Sequoia) or later, on Apple Silicon or Intel.

---

## Using Anvi

- **Today** shows what to study now, your streak and the last weeks of activity.
- **Decks** hold your cards. A deck can have any number of cards; cards can have **tags**, and
  every tag gets its own entry in the sidebar, so you can study a tag across all decks.
- **Cards** have a front and a back. Each side can have text with simple Markdown (`**bold**`,
  `*italic*`, `` `code` ``, `~~strike~~`, `[links](https://…)`) and an image. Drop an image
  file onto the card editor, click to choose one, or paste a screenshot.
- **Studying:** press **Space** to show the answer, then **1** Again, **2** Hard, **3** Good or
  **4** Easy. Each button shows when the card will come back. **⌘Z** undoes the last answer;
  **Esc** ends the session.
- **Daily limits** (Settings → Study): new cards and reviews per day, per deck. You can also
  change the desired retention used by FSRS.
- **Streak:** a day counts when you answer at least one card.

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New card | ⌘N |
| New deck | ⇧⌘N |
| Add card and start the next one (in the editor) | ⌘↩ |
| Study the selected deck, tag or everything | ⌘↩ |
| Show answer | Space |
| Again / Hard / Good / Easy | 1 / 2 / 3 / 4 |
| Undo last answer | ⌘Z |
| End session | Esc |
| Import deck | ⌘O |
| Export deck | ⇧⌘E |
| Settings | ⌘, |

---

## Your data

Everything is stored in one folder, by default `~/Library/Application Support/Anvi`:

```text
Anvi/
├── library.json        settings and daily activity (streak)
├── decks/<id>.json     one file per deck: cards, schedules and review history
├── media/              images used by cards
└── backups/<date>/     automatic daily copy of library.json and decks/ (last 7 days)
```

- **Settings → General → Show in Finder** opens the folder. **Change…** moves your library to
  another folder (or opens a library that is already there). A folder inside iCloud Drive or
  Dropbox lets you use the same library on another Mac. Open it on one Mac at a time, because
  Anvi does not merge changes made on two Macs at once.
- **Export Deck…** writes one self-contained `.json` file with the deck, its images and your
  progress. **Import Deck…** reads it back. If the deck already exists, cards are merged and the
  most recently changed copy of each card wins.
- You can write a deck by hand (or generate one) and import it. Only `front` and `back` are
  required:

```json
{
  "deck": {
    "name": "World Capitals",
    "cards": [
      { "front": "France", "back": "Paris", "tags": ["europe"] },
      { "front": "Japan", "back": "**Tokyo**" }
    ]
  }
}
```

Anything you leave out (ids, dates, progress) is filled in on import.

---

## Soon

- Share decks from a community catalog (a public repository of deck files).
- Statistics: retention, forecast of upcoming reviews.
- Card types beyond front/back (cloze, reversed cards), audio.
- An iPhone app!!!

---

## License

Anvi is free software, licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

Scheduling uses [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) (MIT License).

Made with calm by @cauerast
