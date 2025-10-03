#!/bin/bash
set -e

# Questo script wrappa l'entrypoint di default di Odoo
# per installare automaticamente i moduli specificati

MODULES_FILE="/tmp/modules_to_install.txt"

# Se esiste il file con i moduli da installare e non è stato ancora processato
if [ -f "$MODULES_FILE" ] && [ ! -f "/var/lib/odoo/.modules_installed" ]; then
    MODULES_TO_INSTALL=$(cat "$MODULES_FILE")

    if [ -n "$MODULES_TO_INSTALL" ]; then
        echo "🔧 Installing standard Odoo modules: $MODULES_TO_INSTALL"

        # Aggiungi -i o --init agli argomenti se non presente
        if [[ "$@" != *"-i"* ]] && [[ "$@" != *"--init"* ]]; then
            set -- "$@" "--init=base,$MODULES_TO_INSTALL"
        fi

        # Marca come processato
        touch /var/lib/odoo/.modules_installed
    fi
fi

# Esegui l'entrypoint originale di Odoo
exec /entrypoint.sh "$@"
