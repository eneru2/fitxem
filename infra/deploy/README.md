# Despliegue EU

## Fly.io (Frankfurt)

La imagen Docker aplica las migraciones automáticamente al arrancar la API. Solo hace falta configurar `DATABASE_URL` y desplegar.

```bash
cd backend
fly launch --config ../infra/deploy/fly.toml --region fra
fly secrets set DATABASE_URL=... JWT_SECRET=... ITSS_API_KEY=...
fly deploy --dockerfile Dockerfile
```

## Backups

Ejecutar `infra/deploy/backup.sh` diariamente via cron con `DATABASE_URL` configurado.

## Stripe

1. Configurar `STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET`
2. Webhook endpoint: `POST /webhooks/stripe`
3. Checkout: `POST /admin/billing/checkout` (requiere auth admin)

## Web estática

Servir `web/` con Cloudflare Pages o nginx. Configurar `window.JUST_CLOCK_API` en producción.
