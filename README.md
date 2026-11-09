# PedalFX (Flutter + C++)

Simulador completo de pedaleira para guitarra e baixo, pronto para publicar na Play Store:
pedais, amplificadores (cabeçotes), cubos (combos), caixas com microfone, carregador de IR,
afinador cromático, looper e presets.

O som é processado por um **motor nativo em C++** (AAudio, baixa latência) e a interface é
Flutter. O Dart nunca toca nas amostras de áudio — ele só monta a cadeia e mexe nos knobs.

```
 Guitarra ─► interface USB / P2 ─► AAudio (entrada)
                                      │
                          ┌───────────▼────────────┐
                          │  motor C++ (native/)   │  thread de áudio em tempo real
                          │  gate → drive → amp →  │  oversampling 4x nos blocos com
                          │  caixa/IR → mod → delay│  distorção, sem alocar memória
                          │  → reverb → looper     │
                          └───────────▲────────────┘
                                      │ dart:ffi (só controle: blocos, knobs, medidores)
                          ┌───────────┴────────────┐
                          │   Flutter (lib/)       │  UI, presets, afinador, ajustes
                          └────────────────────────┘
```

## O que vem pronto

| Categoria | Conteúdo |
|---|---|
| **Pedais** (18) | Noise Gate, Compressor, Clean Boost, Green Drive (overdrive), Rodent Dist (distorção), Vintage Fuzz, Metal Core, EQ gráfico 7 bandas, Wah (manual/auto), Octaver (-1/-2), Chorus, Flanger, Phaser (4–12 estágios), Tremolo, Vibrato, Delay (digital/analógico/fita + tap tempo), Reverb (sala/salão/placa), Volume |
| **Amplificadores** (10) | Clean Americano, Tweed 59, Chime Classe A, Brit Plexi, Brit 800, Moderno Hi-Gain, Metal 5150, Jazz Transistor, Transistor Drive, Baixo Valvulado |
| **Cubos** (8) | Transistor 1x10, Americano 1x12, Tweed 1x12, Chime 2x12, Jazz 2x12, Brit 2x12, Blues 2x10, Baixo 1x15 |
| **Caixas** (9) | 1x12 aberta, 2x12 aberta, 4x12 V30, 4x12 Greenback, 2x10, 1x10, 1x15 baixo, 8x10 baixo, **IR personalizado (.wav)** com posição de microfone, cortes de grave/agudo |
| **Ferramentas** | Afinador (YIN, ±0,5 cent, referência 430–450 Hz), looper de 60 s com overdub, medidores de entrada/saída, 124 presets de fábrica (11 essenciais + 113 inspirados em solos e bases famosos, em 10 categorias, com busca), presets do usuário com exportar/importar JSON |

Detalhes técnicos que fazem diferença no som:
- **Tonestack dos amplificadores modelado a partir do circuito** (Fender/Marshall/Vox, equações de Yeh & Smith,
  conferidas contra uma simulação nodal do circuito — erro < 0,1 dB).
- Pré-amplificador com estágios valvulados assimétricos, sag de fonte e power amp com presença/ressonância.
- Convolução de IR com **latência zero** (cabeça FIR direta + cauda em FFT particionada), reamostragem
  automática de qualquer taxa (44,1/48/96 kHz…), normalização de volume.
- Trocas de bloco/preset sem travar o áudio (ponteiro atômico + liberação após o ciclo de áudio),
  bypass com crossfade (sem estalos), limitador de segurança na saída.
- Buffer adaptativo: se o aparelho tiver falhas (xruns), o app aumenta o buffer sozinho.

### Biblioteca de presets
Os presets de fábrica ficam em `lib/state/factory_presets.dart`, agrupados em Essenciais, Solos Lendários,
Bases de Rock, Blues, Metal & Hard Rock, Grunge & Alternativo, Funk/Soul/Pop, Ambiente & Psicodelia,
Jazz & Fusion, Brasil e Baixo. Cada um tem uma dica de como tocar e a referência "Inspirado em: música — artista".
São aproximações feitas com os blocos do app, não cópias de gravações. Todos foram medidos no motor real
(volume entre -30 e -14 dBFS RMS, sem clipar).

Se a revisão da Play Store implicar com os nomes de artistas, mude `kShowInspirations` para `false` no topo
desse arquivo: os timbres continuam iguais, só some a referência.

Nomes de modelos são genéricos ("Brit Plexi", "Green Drive"…) de propósito: **não use marcas
registradas** (Marshall, Fender, Ibanez etc.) no nome do app, nos ícones ou na ficha da Play Store.

## Visual

A tela é uma pedaleira vista de cima. Cada bloco tem a cara do equipamento real: gabinete colorido de pedal,
cabeçote de tolex com painel de latão e knobs "chicken-head", cubo de tweed com grade, e caixa com tecido e
placa. Os mini-knobs mostram a posição de cada parâmetro, e cabos de patch ligam os blocos na ordem do sinal,
da guitarra até os fones. O nome do preset fica escrito a marcador numa fita crepe; as setas embaixo dela
trocam de preset, como um footswitch de banco. Os medidores e o afinador usam escadas de LEDs.

Fontes incluídas em `assets/fonts/` (livres, licenças na mesma pasta): Big Shoulders Display (nomes dos
equipamentos), Barlow (texto) e Permanent Marker (fita). Cores e estilos ficam em `lib/ui/theme.dart`.

## Requisitos

- Flutter estável recente (o código Dart foi verificado com o analisador contra o Flutter 3.47) — `flutter doctor` sem erros para Android.
- Android Studio com SDK; o Gradle baixa o NDK e o CMake automaticamente no primeiro build.
- Celular com **Android 9 (API 28) ou superior**.
- Para tocar de verdade: interface de áudio USB (USB-C/OTG) ou cabo/adaptador de guitarra P2 TRRS, e fones.

## Instalar no celular sem instalar nada no computador

1. Crie um repositório no GitHub e envie todos os arquivos deste projeto, **incluindo a pasta `.github`**.
2. No repositório, abra a aba **Actions** → **Gerar APK** → **Run workflow**.
3. Quando terminar (≈10 min), baixe `pedaleira-apk` em **Artifacts**, descompacte e passe o `app-release.apk` para o celular.
4. No celular, abra o APK e permita "instalar apps desta fonte" quando o Android pedir.

## Atalhos com npm

Se você já usa Node.js: depois de instalar o Flutter SDK e o Android Studio, basta

```bash
npm run doctor    # confere se está tudo instalado
npm run flutter   # instala e abre o app no celular conectado por USB
npm run apk       # gera o .apk para mandar ao celular sem cabo
```

Na primeira vez, eles criam a pasta `android/` e ligam o motor de áudio sozinhos. O npm não instala o
Flutter (ele não é um pacote npm); os scripts só chamam os comandos do Flutter por você.

## Como rodar

```bash
cd pedaleira

# 1) gera a pasta android/ para a sua versão do Flutter (não sobrescreve lib/ nem pubspec)
flutter create --platforms=android --org com.seudominio --project-name pedaleira .

# 2) liga o motor C++ ao Gradle, minSdk 28, permissão de microfone e MainActivity
dart tool/setup_android.dart

# 3) roda no celular conectado (modo debug)
flutter run
```

O identificador do app na Play Store é `com.uchord.pedalfx`, definido em `tool/setup_android.dart`
(`_applicationId`). Ele **não pode mudar** depois de publicado; o `--org` do `flutter create` não importa.

> Dica: o modo **debug** do Flutter não afeta o áudio (ele roda no C++ otimizado), mas a interface
> fica mais lenta. Para sentir o app de verdade use `flutter run --release`.

### Primeiros passos no app
1. Toque no botão ⏻ (canto inferior esquerdo) e permita o microfone.
2. Ajuste **Configurações → Ganho de entrada** até o medidor IN ficar no verde/amarelo ao palhetar forte.
3. Toque no nome do preset (topo) para trocar de preset; toque num bloco para editar os knobs
   (arraste para cima/baixo; toque duplo volta ao padrão); segure e arraste a alça ⋮⋮ para reordenar.
4. **Adicionar** abre o catálogo: Pedais, Amplificadores, Cubos e Caixas. O bloco entra na posição
   certa do sinal automaticamente (drive antes do amp, delay depois da caixa…).

## Testes

Motor nativo (no computador, Linux/macOS):

```bash
cmake -S native -B native/build -DPEDAL_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build native/build -j
./native/build/engine_tests --wav-dir /tmp        # testes + arquivos demo_*.wav para ouvir
./native/build/engine_tests --calibrate            # recalcula os volumes dos amplificadores
```

Cobertura: tonestack vs. circuito, filtro de oversampling, convolução vs. convolução direta
(erro relativo ~1e-7), afinador, looper, todos os blocos/modelos com knobs no mínimo/padrão/máximo
(sem NaN, sem passar de 0 dBFS), leitura de WAV 16-bit/float em 44,1 e 96 kHz, estresse de threads
(cadeia alterada 400 vezes durante o processamento) e desempenho (cadeia pesada ≈ 43× tempo real
num núcleo de desktop). Também passa limpo com AddressSanitizer, UBSan e ThreadSanitizer.

Interface/lógica: `flutter test`.

## Gratuito
O PedalFX é totalmente gratuito: sem assinatura, anúncios, login nem acesso à internet. Não há
compras no app, e o app não coleta dados.

## Publicar na Play Store

1. **Ícone e nome**: o ícone fica em `android_overlay/res/` e é copiado pelo `tool/setup_android.dart`, que também
   define o nome `PedalFX`. Para a ficha da loja use `assets/store/icone_play_store_512.png` (512×512).
2. **Chave de assinatura** (guarde o arquivo e as senhas para sempre):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias upload
   ```
   Crie `android/key.properties` (já está no `.gitignore`):
   ```properties
   storePassword=SUA_SENHA
   keyPassword=SUA_SENHA
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   O `build.gradle.kts` já foi preparado pelo script para usar esse arquivo quando ele existir.
3. **Versão**: em `pubspec.yaml`, `version: 1.0.0+1` → aumente o número depois do `+` a cada envio.
4. **Gerar o pacote**: `flutter build appbundle` → `build/app/outputs/bundle/release/app-release.aab`.
5. **Play Console** (conta de desenvolvedor, taxa única):
   - Contas **pessoais** criadas depois de 13/11/2023 precisam de um **teste fechado com pelo menos
     12 testadores inscritos por 14 dias seguidos** antes de liberar a produção.
   - **Política de privacidade** é obrigatória porque o app usa o microfone: publique o texto de
     `PRIVACY_POLICY.md` (ajustado com seu nome/e-mail) numa página pública e informe a URL.
   - **Segurança dos dados**: o app não coleta nem compartilha dados; o áudio é processado só no
     aparelho e não é gravado nem enviado pela internet.
   - Classificação de conteúdo: questionário simples (app de música, sem conteúdo sensível).
   - O Flutter já define o `targetSdk` exigido pela Play Store; mantenha o Flutter atualizado.
   - O motor é compilado com páginas de 16 KB (exigência do Android 15+ na Play).

## Estrutura do código

```
native/                      motor de áudio (C++17)
  src/dsp.h                  filtros, oversampler 4x, FFT, linhas de atraso
  src/pedals.cpp             os 18 pedais
  src/amps.cpp/.h            tonestack, amplificadores, caixas, cubos
  src/convolver.cpp/.h       convolução de IR + leitura de WAV + reamostragem
  src/engine.cpp/.h          cadeia, bypass, medidores, looper
  src/tuner.h                afinador YIN
  src/audio_android.cpp      AAudio full-duplex, reconexão automática, buffer adaptativo
  src/api.cpp                API C usada pelo Dart (ae_*)
  src/calibration.inc        volumes calibrados por modelo (gerado pelos testes)
  test/engine_tests.cpp      testes e calibração
lib/
  engine/audio_engine.dart   bindings dart:ffi (e motor "mudo" para rodar a UI sem a lib)
  engine/catalog.dart        catálogo de blocos (vem do C++ em JSON)
  models/rig.dart            blocos e presets (JSON)
  state/rig_controller.dart  estado do app, sincronização com o motor, ciclo de vida
  state/factory_presets.dart presets de fábrica
  services/                  canal Android (permissão, seletor de IR, dispositivos) e arquivos
  ui/                        telas: pedaleira, editor de bloco, catálogo, afinador, presets, ajustes
android_overlay/MainActivity.kt   instalada pelo tool/setup_android.dart
assets/catalog.json          cópia do catálogo (usada só quando a lib nativa não está presente)
```

### Adicionar um pedal novo
1. Crie a classe em `native/src/pedals.cpp` (herdando `Effect`, implementando `prepare` e `process`
   sem alocar memória em `process`).
2. Registre em `registerPedals()` com nome, grupo, cor, descrição e parâmetros.
3. Rode os testes nativos (o teste de catálogo já exercita o bloco novo em todos os extremos) e
   copie `build_catalog.json` gerado para `assets/catalog.json`.
A interface (catálogo, knobs, presets) se ajusta sozinha.

## Limitações conhecidas
- Somente Android (o motor tem backend AAudio; iOS exigiria um backend CoreAudio em `native/src`).
- A latência depende do aparelho: celulares com "áudio profissional" ficam abaixo de ~20 ms;
  aparelhos de entrada podem passar de 30 ms. Bluetooth adiciona 150–300 ms (use fio ou USB).
- O áudio para quando o app vai para segundo plano (regra do Android para o microfone sem
  serviço em primeiro plano) e volta sozinho ao reabrir.
