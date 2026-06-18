# Cumplimiento normativo

## Vigente (RDL 8/2019 / Art. 34.9 ET)

Just Clock implementa:

- Registro diario de inicio y fin de jornada por trabajador
- Conservación mínima de 4 años (sin borrado físico)
- Acceso para trabajadores (app), administradores y exportación para ITSS
- Registros objetivos, fiables e inalterables (cadena hash + log de auditoría)

## Anteproyecto (pendiente BOE)

Preparado para:

- Formato exclusivamente digital
- Sellado temporal RFC 3161 (TSA configurable)
- API REST para inspección remota ITSS (`/itss/v1/...`)
- Exportación JSON, XML y PDF
- Correcciones mediante eventos compensatorios (no edición retroactiva)
- Datos en UE (responsabilidad del operador en despliegue)

## No implementado / limitaciones

- No existe certificación oficial de homologación hasta publicación del Real Decreto
- La API ITSS sigue un contrato interno basado en el borrador; se adaptará cuando exista especificación oficial
- Biometría no soportada (alineado con criterios AEPD)

## Declaración responsable

El operador del servicio debe mantener servidores en el EEE, DPA con clientes y política de privacidad conforme RGPD.
