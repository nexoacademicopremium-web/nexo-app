// ============================================================
// Mete el logo del informe dentro de la Edge Function.
//
// El PDF lo genera PDFShift desde HTML suelto, sin acceso a los
// ficheros del proyecto, así que el logo tiene que viajar embebido
// como base64 dentro del propio HTML.
//
// Uso:  node scripts/actualizar-logo-informe.js [ruta-al-png]
// ============================================================

const fs   = require('fs');
const path = require('path');

const RAIZ    = path.join(__dirname, '..');
const FUNCION = path.join(RAIZ, 'supabase/functions/publicar-informe/index.ts');
const LOGO    = process.argv[2] || path.join(RAIZ, 'assets/logo/logo_nexo_horizontal.png');

if (!fs.existsSync(LOGO)) {
  console.error('No encuentro el logo en: ' + LOGO);
  console.error('Guárdalo ahí y vuelve a ejecutar.');
  process.exit(1);
}

const png = fs.readFileSync(LOGO);
if (png.toString('ascii', 1, 4) !== 'PNG') {
  console.error('Ese fichero no es un PNG.');
  process.exit(1);
}

const ancho = png.readUInt32BE(16);
const alto  = png.readUInt32BE(20);
const b64   = 'data:image/png;base64,' + png.toString('base64');

let src = fs.readFileSync(FUNCION, 'utf8');
const re = /const LOGO_BLANCO_SRC = '[^']*'/;

if (!re.test(src)) {
  console.error('No encuentro LOGO_BLANCO_SRC en la Edge Function.');
  process.exit(1);
}

src = src.replace(re, "const LOGO_BLANCO_SRC = '" + b64 + "'");
fs.writeFileSync(FUNCION, src);

console.log('Logo actualizado.');
console.log('  Fichero:    ' + path.relative(RAIZ, LOGO));
console.log('  Dimensiones: ' + ancho + 'x' + alto + '  (ratio ' + (ancho / alto).toFixed(2) + ')');
console.log('  Peso en base64: ' + (b64.length / 1024).toFixed(0) + ' KB');
if (ancho < 700) {
  console.log('  AVISO: menos de 700px de ancho puede verse blando al imprimir.');
}
console.log('\nAhora despliega:  npx supabase functions deploy publicar-informe --no-verify-jwt');
