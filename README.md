# Rendiciones — app de boletas y vouchers

App móvil para registrar en terreno cada compra pagada con boleta o voucher (no factura), con el mismo estilo visual que ClimaPro (DM Sans, verde `#1D9E75`, tarjetas). Es una app independiente de tu ClimaPro operativo: repo propio y proyecto Supabase propio.

Archivos:
- `index.html` — formulario de captura en terreno.
- `admin.html` — panel de administración con clave de acceso.
- `schema.sql` — script para crear/actualizar la base de datos (seguro de re-correr).
- `manifest.json` — permite "instalar" la app en el celular.

## Cómo funciona la app (flujo actual)

1. **Responsable del Fondo**: al entrar, se elige con qué fondo se pagará (administrable desde `admin.html`, pestaña "💳 Responsables del Fondo"). Queda guardado en el celular para la próxima vez.
2. **Foto de la boleta**: se toma o adjunta primero. La app intenta leer automáticamente la Fecha, el Monto y el N° de Folio (OCR gratis, corre en el propio celular, sin API key ni costo — y descarta a propósito la fecha de la resolución SII que traen todas las boletas, para no confundirla con la fecha de la compra). La foto se sube en tamaño y calidad original, sin comprimir, para que quede legible en el PDF consolidado.
3. **Completa los datos**: se muestran Motivo, Fecha, Monto, N° de Folio (prellenados si el OCR los detectó — siempre hay que revisarlos, el folio queda como referencia para validar esa lectura), Centro de Costo / Proyecto, y **Responsable Rendición** (quién hizo la compra: puede ser el mismo Responsable del Fondo u otra persona — administrable desde `admin.html`, pestaña "👤 Usuarios").
4. **Enviar**: si no hay señal, la rendición queda guardada en el celular y se envía sola cuando vuelve la conexión.

Al fondo de la pantalla inicial hay un link discreto **"Panel de administración →"** que lleva a `admin.html`.

## Panel de administración (`admin.html`)

Se entra con clave (ver sección de configuración más abajo). Tiene 4 pestañas:

- **📋 Rendiciones**: lista todas las rendiciones con filtros por Responsable Rendición, Responsable del Fondo, estado, período y rango de fechas (Desde/Hasta). Con esos mismos filtros aplicados, puedes:
  - **📊 Descargar Excel**: genera un `.xlsx` con todos los campos de las rendiciones filtradas (se genera en el propio navegador, no sube nada a ningún servidor externo).
  - **📄 Descargar PDF con boletas**: genera un PDF con una portada resumen y luego una página por cada foto de boleta, en tamaño legible, junto a sus datos (fecha, monto, motivo, responsable, folio).
  - **✅ Marcar selección como procesada**: le asigna el período que escribas (ej. `2026-07`) a todas las rendiciones filtradas y las pasa a estado `procesado`, para no volver a incluirlas en el próximo cierre.
- **💳 Responsables del Fondo**: alta y baja de quienes pueden ser "Responsable del Fondo" al entrar a la app.
- **👤 Usuarios**: alta y baja de quienes pueden ser "Responsable Rendición" además de los Responsables del Fondo (técnicos u otras personas).
- **🏷️ Centros de Costo**: alta y baja de los "Centro de Costo / Proyecto" que aparecen en el formulario de terreno.

Las tres pestañas de gestión (Responsables del Fondo, Usuarios, Centros de Costo) funcionan igual: escribes el nombre nuevo, click "+ Agregar", y cada fila existente tiene un botón para Activar/Desactivar (desactivar no borra las rendiciones ya registradas con ese valor, solo deja de aparecer como opción nueva).

Flujo típico de cierre de período: filtra por fecha (o déjalo sin filtro para ver todo lo pendiente), revisa que los datos estén bien, descarga el Excel y el PDF, y luego marca la selección como procesada.

## 1. Crear el proyecto Supabase (una sola vez)

1. Entra a [supabase.com](https://supabase.com) → **New project** (el plan gratis alcanza de sobra).
2. Cuando esté listo, ve a **SQL Editor → New query**, pega todo el contenido de `schema.sql` y dale **Run**.
3. Ve a **Project Settings → API** y copia dos datos: **Project URL** y la **anon public key**.

Este script es seguro de volver a correr las veces que quieras (no duplica nada), así que si haces cambios al esquema en el futuro, siempre puedes re-pegarlo y darle Run.

## 2. Configurar los archivos

Abre `index.html` y `admin.html`, y en ambos reemplaza cerca del final del archivo:

```js
const SB_URL = 'https://TU-PROYECTO.supabase.co';
const SB_KEY = 'TU-ANON-KEY';
```

En `admin.html`, cambia también la clave de acceso del panel (no es seguridad real, solo evita entradas casuales):

```js
const CLAVE_ADMIN = 'climatermic2026';
```

**Responsables del Fondo**, **Usuarios** y **Centros de Costo** ya no están fijos en el código — los tres se administran desde `admin.html`.

## 3. Subir a GitHub Pages

1. Crea un repo nuevo en GitHub.
2. Sube los 4 archivos (`index.html`, `admin.html`, `schema.sql`, `manifest.json`) a la raíz del repo.
3. Ve a **Settings → Pages**, en "Branch" selecciona `main` / `root` y guarda.
4. En un par de minutos tu app queda en `https://TU-USUARIO.github.io/TU-REPO/`.

El panel admin queda en `https://TU-USUARIO.github.io/TU-REPO/admin.html`.

## 4. Cierre de período

Puedes hacerlo tú mismo desde `admin.html` (filtrar → descargar Excel/PDF → marcar como procesada), o pedirle a Claude en este chat algo como:

> "Corre la consolidación de rendiciones de julio 2026"

En ese caso Claude puede además abrir cada foto y completar/verificar Proveedor y Categoría antes de generar los archivos, algo que la app no hace por sí sola.

## Notas de seguridad

- El bucket de fotos es público de lectura (para verlas en el panel y en el PDF). Si prefieres que no sean públicas, se puede cambiar a bucket privado + URLs firmadas.
- La clave del panel admin es una protección básica, no reemplaza un login real.
- Excel y PDF se generan enteramente en tu navegador (librerías SheetJS y jsPDF cargadas por CDN) — no se envían datos a ningún servidor externo en ese proceso.
