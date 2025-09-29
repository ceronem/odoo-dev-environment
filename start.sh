#!/bin/bash
set -e

# --- Parse command line arguments ---
VERBOSE=false
SKIP_DEPS=false
DEMO_MODE=false
FRESH_DB=false
FORCE=false
NO_BROWSER=false
PG_TIMEOUT=60
DEBUG_MODE=false
DEBUG_WAIT=false
SKIP_MODULES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --skip-modules)
            SKIP_MODULES=true
            shift
            ;;
        --demo)
            DEMO_MODE=true
            shift
            ;;
        --fresh-db)
            FRESH_DB=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --no-browser)
            NO_BROWSER=true
            shift
            ;;
        --pg-timeout)
            PG_TIMEOUT="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --debug-wait)
            DEBUG_MODE=true
            DEBUG_WAIT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --verbose     Verbose output"
            echo "  --skip-deps       Skip dependency installation"
            echo "  --skip-modules    Skip module management (clone/update)"
            echo "  --demo           Enable demo mode"
            echo "  --fresh-db       Initialize fresh database (--init=all)"
            echo "  --force          Skip confirmation prompts"
            echo "  --no-browser     Don't open browser automatically"
            echo "  --pg-timeout N   PostgreSQL timeout in seconds (default: 60)"
            echo "  --debug          Enable debug mode (port 5678)"
            echo "  --debug-wait     Enable debug mode and wait for client"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Logging functions ---
log() {
    echo "🚀 $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "   $1"
    fi
}

log "Starting Odoo development environment..."

# --- Configurazione ---
PYTHON_VERSION=3.12.2
VENV_DIR=".venv"
ODOO_DIR="odoo"
ODOO_HTTP_PORT="${ODOO_HTTP_PORT:-8069}"
ODOO_VERSION="${ODOO_VERSION:-17.0}"
DB_NAME="${DB_NAME:-odoo_db}"
DB_USER="${DB_USER:-odoo}"
DB_PASSWORD="${DB_PASSWORD:-odoo}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# --- Funzioni di utilità ---
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Gestione moduli ---
function manage_modules() {
    local modules_file="modules.json"

    if [ ! -f "$modules_file" ]; then
        log_verbose "File modules.json non trovato, saltando gestione moduli"
        return 0
    fi

    log "Gestione moduli personalizzati..."

    # Assicurati che la directory modules esista
    mkdir -p modules

    # Controlla se jq è disponibile
    if ! command_exists jq; then
        echo "⚠️  jq non installato. Installo jq per gestire modules.json..."
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y jq >/dev/null 2>&1 || {
                echo "❌ Impossibile installare jq. Gestione moduli saltata."
                return 1
            }
        elif command_exists yum; then
            sudo yum install -y jq >/dev/null 2>&1
        elif command_exists pacman; then
            sudo pacman -S --noconfirm jq >/dev/null 2>&1
        elif command_exists brew; then
            brew install jq >/dev/null 2>&1
        else
            echo "❌ Non riesco a installare jq automaticamente. Installalo manualmente."
            return 1
        fi
    fi

    # Leggi configurazioni
    local auto_update=$(jq -r '.config.auto_update // true' "$modules_file")
    local skip_existing=$(jq -r '.config.skip_existing // false' "$modules_file")
    local clone_depth=$(jq -r '.config.clone_depth // 1' "$modules_file")

    # Processa ogni modulo
    local modules_count=$(jq '.modules | length' "$modules_file")
    log_verbose "Trovati $modules_count moduli configurati"

    for i in $(seq 0 $((modules_count - 1))); do
        local module_name=$(jq -r ".modules[$i].name" "$modules_file")
        local git_url=$(jq -r ".modules[$i].git_url" "$modules_file")
        local branch=$(jq -r ".modules[$i].branch // \"main\"" "$modules_file")
        local enabled=$(jq -r ".modules[$i].enabled // true" "$modules_file")
        local description=$(jq -r ".modules[$i].description // \"\"" "$modules_file")

        if [ "$enabled" != "true" ]; then
            log_verbose "Modulo $module_name disabilitato, saltato"
            continue
        fi

        local module_path="modules/$module_name"

        if [ -d "$module_path" ]; then
            if [ "$skip_existing" = "true" ]; then
                log_verbose "Modulo $module_name già presente, saltato"
                continue
            fi

            if [ "$auto_update" = "true" ]; then
                log_verbose "Aggiornamento modulo $module_name..."
                cd "$module_path"
                if git pull origin "$branch" >/dev/null 2>&1; then
                    log_verbose "✅ Modulo $module_name aggiornato"
                else
                    log_verbose "⚠️ Errore aggiornamento modulo $module_name"
                fi
                cd - >/dev/null
            else
                log_verbose "Modulo $module_name presente (aggiornamenti disabilitati)"
            fi
        else
            log_verbose "Clonazione modulo $module_name da $git_url..."
            if git clone --depth "$clone_depth" -b "$branch" "$git_url" "$module_path" >/dev/null 2>&1; then
                log_verbose "✅ Modulo $module_name clonato con successo"
                [ -n "$description" ] && log_verbose "   Descrizione: $description"
            else
                echo "❌ Errore clonazione modulo $module_name da $git_url"
                echo "   Verifica che il repository sia accessibile e che la chiave SSH sia configurata"
            fi
        fi
    done

    log_verbose "Gestione moduli completata"
}

# --- Check/install pyenv ---
INSTALL_PYENV=false

# Prima controlla se la directory esiste
if [ -d "$HOME/.pyenv" ]; then
    # Initialize pyenv temporaneamente
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
    eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

    # Ora testa se funziona
    if command_exists pyenv && pyenv versions >/dev/null 2>&1; then
        log_verbose "pyenv già installato e funzionante"
    else
        log "⚠️ pyenv presente ma danneggiato, lo ripristino..."
        INSTALL_PYENV=true
    fi
else
    log "pyenv non trovato. Installo pyenv..."
    INSTALL_PYENV=true
fi

if [ "$INSTALL_PYENV" = true ]; then
    log "Installazione di pyenv..."
    rm -rf ~/.pyenv
    if ! curl -sSL https://pyenv.run | bash; then
        echo "❌ Errore durante l'installazione di pyenv"
        echo "   Verifica la connessione internet e riprova"
        exit 1
    fi
    # Initialize pyenv dopo l'installazione
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# --- Aggiungi pyenv a ~/.bashrc se non già presente ---
BASHRC="$HOME/.bashrc"
PYENV_INIT_SNIPPET='
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"
'
if ! grep -q 'pyenv init' "$BASHRC"; then
    echo "🔧 Aggiungo pyenv a ~/.bashrc per caricarlo automaticamente"
    echo "$PYENV_INIT_SNIPPET" >> "$BASHRC"
    echo "ℹ️ Modifiche salvate in ~/.bashrc. Riavvia la shell o esegui: source ~/.bashrc"
fi

# --- Install Python if missing (robusto) ---
# Controlla se Python è già installato e funzionante
PYTHON_INSTALLED=false
if pyenv versions --bare 2>/dev/null | grep -qx "$PYTHON_VERSION"; then
    # Testa se la versione locale è già impostata correttamente
    if [ -f ".python-version" ] && [ "$(cat .python-version)" = "$PYTHON_VERSION" ]; then
        PYTHON_BIN=$(pyenv which python 2>/dev/null || echo "")
        if [ -x "$PYTHON_BIN" ] && $PYTHON_BIN --version >/dev/null 2>&1; then
            log_verbose "Python $PYTHON_VERSION già installato e configurato"
            PYTHON_INSTALLED=true
        fi
    fi
fi

if [ "$PYTHON_INSTALLED" = false ]; then
    # Controlla se la versione esiste in pyenv
    if ! pyenv versions --bare 2>/dev/null | grep -qx "$PYTHON_VERSION"; then
        log "Installazione Python $PYTHON_VERSION"
        if ! pyenv install $PYTHON_VERSION; then
            echo "❌ Errore durante l'installazione di Python $PYTHON_VERSION"
            echo "   Verifica che le dipendenze di sistema siano installate"
            exit 1
        fi
    fi

    # Imposta la versione locale
    if ! pyenv local $PYTHON_VERSION; then
        echo "❌ Errore nell'impostazione della versione Python locale"
        exit 1
    fi

    log_verbose "Python $PYTHON_VERSION configurato"
fi

# Verifica finale
PYTHON_BIN=$(pyenv which python)
if [ ! -x "$PYTHON_BIN" ]; then
    echo "❌ Python non trovato o non eseguibile: $PYTHON_BIN"
    exit 1
fi
log_verbose "Python attivo: $($PYTHON_BIN --version)"

# --- Check wkhtmltopdf ---
if [ "$SKIP_DEPS" = false ]; then
    if ! command_exists wkhtmltopdf; then
        echo "⚠️  ATTENZIONE: wkhtmltopdf non è installato!"
        echo "   I report PDF di Odoo non funzioneranno correttamente."
        echo "   Per installarlo:"
        echo "   Ubuntu/Debian: sudo apt-get install wkhtmltopdf"
        echo "   Arch: sudo pacman -S wkhtmltopdf"
        echo "   macOS: brew install wkhtmltopdf"
        echo "   Oppure compila dai sorgenti: https://github.com/wkhtmltopdf/packaging"
        echo ""
        if [ "$FORCE" = false ]; then
            read -p "Premi INVIO per continuare comunque..." -r
        fi
    else
        log_verbose "wkhtmltopdf già installato: $(wkhtmltopdf --version | head -1)"
    fi
else
    log_verbose "Saltando controllo wkhtmltopdf (--skip-deps)"
fi

# --- Start Docker Compose ---
log "Controllo servizi Docker Compose..."
if ! command_exists docker-compose; then
    echo "❌ docker-compose non trovato"
    echo "   Installa Docker Compose e riprova"
    exit 1
fi

if ! docker-compose ps | grep -q "Up"; then
    log_verbose "Avvio Docker Compose..."
    if ! docker-compose up -d; then
        echo "❌ Errore nell'avvio di Docker Compose"
        echo "   Verifica che Docker sia in esecuzione e che docker-compose.yml sia valido"
        exit 1
    fi
else
    log_verbose "Servizi Docker Compose già in esecuzione"
fi

# --- Wait for PostgreSQL with timeout ---
log "Attendo PostgreSQL (timeout: ${PG_TIMEOUT}s)..."
PG_WAIT_TIME=0
until docker-compose exec -T postgres pg_isready > /dev/null 2>&1; do
    if [ $PG_WAIT_TIME -ge $PG_TIMEOUT ]; then
        echo "❌ Timeout: PostgreSQL non risponde dopo ${PG_TIMEOUT} secondi"
        echo "   Verifica che Docker sia in esecuzione e che il servizio postgres sia configurato correttamente"
        exit 1
    fi
    log_verbose "PostgreSQL non pronto, attendo 2s... (${PG_WAIT_TIME}/${PG_TIMEOUT}s)"
    sleep 2
    PG_WAIT_TIME=$((PG_WAIT_TIME + 2))
done
log "PostgreSQL pronto!"

# --- Stop existing Odoo processes ---
echo "🛑 Stop processi Odoo esistenti..."
pkill -f "odoo-bin" || true

# --- Clone Odoo if needed ---
if [ ! -d "$ODOO_DIR" ]; then
    echo "📥 Clono repository Odoo..."
    git clone git@github.com:odoo/odoo -b $ODOO_VERSION --depth=1 $ODOO_DIR
else
    echo "📁 Cartella Odoo già esistente"
fi

# --- Manage custom modules ---
if [ "$SKIP_MODULES" = false ]; then
    manage_modules
else
    log_verbose "Saltando gestione moduli (--skip-modules)"
fi

# --- Load environment variables ---
if [ -f ".env" ]; then
    echo "🔧 Carico variabili d'ambiente..."
    set -o allexport
    source .env
    set +o allexport
fi

# --- Create virtual environment ---
if [ ! -d "$VENV_DIR" ]; then
    echo "🆕 Creo virtual environment..."
    $PYTHON_BIN -m venv $VENV_DIR
else
    echo "📁 Virtual environment già esistente"
fi

# --- Activate virtual environment ---
echo "🐍 Attivo virtual environment..."
source $VENV_DIR/bin/activate

# --- Install Odoo runtime requirements ---
REQUIREMENTS_MARKER=".requirements_installed"
if [ "$SKIP_DEPS" = false ] && [ -f "$ODOO_DIR/requirements.txt" ]; then
    # Controlla se i requirements sono già stati installati
    if [ ! -f "$REQUIREMENTS_MARKER" ] || [ "$ODOO_DIR/requirements.txt" -nt "$REQUIREMENTS_MARKER" ]; then
        log "Installo requirements runtime di Odoo..."
        pip install --upgrade pip --quiet
        pip install -r "$ODOO_DIR/requirements.txt" --quiet --upgrade
        touch "$REQUIREMENTS_MARKER"
    else
        log_verbose "Requirements Odoo già installati"
    fi
elif [ "$SKIP_DEPS" = true ]; then
    log_verbose "Saltando requirements Odoo (--skip-deps)"
elif [ ! -f "$ODOO_DIR/requirements.txt" ]; then
    log_verbose "File requirements.txt non trovato in $ODOO_DIR"
fi

# --- Install/Update Poetry ---
if ! command_exists poetry; then
    if [ "$SKIP_DEPS" = false ]; then
        log "Installo Poetry..."
        pip install poetry --quiet
    else
        log_verbose "Saltando installazione Poetry (--skip-deps)"
    fi
else
    POETRY_VERSION=$(poetry --version 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    log_verbose "Poetry già installato (versione: $POETRY_VERSION)"
fi

# --- Install development dependencies via Poetry ---
if [ "$SKIP_DEPS" = false ]; then
    if command_exists poetry && [ -f "pyproject.toml" ]; then
        log "Installo dipendenze dev via Poetry..."
        if ! poetry install --with dev --no-interaction --no-ansi --quiet 2>/dev/null; then
            log_verbose "⚠️ Poetry install fallito, continuo senza dipendenze dev"
        fi
    else
        log_verbose "Poetry o pyproject.toml non disponibile, saltando dipendenze dev"
    fi
else
    log_verbose "Saltando installazione dipendenze (--skip-deps)"
fi

# --- Build Odoo command using array to avoid quoting issues ---
ODOO_CMD=(
    python odoo-bin
    -d "$DB_NAME"
    -r "$DB_USER"
    -w "$DB_PASSWORD"
    --db_host "$DB_HOST"
    --db_port "$DB_PORT"
    --http-port "$ODOO_HTTP_PORT"
    -u all
    --addons-path ../modules
)

# Add config file if it exists
if [ -f "odoo.conf" ]; then
    ODOO_CMD+=(-c odoo.conf)
    log_verbose "Usando file configurazione odoo.conf"
else
    log_verbose "File odoo.conf non trovato, uso parametri da linea di comando"
fi

if [ "$DEMO_MODE" = true ]; then
    log "Modalità demo abilitata"
    ODOO_CMD+=(--with-demo)
fi

if [ "$DEBUG_MODE" = true ]; then
    # Installa debugpy se non presente
    pip show debugpy >/dev/null 2>&1 || pip install debugpy --quiet

    if [ "$DEBUG_WAIT" = true ]; then
        log "Modalità debug con attesa client abilitata (porta 5678)"
        echo "⏳ Odoo attenderà la connessione del debugger prima di avviarsi..."
        ODOO_CMD=(python -m debugpy --listen 0.0.0.0:5678 --wait-for-client "${ODOO_CMD[@]:1}")
    else
        log "Modalità debug abilitata (porta 5678)"
        echo "ℹ️  Puoi collegare il debugger in qualsiasi momento"
        ODOO_CMD=(python -m debugpy --listen 0.0.0.0:5678 "${ODOO_CMD[@]:1}")
    fi
fi

if [ "$FRESH_DB" = true ]; then
    if [ "$FORCE" = false ]; then
        echo ""
        echo "⚠️  ATTENZIONE: Stai per eliminare completamente il database '$DB_NAME'!"
        echo "   Tutti i dati esistenti andranno persi definitivamente."
        echo ""
        read -p "Sei sicuro di voler continuare? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Operazione annullata."
            exit 1
        fi
    else
        log_verbose "Saltando conferma (--force)"
    fi

    log "Eliminazione database esistente..."
    if docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" 2>/dev/null; then
        log_verbose "Database '$DB_NAME' eliminato"
    else
        log_verbose "Database '$DB_NAME' non esistente o già eliminato"
    fi

    if docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";" 2>/dev/null; then
        log_verbose "Database '$DB_NAME' ricreato"
    else
        echo "⚠️ Errore nella creazione del database. Continuo comunque..."
    fi

    log "Inizializzazione database fresh"
    # Replace -u all with --init=all for fresh database
    for i in "${!ODOO_CMD[@]}"; do
        if [[ "${ODOO_CMD[$i]}" == "-u" ]]; then
            ODOO_CMD[$i]="--init"
            break
        fi
    done
fi

# --- Start Odoo ---
log "Avvio server Odoo..."
cd $ODOO_DIR

if [ "$VERBOSE" = true ]; then
    echo "📍 Directory corrente: $(pwd)"
    echo "🐍 Python in uso: $PYTHON_BIN"
    echo "⚡ Comando Odoo: ${ODOO_CMD[*]}"
    echo ""
    echo "🚀 === OUTPUT SERVER ODOO ==="
fi

# Funzione per aprire il browser
open_browser() {
    local url="http://localhost:$ODOO_HTTP_PORT"
    log_verbose "Tentativo di aprire browser su $url"

    if command_exists xdg-open; then
        xdg-open "$url" &>/dev/null &
    elif command_exists gnome-open; then
        gnome-open "$url" &>/dev/null &
    elif command_exists open; then
        open "$url" &>/dev/null &
    else
        log_verbose "Browser non aperto automaticamente. URL: $url"
    fi
}

# Avvia il browser dopo un breve delay (in background)
if [ "$NO_BROWSER" = false ]; then
    (sleep 5 && open_browser) &
    log_verbose "Browser si aprirà automaticamente su http://localhost:$ODOO_HTTP_PORT"
else
    log_verbose "Apertura browser disabilitata. URL: http://localhost:$ODOO_HTTP_PORT"
fi

# Avvia Odoo con output completo
exec "${ODOO_CMD[@]}"
