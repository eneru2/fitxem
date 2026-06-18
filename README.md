# Fitxem

Fichaje digital legal, simple y barato para pymes españolas.

Multi-tenant SaaS con app Flutter (iOS, Android, Web, Desktop) y API en Go.

## Requisitos

- Go 1.22+
- Flutter 3.18+
- Docker & Docker Compose

## Inicio rápido

```bash
# Postgres + API (las migraciones se aplican solas al arrancar la API)
make dev

# App Flutter (otra terminal)
make flutter
```

### Docker (stack completo)

```bash
make up    # Postgres + API en contenedores
make down
```

`make migrate` sigue disponible para CI o uso manual; en desarrollo y despliegue no hace falta ejecutarlo por separado.

## Estructura

```
just-clock/
├── frontend/   # App Flutter
├── backend/    # API Go
├── web/        # Web marketing
├── infra/      # Docker y despliegue
└── docs/       # Cumplimiento normativo
```

## Variables de entorno

Copia `.env.example` a `.env` y ajusta los valores.

## Cumplimiento

Ver [docs/compliance.md](docs/compliance.md) y [docs/itss-api.md](docs/itss-api.md).
