#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <module_name>"
    exit 1
fi

MODULE_NAME="$1"

python ./odoo/odoo-bin scaffold "$MODULE_NAME" ./modules/