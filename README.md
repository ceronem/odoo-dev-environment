# Ambiente di Sviluppo Odoo

Questo progetto fornisce un ambiente di sviluppo completo e automatizzato per Odoo, con configurazione automatica di Python, PostgreSQL e tutte le dipendenze necessarie.

## Caratteristiche

- ✅ **Setup automatico completo**: Python 3.12, pyenv, PostgreSQL, pgAdmin
- ✅ **Zero configurazione manuale**: tutto viene configurato automaticamente
- ✅ **Docker Compose integrato**: PostgreSQL e pgAdmin containerizzati
- ✅ **Gestione dipendenze moderna**: Poetry per le dipendenze di sviluppo
- ✅ **Multiple opzioni di avvio**: demo mode, fresh database, verbose output
- ✅ **Cross-platform**: supporta Linux, macOS, WSL

## Requisiti

- **Docker** e **Docker Compose**
- **Git**
- **Bash** (per lo script di avvio)

Tutto il resto (Python, pyenv, dipendenze) viene installato automaticamente.

## Quick Start

1. **Clone del repository**:
   ```bash
   git clone <repository-url>
   cd odoo
   ```

2. **Avvio dell'ambiente**:
   ```bash
   ./start.sh
   ```

3. **Accesso all'applicazione**:
   - Odoo: http://localhost:8069
   - pgAdmin: http://localhost:8081

## Script di Avvio (start.sh)

Lo script `start.sh` automatizza completamente la configurazione dell'ambiente di sviluppo.

### Opzioni Disponibili

```bash
./start.sh [OPZIONI]
```

| Opzione | Descrizione |
|---------|-------------|
| `-v, --verbose` | Output dettagliato di tutte le operazioni |
| `--skip-deps` | Salta l'installazione delle dipendenze |
| `--demo` | Avvia Odoo con dati demo |
| `--fresh-db` | Inizializza un database completamente nuovo |
| `--force` | Salta tutte le conferme interattive |
| `--no-browser` | Non apre automaticamente il browser |
| `--pg-timeout N` | Timeout per PostgreSQL in secondi (default: 60) |
| `-h, --help` | Mostra l'aiuto |

### Esempi di Utilizzo

```bash
# Avvio standard
./start.sh

# Avvio con dati demo e output verbose
./start.sh --demo --verbose

# Reset completo del database
./start.sh --fresh-db

# Avvio rapido senza dipendenze (se già installate)
./start.sh --skip-deps --no-browser
```

### Funzionalità dello Script

#### 1. **Gestione Python e pyenv**
- Installa automaticamente pyenv se non presente
- Configura Python 3.12.2 come versione del progetto
- Aggiunge pyenv al `.bashrc` per caricamento automatico
- Verifica l'integrità dell'installazione Python

#### 2. **Controllo Dipendenze di Sistema**
- Verifica presenza di `wkhtmltopdf` (necessario per i PDF di Odoo)
- Controlla Docker Compose
- Valida la configurazione dell'ambiente

#### 3. **Gestione Database**
- Avvia PostgreSQL tramite Docker Compose
- Attende che il database sia pronto con timeout configurabile
- Supporta reset completo del database con `--fresh-db`
- Gestisce pgAdmin per amministrazione database

#### 4. **Setup Ambiente Python**
- Crea e attiva virtual environment automaticamente
- Installa dipendenze runtime di Odoo
- Configura Poetry per dipendenze di sviluppo
- Cache intelligente per evitare reinstallazioni

#### 5. **Configurazione Odoo**
- Clone automatico del repository Odoo (versione 17.0)
- Configurazione parametri database e porta HTTP
- Supporto per file di configurazione `odoo.conf`
- Gestione addons personalizzati in `../modules`

#### 6. **Avvio Intelligente**
- Termina processi Odoo esistenti
- Apertura automatica del browser
- Modalità verbose per debugging
- Gestione errori con messaggi informativi

## Configurazione

### Variabili d'Ambiente

Crea un file `.env` nella root del progetto per personalizzare la configurazione:

```env
# Database
DB_NAME=odoo_db
DB_USER=odoo
DB_PASSWORD=odoo
DB_HOST=localhost
DB_PORT=5432

# Odoo
ODOO_HTTP_PORT=8069
ODOO_VERSION=17.0

# pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=admin
```

### Struttura del Progetto

```
odoo/
├── start.sh              # Script di avvio principale
├── docker-compose.yml    # Configurazione PostgreSQL e pgAdmin
├── pyproject.toml        # Dipendenze Python e configurazione
├── .env                  # Variabili d'ambiente (opzionale)
├── odoo.conf            # Configurazione Odoo (opzionale)
├── .venv/               # Virtual environment (auto-generato)
├── odoo/                # Repository Odoo (auto-clonato)
└── modules/             # Directory per moduli personalizzati
```

## Sviluppo

### Aggiunta di Moduli Personalizzati

1. Crea i tuoi moduli nella directory `modules/`
2. Riavvia Odoo per caricare i nuovi moduli
3. I moduli saranno automaticamente riconosciuti da Odoo

### Debugging

**Setup VS Code Debug:**
1. Copia `.vscode/launch.json.example` in `.vscode/launch.json`
2. Personalizza le configurazioni se necessario

**Avvio con debug:**
```bash
./start.sh --debug
```

**Altre opzioni:**
- Usa `--verbose` per output dettagliato
- I log di Odoo sono visibili direttamente nel terminale
- pgAdmin è disponibile per gestire il database
- Breakpoint con `import pdb; pdb.set_trace()` nel codice Python

### Reset dell'Ambiente

```bash
# Reset completo del database
./start.sh --fresh-db

# Reinstallazione completa delle dipendenze
rm -rf .venv .requirements_installed
./start.sh
```

## Troubleshooting

### Problemi Comuni

**PostgreSQL non si avvia**:
```bash
docker-compose down
docker-compose up -d
```

**Errori di dipendenze Python**:
```bash
rm -rf .venv .requirements_installed
./start.sh
```

**Porta già in uso**:
- Cambia `ODOO_HTTP_PORT` nel file `.env`
- Oppure termina il processo esistente: `pkill -f odoo-bin`

**Timeout PostgreSQL**:
```bash
./start.sh --pg-timeout 120
```

## Licenza

MIT
