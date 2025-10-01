# Odoo Development Environment

This project provides a complete and automated development environment for Odoo, with automatic configuration of Python, PostgreSQL, and all necessary dependencies.

## Features

- ✅ **Complete automatic setup**: Python 3.12, pyenv, PostgreSQL, pgAdmin
- ✅ **Zero manual configuration**: everything is configured automatically
- ✅ **Integrated Docker Compose**: containerized PostgreSQL and pgAdmin
- ✅ **Modern dependency management**: Poetry for development dependencies
- ✅ **Multiple startup options**: demo mode, fresh database, verbose output
- ✅ **Cross-platform**: supports Linux, macOS, WSL

## Requirements

- **Docker** and **Docker Compose**
- **Git**
- **Bash** (for the startup script)

Everything else (Python, pyenv, dependencies) is installed automatically.

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd odoo
   ```

2. **Start the environment**:
   ```bash
   ./start.sh
   ```

3. **Access the application**:
   - Odoo: http://localhost:8069
   - pgAdmin: http://localhost:8081

## Startup Script (start.sh)

The `start.sh` script completely automates the development environment configuration.

### Available Options

```bash
./start.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Detailed output of all operations |
| `--skip-deps` | Skip dependency installation |
| `--skip-modules` | Skip module management (clone/update) |
| `--demo` | Start Odoo with demo data |
| `--fresh-db` | Initialize a completely fresh database |
| `--force` | Skip all interactive confirmations |
| `--no-browser` | Don't automatically open the browser |
| `--pg-timeout N` | PostgreSQL timeout in seconds (default: 60) |
| `--debug` | Enable debug mode (port 5678) |
| `--debug-wait` | Enable debug and wait for client connection |
| `-h, --help` | Show help |

### Usage Examples

```bash
# Standard startup
./start.sh

# Startup with demo data and verbose output
./start.sh --demo --verbose

# Complete database reset
./start.sh --fresh-db

# Quick startup without dependencies (if already installed)
./start.sh --skip-deps --no-browser

# Debug - Odoo starts immediately
./start.sh --debug

# Debug - Odoo waits for debugger
./start.sh --debug-wait
```

### Script Features

#### 1. **Python and pyenv Management**
- Automatically installs pyenv if not present
- Configures Python 3.12.2 as the project version
- Adds pyenv to `.bashrc` for automatic loading
- Verifies Python installation integrity

#### 2. **System Dependencies Check**
- Checks for `wkhtmltopdf` (required for Odoo PDFs)
- Validates Docker Compose
- Validates environment configuration

#### 3. **Database Management**
- Starts PostgreSQL via Docker Compose
- Waits for database to be ready with configurable timeout
- Supports complete database reset with `--fresh-db`
- Manages pgAdmin for database administration

#### 4. **Python Environment Setup**
- Creates and activates virtual environment automatically
- Installs Odoo runtime dependencies
- Configures Poetry for development dependencies
- Intelligent caching to avoid reinstallations

#### 5. **Odoo Configuration**
- Automatic cloning of Odoo repository (version 17.0)
- Database parameters and HTTP port configuration
- Support for `odoo.conf` configuration file
- Automatic custom module management via Git

#### 6. **Smart Startup**
- Terminates existing Odoo processes
- Automatic browser opening
- Verbose mode for debugging
- Error handling with informative messages

## Configuration

### Environment Variables

Create a `.env` file in the project root to customize the configuration:

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

### Project Structure

```
odoo/
├── start.sh              # Main startup script
├── docker-compose.yml    # PostgreSQL and pgAdmin configuration
├── pyproject.toml        # Python dependencies and configuration
├── modules.json.example  # Module configuration template
├── modules.json          # Module configuration (local, optional)
├── .env                  # Environment variables (optional)
├── odoo.conf            # Odoo configuration (optional)
├── .venv/               # Virtual environment (auto-generated)
├── odoo/                # Odoo repository (auto-cloned)
└── modules/             # Custom modules (auto-cloned)
```

## Development

### Custom Module Management

**Automatic setup:**
1. Copy `modules.json.example` to `modules.json`
2. Configure your Git repositories in the file
3. Start with `./start.sh` - modules are cloned automatically

**modules.json format:**
```json
{
  "modules": [
    {
      "name": "my_module",
      "git_url": "git@github.com:username/my_module.git",
      "branch": "main",
      "enabled": true,
      "description": "Module description"
    }
  ],
  "config": {
    "auto_update": true,
    "skip_existing": false,
    "clone_depth": 1
  }
}
```

**Configuration options:**
- `auto_update`: Update existing modules with git pull
- `skip_existing`: Skip modules already present
- `clone_depth`: Git clone depth (default: 1)

### Debugging

**VS Code Debug Setup:**
1. Copy `.vscode/launch.json.example` to `.vscode/launch.json`
2. Customize configurations if necessary

**Start with debug:**
```bash
./start.sh --debug
```

**Other options:**
- Use `--verbose` for detailed output
- Odoo logs are visible directly in the terminal
- pgAdmin is available for database management
- Breakpoints with `import pdb; pdb.set_trace()` in Python code

### Environment Reset

```bash
# Complete database reset
./start.sh --fresh-db

# Complete dependency reinstallation
rm -rf .venv .requirements_installed
./start.sh
```

## Troubleshooting

### Common Issues

**PostgreSQL won't start**:
```bash
docker-compose down
docker-compose up -d
```

**Python dependency errors**:
```bash
rm -rf .venv .requirements_installed
./start.sh
```

**Port already in use**:
- Change `ODOO_HTTP_PORT` in the `.env` file
- Or terminate the existing process: `pkill -f odoo-bin`

**PostgreSQL timeout**:
```bash
./start.sh --pg-timeout 120
```

## License

MIT