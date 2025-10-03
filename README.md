# Odoo Development Environment

This project provides a complete and automated development environment for Odoo, with automatic configuration of Python, PostgreSQL, and all necessary dependencies. It also includes tools for building and deploying production Docker images.

## Features

- ✅ **Complete automatic setup**: Python 3.12, pyenv, PostgreSQL, pgAdmin
- ✅ **Zero manual configuration**: everything is configured automatically
- ✅ **Integrated Docker Compose**: containerized PostgreSQL and pgAdmin
- ✅ **Modern dependency management**: Poetry for development and production dependencies
- ✅ **Multiple startup options**: demo mode, fresh database, verbose output, debug mode
- ✅ **Docker image builder**: automated build and push to Docker registry
- ✅ **Customizable Dockerfile**: template-based Docker image generation
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
ODOO_VERSION=18.0

# Docker Registry (for production builds)
DOCKER_REGISTRY=registry.vultur-code.dev

# pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=admin
```

### Project Structure

```
odoo/
├── start.sh              # Development environment startup script
├── build-docker.sh       # Docker image builder script
├── docker-compose.yml    # PostgreSQL and pgAdmin configuration
├── Dockerfile.template   # Docker image template
├── pyproject.toml        # Python dependencies and configuration
├── modules.json          # Development modules configuration
├── build-modules.json    # Production build modules configuration
├── .env                  # Environment variables (optional)
├── odoo.conf             # Odoo configuration (optional)
├── .venv/                # Virtual environment (auto-generated)
├── odoo/                 # Odoo repository (auto-cloned)
├── modules/              # Custom modules (auto-cloned)
└── docker-build/         # Docker build output (auto-generated)
```

## Development

### Custom Module Management

**Development modules (modules.json):**
This file is used by `start.sh` for local development.

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

**Production modules (build-modules.json):**
This file is used by `build-docker.sh` for Docker image builds.

```json
{
  "modules": [
    {
      "name": "my_module",
      "git_url": "git@github.com:username/my_module.git",
      "branch": "main",
      "enabled": true
    },
    {
      "name": "local_module",
      "path": "./modules/local_module",
      "enabled": true
    }
  ]
}
```

**Module source options:**
- `git_url` + `branch`: Clone from Git repository
- `path`: Copy from local directory

**Configuration options:**
- `auto_update`: Update existing modules with git pull (development only)
- `skip_existing`: Skip modules already present (development only)
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

## Docker Image Builder (build-docker.sh)

The `build-docker.sh` script creates production-ready Docker images with your custom Odoo modules.

### Available Options

```bash
./build-docker.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Detailed output of all operations |
| `-f, --file FILE` | Modules JSON file (default: build-modules.json) |
| `-o, --output DIR` | Output directory (default: docker-build) |
| `-t, --template FILE` | Dockerfile template (default: Dockerfile.template) |
| `-n, --name NAME` | Image name (default: odoo-custom) |
| `--build` | Build Docker image after preparation |
| `--push` | Build and push Docker image to registry |
| `--force` | Overwrite existing output directory |
| `-h, --help` | Show help |

### Usage Examples

```bash
# Prepare build files only
./build-docker.sh

# Prepare and build image
./build-docker.sh --build

# Build and push to registry (defined in .env)
./build-docker.sh --push

# Custom image name
./build-docker.sh --build -n my-odoo-app

# Custom modules file and output directory
./build-docker.sh -f custom-modules.json -o custom-build --build

# Full workflow with verbose output
./build-docker.sh -v --push --force
```

### Build Process

1. **Module Collection**: Clones/copies modules from `build-modules.json`
2. **Dependency Extraction**: Extracts Python dependencies from `pyproject.toml`
3. **Dockerfile Generation**: Creates Dockerfile from `Dockerfile.template`
4. **Image Build** (with `--build`): Builds Docker image with specified name
5. **Registry Push** (with `--push`): Pushes image to `DOCKER_REGISTRY`

### Dockerfile Customization

Edit `Dockerfile.template` to customize the Docker image. Available variables:
- `{{ODOO_VERSION}}`: Replaced with value from `.env`

Example template:
```dockerfile
FROM odoo:{{ODOO_VERSION}}

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    some-package \
    && rm -rf /var/lib/apt/lists/*

# Copy custom modules
COPY ./addons /mnt/extra-addons

# Install Python dependencies
COPY requirements.txt* /tmp/
RUN if [ -f /tmp/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /tmp/requirements.txt; \
    fi

USER odoo

EXPOSE 8069
CMD ["odoo"]
```

### Output Structure

After running `build-docker.sh`, the output directory contains:

```
docker-build/
├── Dockerfile           # Generated from template
├── addons/              # Custom modules
│   ├── module1/
│   └── module2/
├── requirements.txt     # Python dependencies (if any)
├── .dockerignore        # Docker ignore rules
└── build.sh             # Helper build script
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

**Docker build fails**:
- Check that all modules in `build-modules.json` are accessible
- Verify `DOCKER_REGISTRY` is correctly set in `.env` (for push)
- Ensure you're logged in to the registry: `docker login registry.vultur-code.dev`

**Module not found in Docker image**:
- Verify module is enabled in `build-modules.json`
- Check that module was copied to `docker-build/addons/`
- Rebuild with `--force` flag to clean previous builds

## Workflows

### Development Workflow

1. Configure development modules in `modules.json`
2. Start environment: `./start.sh`
3. Develop and test locally
4. Commit changes to module repositories

### Production Deployment Workflow

1. Configure production modules in `build-modules.json`
2. Update dependencies in `pyproject.toml` if needed
3. Customize `Dockerfile.template` if needed
4. Build and push: `./build-docker.sh --push -n my-app`
5. Deploy image: `docker pull registry.vultur-code.dev/my-app:18.0`

### Quick Production Build

```bash
# One-liner to build and push
./build-docker.sh --push -n production-odoo --force
```

## License

MIT