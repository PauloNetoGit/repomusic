#!/usr/bin/env node
// Atalhos "npm run ..." para quem prefere o npm. Faz o mesmo que os comandos do
// README: prepara a pasta android/ na primeira vez e chama o Flutter.
//
//   npm run flutter   -> instala e abre o app no celular conectado (release)
//   npm run apk       -> gera o .apk para mandar ao celular
//   npm run doctor    -> verifica se Flutter/Android estão instalados
//
// O Flutter em si NÃO vem pelo npm: instale o Flutter SDK e o Android Studio antes.
'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const mode = process.argv[2] || 'run';

function sh(cmd, args, opts = {}) {
  // shell: true para achar flutter.bat no Windows
  return spawnSync(cmd, args, { cwd: root, stdio: 'inherit', shell: true, ...opts });
}

function must(cmd, args) {
  const r = sh(cmd, args);
  if (r.status !== 0) {
    console.error(`\n✗ Falhou: ${cmd} ${args.join(' ')}`);
    process.exit(r.status || 1);
  }
}

function checkFlutter() {
  const r = spawnSync('flutter', ['--version'], { cwd: root, shell: true, encoding: 'utf8' });
  if (r.status !== 0) {
    console.error(`
✗ O Flutter não foi encontrado.

O npm não instala o Flutter. Faça uma vez:
  1. Instale o Flutter SDK: https://docs.flutter.dev/get-started/install
     (no Windows, extraia em C:\\src\\flutter e adicione C:\\src\\flutter\\bin ao PATH)
  2. Instale o Android Studio: https://developer.android.com/studio
  3. Feche e abra o terminal e rode:  npm run doctor
`);
    process.exit(1);
  }
  const first = (r.stdout || '').split('\n')[0];
  console.log(`✓ ${first.trim()}`);
}

function setupAndroid() {
  if (!fs.existsSync(path.join(root, 'android', 'app'))) {
    console.log('→ Primeira vez: criando a pasta android/ ...');
    must('flutter', ['create', '--platforms=android', '--org', 'com.pedaleira', '--project-name', 'pedaleira', '.']);
  }
  console.log('→ Ligando o motor de áudio ao Android ...');
  must('dart', ['tool/setup_android.dart']);
  must('flutter', ['pub', 'get']);
}

function androidDevices() {
  const r = spawnSync('flutter', ['devices', '--machine'], { cwd: root, shell: true, encoding: 'utf8' });
  const out = r.stdout || '';
  const start = out.indexOf('[');
  if (start < 0) return [];
  try {
    return JSON.parse(out.slice(start)).filter((d) => String(d.targetPlatform || '').startsWith('android'));
  } catch (_) {
    return [];
  }
}

function noPhoneHelp() {
  console.error(`
✗ Nenhum celular Android conectado.

No celular:
  1. Configurações > Sobre o telefone > toque 7 vezes em "Número da versão"
  2. Configurações > Sistema > Opções do desenvolvedor > ative "Depuração USB"
  3. Conecte o cabo USB e toque em "Permitir" na pergunta que aparecer
Depois rode de novo:  npm run flutter

Sem cabo? Rode  npm run apk  e mande o arquivo gerado para o celular.
`);
  process.exit(1);
}

switch (mode) {
  case 'doctor':
    checkFlutter();
    must('flutter', ['doctor']);
    break;

  case 'apk': {
    checkFlutter();
    setupAndroid();
    must('flutter', ['build', 'apk', '--release']);
    const apk = path.join(root, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
    console.log(`
✓ APK pronto:
  ${apk}

Mande esse arquivo para o celular (Drive, WhatsApp, cabo), toque nele e
permita "instalar apps desta fonte".`);
    break;
  }

  case 'run':
  default: {
    checkFlutter();
    setupAndroid();
    const devices = androidDevices();
    if (devices.length === 0) noPhoneHelp();
    console.log(`→ Instalando em: ${devices[0].name}`);
    must('flutter', ['run', '--release', '-d', devices[0].id]);
  }
}
