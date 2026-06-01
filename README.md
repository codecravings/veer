# ⟁ VEER · Polarity

A one-thumb reaction-and-focus game for mobile. Fly forward forever; **tap to flip
your colour** and match every incoming bar. The colours arrive in *runs*, so you
have to read ahead and **hold the tap** when the colour repeats — that inhibition
is the real cognition.

## 🎮 How to play
- **Tap anywhere** to flip between the two polarities (cyan / amber).
- Match the colour of each bar to absorb it. A mismatch ends the run.
- Same colour twice in a row? **Don't tap.**
- Flip at the last instant for a bonus. Build a streak for a bigger multiplier.

## 🌀 Zones
The run escalates through announced zones that cycle and intensify forever:
`STEADY → RAPIDS → BLACKOUT → STORM`. In **BLACKOUT** the bars fade out as they
near you — you read from memory.

## 🏆 Modes & progression
- **Endless** — chase your best score.
- **Daily** — a seeded run that's the same for everyone that day.
- **Challenges** — 9 long-term goals with progress tracking.

## 🛠️ Tech
Built with Flutter. The game field is a single `CustomPainter` driven by a
`Ticker`; menus and HUD are widgets. Records persist via `shared_preferences`.

- `lib/veer_game.dart` — engine, generation, renderer
- `lib/challenges.dart` — records + challenge definitions
- `lib/main.dart` — app shell, screens, HUD

## ▶️ Run it
```
flutter pub get
flutter run --release
```
