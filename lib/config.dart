/// URL dell'API. In sviluppo `http://localhost:3000`; in produzione si compila con
/// `--dart-define=API_URL=/api` (stessa origine, dietro nginx).
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
