#!/bin/bash
set -e

# --- Logging functions ---
log() {
    echo "🐳 $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "   $1"
    fi
}

# --- Parse command line arguments ---
VERBOSE=false
MODULES_FILE="build-modules.json"
OUTPUT_DIR="docker-build"
DOCKERFILE_TEMPLATE="Dockerfile.template"
IMAGE_NAME="odoo-custom"
IMAGE_TAG=""
DO_BUILD=false
DO_PUSH=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--file)
            MODULES_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--template)
            DOCKERFILE_TEMPLATE="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --build)
            DO_BUILD=true
            shift
            ;;
        --push)
            DO_PUSH=true
            DO_BUILD=true  # Push implica build
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --verbose        Verbose output"
            echo "  -f, --file FILE      Modules JSON file (default: build-modules.json)"
            echo "  -o, --output DIR     Output directory (default: docker-build)"
            echo "  -t, --template FILE  Dockerfile template (default: Dockerfile.template)"
            echo "  -n, --name NAME      Image name (default: odoo-custom)"
            echo "  --tag TAG            Image tag (default: ODOO_VERSION from .env)"
            echo "  --build              Build Docker image after preparation"
            echo "  --push               Build and push Docker image to registry"
            echo "  --force              Overwrite existing output directory"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Load environment variables ---
if [ ! -f ".env" ]; then
    echo "❌ File .env non trovato"
    exit 1
fi

log "Carico variabili d'ambiente da .env..."
set -o allexport
source .env
set +o allexport

# Verifica che ODOO_VERSION sia definita
if [ -z "$ODOO_VERSION" ]; then
    echo "❌ ODOO_VERSION non definita nel file .env"
    exit 1
fi

log_verbose "Versione Odoo: $ODOO_VERSION"

# Default registry se non specificato
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
if [ -n "$DOCKER_REGISTRY" ]; then
    log_verbose "Registry Docker: $DOCKER_REGISTRY"
fi

# Default tag se non specificato
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="$ODOO_VERSION"
fi
log_verbose "Image tag: $IMAGE_TAG"

# --- Check modules file ---
if [ ! -f "$MODULES_FILE" ]; then
    echo "❌ File moduli non trovato: $MODULES_FILE"
    exit 1
fi

# --- Check jq ---
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq non installato. Installa jq per continuare."
    exit 1
fi

# --- Prepare output directory ---
if [ -d "$OUTPUT_DIR" ]; then
    if [ "$FORCE" = false ]; then
        echo "⚠️  Directory $OUTPUT_DIR già esistente."
        read -p "Sovrascrivere? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Operazione annullata."
            exit 1
        fi
    fi
    log_verbose "Rimuovo directory esistente..."
    rm -rf "$OUTPUT_DIR"
fi

log "Creo directory di build: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/addons"

# Lista dei moduli che verranno inclusi (per verifica finale)
INCLUDED_MODULES=()

# --- Process Odoo Enterprise and extra repos ---
log "Elaborazione addon ufficiali Odoo..."

# Check if odoo_addons section exists
if jq -e '.odoo_addons' "$MODULES_FILE" >/dev/null 2>&1; then
    # Process Enterprise
    enterprise_enabled=$(jq -r '.odoo_addons.enterprise.enabled // false' "$MODULES_FILE")

    if [ "$enterprise_enabled" = "true" ]; then
        enterprise_url=$(jq -r '.odoo_addons.enterprise.git_url' "$MODULES_FILE")
        enterprise_branch=$(jq -r '.odoo_addons.enterprise.branch // "18.0"' "$MODULES_FILE")

        log_verbose "Clonazione Odoo Enterprise..."

        if git clone --depth 1 -b "$enterprise_branch" "$enterprise_url" "$OUTPUT_DIR/.tmp_enterprise" >/dev/null 2>&1; then
            # Copia tutti i moduli enterprise
            cp -r "$OUTPUT_DIR/.tmp_enterprise"/* "$OUTPUT_DIR/addons/"
            rm -rf "$OUTPUT_DIR/.tmp_enterprise"

            # Conta moduli enterprise
            enterprise_count=$(find "$OUTPUT_DIR/addons" -mindepth 1 -maxdepth 1 -type d | wc -l)
            log_verbose "✅ $enterprise_count moduli Enterprise copiati"

            # Aggiungi alla lista
            for dir in "$OUTPUT_DIR/addons"/*; do
                if [ -d "$dir" ]; then
                    INCLUDED_MODULES+=("$(basename "$dir")")
                fi
            done
        else
            echo "❌ Errore clonazione Odoo Enterprise"
            exit 1
        fi
    else
        log_verbose "Odoo Enterprise disabilitato"
    fi

    # Process extra repos
    extra_repos_count=$(jq '.odoo_addons.extra_repos | length' "$MODULES_FILE" 2>/dev/null || echo "0")

    if [ "$extra_repos_count" -gt 0 ]; then
        log_verbose "Elaborazione $extra_repos_count repository aggiuntivi..."

        for i in $(seq 0 $((extra_repos_count - 1))); do
            repo_name=$(jq -r ".odoo_addons.extra_repos[$i].name" "$MODULES_FILE")
            repo_enabled=$(jq -r ".odoo_addons.extra_repos[$i].enabled // true" "$MODULES_FILE")

            if [ "$repo_enabled" != "true" ]; then
                log_verbose "Repository $repo_name disabilitato, saltato"
                continue
            fi

            repo_url=$(jq -r ".odoo_addons.extra_repos[$i].git_url" "$MODULES_FILE")
            repo_branch=$(jq -r ".odoo_addons.extra_repos[$i].branch // \"main\"" "$MODULES_FILE")
            subdirs=$(jq -r ".odoo_addons.extra_repos[$i].subdirs[]?" "$MODULES_FILE")

            log_verbose "Clonazione repository $repo_name..."

            if git clone --depth 1 -b "$repo_branch" "$repo_url" "$OUTPUT_DIR/.tmp_$repo_name" >/dev/null 2>&1; then
                if [ -n "$subdirs" ]; then
                    # Copia solo le sottodirectory specificate
                    while IFS= read -r subdir; do
                        if [ -d "$OUTPUT_DIR/.tmp_$repo_name/$subdir" ]; then
                            cp -r "$OUTPUT_DIR/.tmp_$repo_name/$subdir" "$OUTPUT_DIR/addons/"
                            log_verbose "✅ Modulo $subdir copiato da $repo_name"
                            INCLUDED_MODULES+=("$subdir")
                        else
                            echo "⚠️  Sottodirectory $subdir non trovata in $repo_name"
                        fi
                    done <<< "$subdirs"
                else
                    # Copia tutti i moduli dalla root
                    for dir in "$OUTPUT_DIR/.tmp_$repo_name"/*; do
                        if [ -d "$dir" ] && [ -f "$dir/__manifest__.py" -o -f "$dir/__openerp__.py" ]; then
                            module_name=$(basename "$dir")
                            cp -r "$dir" "$OUTPUT_DIR/addons/"
                            INCLUDED_MODULES+=("$module_name")
                        fi
                    done
                    log_verbose "✅ Moduli copiati da $repo_name"
                fi

                rm -rf "$OUTPUT_DIR/.tmp_$repo_name"
            else
                echo "❌ Errore clonazione repository $repo_name"
                exit 1
            fi
        done
    fi
else
    log_verbose "Nessun addon ufficiale Odoo configurato"
fi

# --- Process custom modules ---
log "Elaborazione moduli custom da $MODULES_FILE..."

modules_count=$(jq '.modules | length' "$MODULES_FILE")
log_verbose "Trovati $modules_count moduli custom"

for i in $(seq 0 $((modules_count - 1))); do
    module_name=$(jq -r ".modules[$i].name" "$MODULES_FILE")
    enabled=$(jq -r ".modules[$i].enabled // true" "$MODULES_FILE")

    if [ "$enabled" != "true" ]; then
        log_verbose "Modulo $module_name disabilitato, saltato"
        continue
    fi

    # Controlla se è git o path
    git_url=$(jq -r ".modules[$i].git_url // empty" "$MODULES_FILE")
    local_path=$(jq -r ".modules[$i].path // empty" "$MODULES_FILE")

    if [ -n "$git_url" ]; then
        # Clone da git
        branch=$(jq -r ".modules[$i].branch // \"main\"" "$MODULES_FILE")
        log_verbose "Clonazione modulo $module_name da git..."

        if ! git clone --depth 1 -b "$branch" "$git_url" "$OUTPUT_DIR/addons/$module_name" >/dev/null 2>&1; then
            echo "❌ Errore clonazione modulo $module_name"
            exit 1
        fi

        # Rimuovi .git per ridurre dimensione immagine
        rm -rf "$OUTPUT_DIR/addons/$module_name/.git"
        log_verbose "✅ Modulo $module_name clonato"
        INCLUDED_MODULES+=("$module_name")

    elif [ -n "$local_path" ]; then
        # Copia da path locale
        log_verbose "Copia modulo $module_name da $local_path..."

        if [ ! -d "$local_path" ]; then
            echo "❌ Path non trovato: $local_path"
            exit 1
        fi

        cp -r "$local_path" "$OUTPUT_DIR/addons/$module_name"

        # Rimuovi .git se presente
        rm -rf "$OUTPUT_DIR/addons/$module_name/.git"
        log_verbose "✅ Modulo $module_name copiato"
        INCLUDED_MODULES+=("$module_name")

    else
        echo "❌ Modulo $module_name: specificare git_url o path"
        exit 1
    fi
done

# Verifica che addons contenga solo i moduli processati
log_verbose "Verifica integrità directory addons..."
for dir in "$OUTPUT_DIR/addons"/*; do
    if [ -d "$dir" ]; then
        basename_dir=$(basename "$dir")
        if [[ ! " ${INCLUDED_MODULES[@]} " =~ " ${basename_dir} " ]]; then
            echo "⚠️  Modulo non previsto trovato in addons/: $basename_dir (rimuovo)"
            rm -rf "$dir"
        fi
    fi
done

# --- Create Dockerfile from template ---
log "Generazione Dockerfile da template..."

if [ ! -f "$DOCKERFILE_TEMPLATE" ]; then
    echo "❌ Template Dockerfile non trovato: $DOCKERFILE_TEMPLATE"
    exit 1
fi

# Sostituisci variabili nel template
sed "s/{{ODOO_VERSION}}/$ODOO_VERSION/g" "$DOCKERFILE_TEMPLATE" > "$OUTPUT_DIR/Dockerfile"

log_verbose "Dockerfile generato da $DOCKERFILE_TEMPLATE"


# --- Create modules_to_install.txt for standard modules ---
if jq -e '.odoo_standard_modules' "$MODULES_FILE" >/dev/null 2>&1; then
    standard_modules=$(jq -r '.odoo_standard_modules[]?' "$MODULES_FILE")

    if [ -n "$standard_modules" ]; then
        log "Generazione lista moduli standard da installare..."
        echo "$standard_modules" | tr '\n' ',' | sed 's/,$//' > "$OUTPUT_DIR/modules_to_install.txt"
        log_verbose "✅ modules_to_install.txt generato"
        log_verbose "Moduli standard: $(cat "$OUTPUT_DIR/modules_to_install.txt")"
    fi
fi

# --- Copy docker-entrypoint.sh if exists ---
if [ -f "docker-entrypoint.sh" ]; then
    log_verbose "Copia entrypoint personalizzato..."
    cp docker-entrypoint.sh "$OUTPUT_DIR/docker-entrypoint.sh"
fi

# --- Create .dockerignore ---
cat > "$OUTPUT_DIR/.dockerignore" <<EOF
.git
.gitignore
__pycache__
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info
dist
build
.venv
venv
EOF

log_verbose ".dockerignore creato"

# --- Create build script ---
cat > "$OUTPUT_DIR/build.sh" <<EOF
#!/bin/bash
set -e

IMAGE_NAME="\${1:-odoo-custom}"
IMAGE_TAG="\${2:-$IMAGE_TAG}"
REGISTRY="${DOCKER_REGISTRY}"

if [ -n "\$REGISTRY" ]; then
    FULL_IMAGE="\$REGISTRY/\$IMAGE_NAME:\$IMAGE_TAG"
else
    FULL_IMAGE="\$IMAGE_NAME:\$IMAGE_TAG"
fi

echo "🐳 Building Docker image: \$FULL_IMAGE"
docker build -t "\$FULL_IMAGE" .

echo "✅ Build completato!"
echo ""
if [ -n "\$REGISTRY" ]; then
    echo "Per pushare l'immagine:"
    echo "  docker push \$FULL_IMAGE"
else
    echo "Immagine locale: \$FULL_IMAGE"
    echo "Per pushare, definisci DOCKER_REGISTRY nel .env"
fi
EOF

chmod +x "$OUTPUT_DIR/build.sh"

log_verbose "Script build.sh creato"

# --- Summary ---
echo ""
log "✅ Build preparato in $OUTPUT_DIR/"
echo ""
echo "Contenuto:"
echo "  - Dockerfile (generato da $DOCKERFILE_TEMPLATE)"
echo "  - addons/ (${#INCLUDED_MODULES[@]} moduli custom)"
if [ ${#INCLUDED_MODULES[@]} -gt 0 ]; then
    for mod in "${INCLUDED_MODULES[@]}"; do
        echo "    • $mod"
    done
fi
echo "  - requirements.txt (se presente)"
echo "  - build.sh (script di build)"
echo ""
echo "Per buildare l'immagine:"
echo "  cd $OUTPUT_DIR"
echo "  ./build.sh [nome-immagine] [tag]"
echo ""
echo "Oppure:"
echo "  cd $OUTPUT_DIR"
echo "  docker build -t mia-odoo:$ODOO_VERSION ."

# --- Build Docker image if requested ---
if [ "$DO_BUILD" = true ]; then
    echo ""
    log "Build immagine Docker..."

    # Costruisci il nome completo dell'immagine
    if [ -n "$DOCKER_REGISTRY" ]; then
        FULL_IMAGE="$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    else
        FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
    fi

    log_verbose "Immagine: $FULL_IMAGE"

    # Entra nella directory di build
    cd "$OUTPUT_DIR"

    # Build dell'immagine
    if docker build -t "$FULL_IMAGE" .; then
        log "✅ Immagine buildata con successo: $FULL_IMAGE"
    else
        echo "❌ Errore durante la build dell'immagine"
        exit 1
    fi

    # Torna alla directory originale
    cd - > /dev/null

    # Push se richiesto
    if [ "$DO_PUSH" = true ]; then
        echo ""
        log "Push immagine al registry..."

        if [ -z "$DOCKER_REGISTRY" ]; then
            echo "❌ DOCKER_REGISTRY non definito nel .env"
            echo "   Impossibile pushare senza registry configurato"
            exit 1
        fi

        if docker push "$FULL_IMAGE"; then
            log "✅ Immagine pushata con successo: $FULL_IMAGE"
        else
            echo "❌ Errore durante il push dell'immagine"
            echo "   Verifica di essere autenticato al registry: docker login $DOCKER_REGISTRY"
            exit 1
        fi
    fi
fi
