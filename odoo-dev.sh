#!/bin/bash
set -e

# --- Funzione di help ---
show_help() {
    cat <<EOF
Odoo Development Manager

Usage: $0 <command> [options]

Commands:
  start [options]           Avvia l'ambiente di sviluppo Odoo
  build [options]           Prepara/builda immagine Docker
  create <module_name>      Crea un nuovo modulo Odoo

START Options:
  -v, --verbose             Verbose output
  --skip-deps               Skip dependency installation
  --skip-modules            Skip module management (clone/update)
  --demo                    Enable demo mode
  --fresh-db                Initialize fresh database (--init=all)
  --force                   Skip confirmation prompts
  --no-browser              Don't open browser automatically
  --pg-timeout N            PostgreSQL timeout in seconds (default: 60)
  --debug                   Enable debug mode (port 5678)
  --debug-wait              Enable debug mode and wait for client

BUILD Options:
  -v, --verbose             Verbose output
  -f, --file FILE           Modules JSON file (default: build-modules.json)
  -o, --output DIR          Output directory (default: docker-build)
  -t, --template FILE       Dockerfile template (default: Dockerfile.template)
  -n, --name NAME           Image name (default: odoo-custom)
  --tag TAG                 Image tag (default: ODOO_VERSION from .env)
  --build                   Build Docker image after preparation
  --push                    Build and push Docker image to registry
  --force                   Overwrite existing output directory

CREATE:
  $0 create <module_name>   Crea nuovo modulo con nome specificato

Examples:
  $0 start --verbose --fresh-db
  $0 build --build --name my-odoo
  $0 create my_custom_module

EOF
}

# --- Main script ---
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    start)
        # Esegui start.sh con tutti gli argomenti passati
        exec bash "$(dirname "$0")/start.sh" "$@"
        ;;

    build)
        # Esegui build-docker.sh con tutti gli argomenti passati
        exec bash "$(dirname "$0")/build-docker.sh" "$@"
        ;;

    create)
        # Verifica che ci sia il nome del modulo
        if [ -z "$1" ]; then
            echo "❌ Errore: specifica il nome del modulo"
            echo "Usage: $0 create <module_name>"
            exit 1
        fi

        MODULE_NAME="$1"

        # Esegui scaffold
        python ./odoo/odoo-bin scaffold "$MODULE_NAME" ./modules/
        ;;

    -h|--help|help)
        show_help
        exit 0
        ;;

    *)
        echo "❌ Comando sconosciuto: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
