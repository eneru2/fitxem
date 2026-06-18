# ITSS API v1 (borrador interno)

Contrato provisional hasta publicación de especificación oficial.

Base path: `/itss/v1`

Autenticación: Bearer token de inspector (futuro: mTLS con certificado ITSS).

## GET /companies/{cif}/records

Parámetros query: `from` (RFC3339), `to` (RFC3339)

Respuesta:

```json
{
  "company_cif": "B12345678",
  "from": "2026-01-01T00:00:00Z",
  "to": "2026-01-31T23:59:59Z",
  "records": [
    {
      "employee_nif": "12345678A",
      "employee_name": "Juan García",
      "event_type": "in",
      "recorded_at": "2026-01-15T08:02:00Z",
      "hour_type": "ordinary",
      "work_center": "Madrid",
      "event_hash": "sha256:...",
      "is_correction": false
    }
  ]
}
```

## GET /companies/{cif}/employees/{nif}/records

Mismos parámetros `from` / `to`. Filtra por trabajador.

## GET /companies/{cif}/audit-log

Parámetros: `from`, `to`, `limit` (default 100, max 1000)

Devuelve entradas de auditoría: creaciones, correcciones, accesos de exportación.
