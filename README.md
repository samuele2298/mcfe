# mcfe — frontend Chess Mentor (Flutter web)

Specifica del progetto: [SPEC.md](https://github.com/samuele2298/mcbe/blob/main/SPEC.md).
Il backend è in [mcbe](https://github.com/samuele2298/mcbe).

## Sezioni

Home con piano del giorno · Puzzle (mix, tema, punti deboli, ripasso) · Storm · Gioca
(partita, allenamento, adattiva) · Aperture (esplora, repertorio, allenamento delle linee) ·
Partite (archivio, import Lichess/Chess.com, revisione con grafico ed errori) · Analisi
(motore + coach) · Statistiche (rating, punti deboli, nota del coach).

## Sviluppo

Requisiti: Flutter ≥ 3.35, backend `mcbe` in esecuzione su `http://localhost:3000`
(con `CORS_ORIGINS=http://localhost:8080` nel suo `.env`).

```bash
flutter pub get
flutter run -d chrome --web-port 8080
tool/build.sh && python3 tool/serve.py 8080   # build di prova, senza cache
flutter test
```

## Build di produzione

L'app gira dietro lo stesso nginx dell'API, che la espone sotto `/api`:

```bash
tool/build.sh /api
# copiare build/web/ nella root nginx (vedi mcbe/deploy/nginx.conf.example)
```

## Note tecniche

- La scacchiera è un widget proprio (`lib/widgets/board.dart`) con la logica del pacchetto
  `chess` (port di chess.js). Le librerie Lichess `chessground`/`dartchess` usano interi a
  64 bit e non compilano in JavaScript per il web.
- Pezzi: set *cburnett* di Colin M.L. Burnett (CC BY-SA 3.0), presi dagli asset di
  chessground/Lichess.
