// Biblioteca de presets de fábrica.
//
// Os timbres são *inspirados* em gravações famosas: aproximações feitas com os
// blocos genéricos do app (nenhum som, marca ou gravação é reproduzido). Os
// parâmetros são referenciados por nome (do catálogo do motor), então continuam
// válidos se a ordem dos parâmetros mudar; validateFactoryPresets() acusa nomes
// errados nos testes.
import '../engine/catalog.dart';
import '../models/rig.dart';

/// Mostra "Inspirado em: música — artista" na interface.
///
/// Citar músicas e artistas como referência é comum em apps de timbre, mas a
/// Google Play pode recusar apps que pareçam ter vínculo com artistas. Se a
/// revisão reclamar, mude para `false`: os presets continuam iguais, só sem a
/// referência visível.
const bool kShowInspirations = true;

class _B {
  const _B(this.type, [this.model = 0, this.values = const {}]);
  final String type;
  final int model;
  final Map<String, double> values;
}

class _P {
  const _P(this.name, this.category, this.blocks, {this.inspiration, this.tip});
  final String name;
  final String category;
  final List<_B> blocks;
  final String? inspiration;
  final String? tip;
}

// ------------------------------------------------------------------ modelos
// Amplificadores
const _cleanUS = 0, _tweed = 1, _chime = 2, _plexi = 3, _brit800 = 4, _hiGain = 5, _m5150 = 6, _jazz = 7;
const _ssDrive = 8, _bassAmp = 9;
// Cubos
const _cTrans = 0, _cUS = 1, _cTweed = 2, _cChime = 3, _cJazz = 4, _cBrit = 5, _cBlues = 6, _cBass = 7;
// Caixas
const _k112 = 0, _k212 = 1, _kV30 = 2, _kGreen = 3, _k210 = 4, _k115 = 6, _k810 = 7;
// Tipos de delay / reverb
const _ana = 1.0, _tape = 2.0; // Digital é o padrão (0)
const _room = 0.0, _hall = 1.0, _plate = 2.0;

// ------------------------------------------------------------------ atalhos
_B gate([Map<String, double> v = const {}]) => _B('gate', 0, v);
_B comp([Map<String, double> v = const {}]) => _B('comp', 0, v);
_B boost([Map<String, double> v = const {}]) => _B('boost', 0, v);
_B od([Map<String, double> v = const {}]) => _B('od_green', 0, v);
_B dist([Map<String, double> v = const {}]) => _B('dist_rodent', 0, v);
_B fuzz([Map<String, double> v = const {}]) => _B('fuzz', 0, v);
_B metal([Map<String, double> v = const {}]) => _B('metal', 0, v);
_B geq([Map<String, double> v = const {}]) => _B('geq', 0, v);
_B wah([Map<String, double> v = const {}]) => _B('wah', 0, v);
_B octave([Map<String, double> v = const {}]) => _B('octave', 0, v);
_B chorus([Map<String, double> v = const {}]) => _B('chorus', 0, v);
_B flanger([Map<String, double> v = const {}]) => _B('flanger', 0, v);
_B phaser([Map<String, double> v = const {}]) => _B('phaser', 0, v);
_B trem([Map<String, double> v = const {}]) => _B('tremolo', 0, v);
_B vib([Map<String, double> v = const {}]) => _B('vibrato', 0, v);
_B delay([Map<String, double> v = const {}]) => _B('delay', 0, v);
_B reverb([Map<String, double> v = const {}]) => _B('reverb', 0, v);
_B amp(int m, [Map<String, double> v = const {}]) => _B('amp', m, v);
_B combo(int m, [Map<String, double> v = const {}]) => _B('combo', m, v);
_B cab(int m, [Map<String, double> v = const {}]) => _B('cab', m, v);

// ------------------------------------------------------------------ categorias
const catEssenciais = 'Essenciais';
const catSolos = 'Solos Lendários';
const catBases = 'Bases de Rock';
const catBlues = 'Blues';
const catMetal = 'Metal & Hard Rock';
const catAlt = 'Grunge & Alternativo';
const catFunk = 'Funk, Soul & Pop';
const catAmbient = 'Ambiente & Psicodelia';
const catJazz = 'Jazz & Fusion';
const catBrasil = 'Brasil';
const catBaixo = 'Baixo';

const factoryCategories = [
  catEssenciais,
  catSolos,
  catBases,
  catBlues,
  catMetal,
  catAlt,
  catFunk,
  catAmbient,
  catJazz,
  catBrasil,
  catBaixo,
];

final List<_P> _library = [
  // ================================================================ Essenciais
  _P('Limpo Cristalino', catEssenciais, [
    comp({'Limiar': -28, 'Razão': 3, 'Ganho': 6}),
    amp(_cleanUS, {'Ganho': 4, 'Agudos': 6}),
    cab(_k112, {'Microfone': 0.25}),
    chorus({'Mistura': 0.35, 'Velocidade': 0.6}),
    reverb({'Tipo': _hall, 'Mistura': 0.28, 'Decaimento': 2.5}),
  ]),
  _P('Blues Quente', catEssenciais, [
    od({'Drive': 3, 'Tom': 5.5, 'Nível': 5.5}),
    combo(_cTweed, {'Ganho': 5.5, 'Médios': 6}),
    delay({'Tipo': _ana, 'Tempo': 320, 'Mistura': 0.2, 'Repetições': 0.25}),
    reverb({'Mistura': 0.2}),
  ]),
  _P('Crunch Clássico', catEssenciais, [
    amp(_plexi, {'Ganho': 6.5, 'Médios': 7, 'Agudos': 6}),
    cab(_kGreen),
    reverb({'Mistura': 0.18}),
  ]),
  _P('Rock Anos 80', catEssenciais, [
    gate({'Limiar': -62}),
    amp(_brit800, {'Ganho': 7, 'Médios': 6.5, 'Presença': 6}),
    cab(_kV30, {'Microfone': 0.35}),
    delay({'Tempo': 420, 'Mistura': 0.22}),
    reverb({'Tipo': _hall, 'Mistura': 0.2}),
  ]),
  _P('Metal Moderno', catEssenciais, [
    gate({'Limiar': -55, 'Liberação': 60}),
    od({'Drive': 0, 'Tom': 6.5, 'Nível': 8}),
    amp(_m5150, {'Ganho': 6, 'Graves': 6, 'Médios': 4.5, 'Agudos': 6, 'Presença': 6}),
    cab(_kV30, {'Microfone': 0.3, 'Corte graves': 85}),
  ]),
  _P('Funk com Wah', catEssenciais, [
    comp({'Limiar': -34, 'Razão': 6, 'Ataque': 3, 'Ganho': 10}),
    wah({'Modo': 1, 'Sensibilidade': 0.6, 'Ressonância': 7}),
    amp(_jazz, {'Ganho': 5, 'Agudos': 6}),
    cab(_k212),
  ]),
  _P('Ambient', catEssenciais, [
    amp(_cleanUS, {'Ganho': 4.5, 'Master': 6.5}),
    cab(_k212),
    chorus({'Mistura': 0.4, 'Profundidade': 0.6, 'Velocidade': 0.3}),
    delay({'Tipo': _tape, 'Tempo': 520, 'Repetições': 0.55, 'Mistura': 0.35, 'Tom': 0.5}),
    reverb({'Tipo': _plate, 'Decaimento': 5, 'Mistura': 0.45, 'Pré-atraso': 40}),
  ]),
  _P('Fuzz Psicodélico', catEssenciais, [
    fuzz({'Fuzz': 8, 'Tom': 6, 'Nível': 6}),
    phaser({'Velocidade': 0.4, 'Estágios': 1, 'Mistura': 0.5}),
    amp(_chime, {'Ganho': 4.5}),
    cab(_k212),
    trem({'Velocidade': 4, 'Profundidade': 0.35}),
  ]),
  _P('Surf Tremolo', catEssenciais, [
    combo(_cUS, {'Ganho': 5, 'Agudos': 7, 'Master': 6}),
    trem({'Velocidade': 6.5, 'Profundidade': 0.6, 'Forma': 0.3}),
    reverb({'Tipo': _plate, 'Decaimento': 2.2, 'Mistura': 0.38}),
  ]),
  _P('Baixo Valvulado', catEssenciais, [
    comp({'Limiar': -30, 'Razão': 4, 'Ataque': 10, 'Ganho': 6}),
    amp(_bassAmp, {'Ganho': 4.5, 'Graves': 6}),
    cab(_k810),
  ]),
  _P('Cubinho de Estudo', catEssenciais, [
    combo(_cTrans, {'Ganho': 5}),
  ]),

  // ================================================================ Solos Lendários
  _P(
    'Escadaria Celestial',
    catSolos,
    [
      amp(_plexi, {'Ganho': 6.5, 'Graves': 4.5, 'Médios': 6.5, 'Agudos': 6.5, 'Presença': 6}),
      cab(_kGreen, {'Microfone': 0.25}),
      delay({'Tipo': _ana, 'Tempo': 270, 'Repetições': 0.2, 'Mistura': 0.15}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Stairway to Heaven — Led Zeppelin',
    tip: 'Captador da ponte, volume da guitarra no máximo. Para as bases, baixe o volume da guitarra.',
  ),
  _P(
    'Confortavelmente Solo',
    catSolos,
    [
      comp({'Limiar': -26, 'Razão': 3, 'Ganho': 4, 'Mistura': 0.7}),
      fuzz({'Fuzz': 6.5, 'Tom': 6.5, 'Nível': 4.5}),
      amp(_cleanUS, {'Ganho': 5.5, 'Graves': 5, 'Médios': 5.5, 'Agudos': 6, 'Master': 5}),
      cab(_kV30, {'Microfone': 0.35}),
      delay({'Tempo': 440, 'Repetições': 0.35, 'Mistura': 0.3, 'Tom': 0.55}),
      reverb({'Tipo': _hall, 'Decaimento': 2.8, 'Mistura': 0.25}),
    ],
    inspiration: 'Comfortably Numb (2º solo) — Pink Floyd',
    tip: 'Bends largos e lentos no captador da ponte. O fuzz entra num amp limpo e alto.',
  ),
  _P(
    'Diamante Louco',
    catSolos,
    [
      comp({'Limiar': -30, 'Razão': 4, 'Ataque': 15, 'Ganho': 7}),
      boost({'Ganho': 5, 'Graves': -2, 'Agudos': 1}),
      amp(_cleanUS, {'Ganho': 5.5, 'Médios': 6, 'Agudos': 5.5, 'Master': 5}),
      cab(_kV30, {'Microfone': 0.4}),
      delay({'Tipo': _tape, 'Tempo': 380, 'Repetições': 0.3, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Decaimento': 3.5, 'Mistura': 0.35}),
    ],
    inspiration: 'Shine On You Crazy Diamond — Pink Floyd',
    tip: 'Notas longas e muito espaço entre as frases. O compressor segura a sustentação.',
  ),
  _P(
    'Hotel na Califórnia',
    catSolos,
    [
      od({'Drive': 4, 'Tom': 5.5, 'Nível': 6}),
      amp(_plexi, {'Ganho': 5.5, 'Médios': 6.5, 'Agudos': 6}),
      cab(_kGreen),
      delay({'Tipo': _ana, 'Tempo': 350, 'Repetições': 0.25, 'Mistura': 0.17}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Hotel California — Eagles',
    tip: 'Ótimo para duetos em terças: grave duas vozes no looper.',
  ),
  _P(
    'Sultões do Swing',
    catSolos,
    [
      comp({'Limiar': -32, 'Razão': 3, 'Ataque': 8, 'Ganho': 6}),
      amp(_cleanUS, {'Ganho': 5, 'Graves': 4.5, 'Médios': 6.5, 'Agudos': 6.5}),
      cab(_k112, {'Microfone': 0.3}),
      reverb({'Tipo': _room, 'Mistura': 0.18}),
    ],
    inspiration: 'Sultans of Swing — Dire Straits',
    tip: 'Posição intermediária (ponte + meio) e toque com os dedos, sem palheta.',
  ),
  _P(
    'Erupção',
    catSolos,
    [
      phaser({'Velocidade': 0.6, 'Profundidade': 0.5, 'Realimentação': 0.3, 'Mistura': 0.3}),
      amp(_plexi, {'Ganho': 9, 'Graves': 5, 'Médios': 6, 'Agudos': 6.5, 'Presença': 7}),
      cab(_kGreen, {'Microfone': 0.3}),
      delay({'Tipo': _tape, 'Tempo': 310, 'Repetições': 0.2, 'Mistura': 0.18}),
      reverb({'Tipo': _hall, 'Mistura': 0.28}),
    ],
    inspiration: 'Eruption — Van Halen',
    tip: 'O "brown sound": Plexi no talo, captador humbucker da ponte e tapping.',
  ),
  _P(
    'Pequena Asa',
    catSolos,
    [
      amp(_plexi, {'Ganho': 4.5, 'Graves': 5, 'Médios': 5.5, 'Agudos': 6}),
      cab(_kGreen),
      chorus({'Velocidade': 0.9, 'Profundidade': 0.7, 'Mistura': 0.45}),
      reverb({'Tipo': _room, 'Mistura': 0.2}),
    ],
    inspiration: 'Little Wing — Jimi Hendrix',
    tip: 'Captador do braço, acordes com bordaduras. O chorus lento imita a caixa rotativa.',
  ),
  _P(
    'Criança Vodu',
    catSolos,
    [
      wah({'Modo': 1, 'Sensibilidade': 0.7, 'Ressonância': 7}),
      fuzz({'Fuzz': 7, 'Tom': 5.5, 'Nível': 6}),
      amp(_plexi, {'Ganho': 6, 'Médios': 6, 'Agudos': 6.5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Voodoo Child (Slight Return) — Jimi Hendrix',
    tip: 'O wah automático segue a palhetada. Troque para Manual e arraste o pedal se preferir.',
  ),
  _P(
    'Tom de Mulher',
    catSolos,
    [
      amp(_plexi, {'Ganho': 7.5, 'Graves': 5.5, 'Médios': 6.5, 'Agudos': 2.5, 'Presença': 3.5}),
      cab(_kGreen, {'Microfone': 0.55}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Crossroads / Sunshine of Your Love — Cream',
    tip: 'Captador do braço com o tom da guitarra todo fechado: o "woman tone".',
  ),
  _P(
    'Pássaro Livre',
    catSolos,
    [
      amp(_plexi, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6.5, 'Presença': 6}),
      cab(_kGreen),
      delay({'Tempo': 280, 'Repetições': 0.15, 'Mistura': 0.12}),
      reverb({'Tipo': _hall, 'Mistura': 0.18}),
    ],
    inspiration: 'Free Bird — Lynyrd Skynyrd',
    tip: 'Para o solo final, adicione o Green Drive com Drive baixo e Nível alto.',
  ),
  _P(
    'Doce Criança',
    catSolos,
    [
      wah({'Modo': 0, 'Pedal': 0.7, 'Ressonância': 5}),
      amp(_brit800, {'Ganho': 6.5, 'Graves': 5, 'Médios': 7, 'Agudos': 6}),
      cab(_kV30),
      delay({'Tempo': 380, 'Repetições': 0.2, 'Mistura': 0.15}),
      reverb({'Tipo': _hall, 'Mistura': 0.18}),
    ],
    inspiration: "Sweet Child O' Mine — Guns N' Roses",
    tip: 'Captador do braço. O wah está "parado" num ponto (cocked wah); desligue-o para a introdução.',
  ),
  _P(
    'Chuva de Novembro',
    catSolos,
    [
      amp(_brit800, {'Ganho': 6, 'Graves': 5, 'Médios': 7, 'Agudos': 5.5}),
      cab(_kV30, {'Microfone': 0.4}),
      delay({'Tempo': 460, 'Repetições': 0.3, 'Mistura': 0.28}),
      reverb({'Tipo': _hall, 'Decaimento': 3, 'Mistura': 0.3}),
    ],
    inspiration: "November Rain — Guns N' Roses",
    tip: 'Captador do braço e vibrato largo nas notas longas.',
  ),
  _P(
    'Feitiço Latino',
    catSolos,
    [
      od({'Drive': 2, 'Tom': 5, 'Nível': 7}),
      amp(_hiGain, {'Ganho': 5, 'Graves': 5, 'Médios': 7.5, 'Agudos': 4.5, 'Presença': 4.5}),
      cab(_k112, {'Microfone': 0.45}),
      reverb({'Tipo': _hall, 'Mistura': 0.22}),
    ],
    inspiration: 'Black Magic Woman — Santana',
    tip: 'Captador do braço e notas sustentadas: o timbre "cantado".',
  ),
  _P(
    'Europa Cantante',
    catSolos,
    [
      od({'Drive': 2.5, 'Tom': 5, 'Nível': 7}),
      amp(_hiGain, {'Ganho': 5.5, 'Médios': 7.5, 'Agudos': 4.5, 'Presença': 4.5}),
      cab(_k112, {'Microfone': 0.45}),
      delay({'Tempo': 420, 'Repetições': 0.3, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Decaimento': 3.5, 'Mistura': 0.35}),
    ],
    inspiration: 'Europa (Earth\'s Cry Heaven\'s Smile) — Santana',
    tip: 'Deixe as notas soarem até realimentar; o delay e o reverb preenchem o espaço.',
  ),
  _P(
    'Penhascos de Dover',
    catSolos,
    [
      od({'Drive': 5, 'Tom': 4.5, 'Nível': 6}),
      amp(_plexi, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 4.5, 'Presença': 4}),
      cab(_kGreen, {'Microfone': 0.4}),
      delay({'Tipo': _ana, 'Tempo': 380, 'Repetições': 0.3, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Cliffs of Dover — Eric Johnson',
    tip: 'O "violin tone": captador do braço com o tom levemente fechado.',
  ),
  _P(
    'Surfando com o Alien',
    catSolos,
    [
      wah({'Modo': 0, 'Pedal': 0.55, 'Ressonância': 6}),
      od({'Drive': 6, 'Tom': 6, 'Nível': 6}),
      amp(_brit800, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 6}),
      cab(_kV30),
      delay({'Tempo': 350, 'Repetições': 0.25, 'Mistura': 0.2}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Surfing with the Alien — Joe Satriani',
    tip: 'Legato e alavanca. Ative o wah só nas frases mais agressivas.',
  ),
  _P(
    'Pelo Amor de Deus',
    catSolos,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5, 'Mistura': 0.6}),
      amp(_hiGain, {'Ganho': 6.5, 'Graves': 5, 'Médios': 6, 'Agudos': 6}),
      cab(_kV30),
      chorus({'Velocidade': 0.4, 'Profundidade': 0.3, 'Mistura': 0.2}),
      delay({'Tempo': 450, 'Repetições': 0.4, 'Mistura': 0.3}),
      reverb({'Tipo': _hall, 'Decaimento': 4, 'Mistura': 0.32}),
    ],
    inspiration: 'For the Love of God — Steve Vai',
    tip: 'Notas longas com vibrato e alavanca; deixe o delay cantar.',
  ),
  _P(
    'Rapsódia Boêmia',
    catSolos,
    [
      boost({'Ganho': 14, 'Graves': -5, 'Agudos': 6}),
      amp(_chime, {'Ganho': 7.5, 'Graves': 5, 'Médios': 6.5, 'Agudos': 5.5, 'Master': 7}),
      cab(_k212),
      delay({'Tempo': 300, 'Repetições': 0.15, 'Mistura': 0.12}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Bohemian Rhapsody — Queen',
    tip: 'Treble booster na frente de um classe A no talo. Captadores juntos (ponte + meio).',
  ),
  _P(
    'Chuva Púrpura',
    catSolos,
    [
      dist({'Distorção': 6, 'Filtro': 4.5, 'Nível': 6}),
      amp(_cleanUS, {'Ganho': 5, 'Médios': 6, 'Agudos': 5.5, 'Master': 6.5}),
      cab(_k212),
      chorus({'Velocidade': 0.5, 'Profundidade': 0.5, 'Mistura': 0.3}),
      delay({'Tempo': 420, 'Repetições': 0.35, 'Mistura': 0.3}),
      reverb({'Tipo': _hall, 'Decaimento': 4, 'Mistura': 0.42}),
    ],
    inspiration: 'Purple Rain — Prince',
    tip: 'Solo final: notas longas, bends lentos e muito reverb.',
  ),
  _P(
    'Calçadas de Paris',
    catSolos,
    [
      od({'Drive': 4, 'Tom': 5, 'Nível': 7}),
      amp(_brit800, {'Ganho': 6.5, 'Médios': 7, 'Agudos': 5.5}),
      cab(_kGreen),
      delay({'Tempo': 450, 'Repetições': 0.28, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Decaimento': 3, 'Mistura': 0.3}),
    ],
    inspiration: 'Parisienne Walkways — Gary Moore',
    tip: 'Captador do braço e aquela nota final sustentada até realimentar.',
  ),
  _P(
    'Estrela da Estrada',
    catSolos,
    [
      boost({'Ganho': 12, 'Graves': -4, 'Agudos': 5}),
      amp(_plexi, {'Ganho': 7.5, 'Médios': 6, 'Agudos': 7, 'Presença': 6.5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Highway Star — Deep Purple',
    tip: 'Palhetada alternada rápida, captador da ponte.',
  ),
  _P(
    'Senhor Corvo',
    catSolos,
    [
      dist({'Distorção': 5, 'Filtro': 3.5, 'Nível': 6}),
      amp(_brit800, {'Ganho': 7, 'Médios': 6.5, 'Agudos': 6}),
      cab(_kGreen),
      delay({'Tempo': 400, 'Repetições': 0.2, 'Mistura': 0.17}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Mr. Crowley — Ozzy Osbourne (Randy Rhoads)',
    tip: 'Escalas menores harmônicas e palhetada precisa.',
  ),

  // ================================================================ Bases de Rock
  _P(
    'Fumaça na Água',
    catBases,
    [
      boost({'Ganho': 8, 'Graves': -2, 'Agudos': 3}),
      amp(_plexi, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 6.5}),
      cab(_kGreen),
    ],
    inspiration: 'Smoke on the Water — Deep Purple',
    tip: 'Riff em quartas, tocado com os dedos ou palheta, captador da ponte.',
  ),
  _P(
    'Satisfação Garantida',
    catBases,
    [
      fuzz({'Fuzz': 6, 'Tom': 6.5, 'Nível': 6}),
      amp(_cleanUS, {'Ganho': 5, 'Agudos': 6}),
      cab(_k212),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: "(I Can't Get No) Satisfaction — The Rolling Stones",
    tip: 'Fuzz anos 60 fino e "buzzy": captador da ponte.',
  ),
  _P(
    'De Volta ao Preto',
    catBases,
    [
      amp(_plexi, {'Ganho': 5.5, 'Graves': 5, 'Médios': 6.5, 'Agudos': 6.5, 'Presença': 6}),
      cab(_kGreen, {'Microfone': 0.3}),
      reverb({'Tipo': _room, 'Mistura': 0.1}),
    ],
    inspiration: 'Back in Black — AC/DC',
    tip: 'Menos ganho do que parece: o peso vem da palhetada forte e das cordas grossas.',
  ),
  _P(
    'Rodovia pro Inferno',
    catBases,
    [
      amp(_brit800, {'Ganho': 5.5, 'Médios': 6.5, 'Agudos': 6.5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: 'Highway to Hell — AC/DC',
    tip: 'Acordes abertos com muito ataque; deixe soar.',
  ),
  _P('Noite Toda de Rock', catBases, [
    amp(_brit800, {'Ganho': 6, 'Médios': 6, 'Agudos': 6}),
    cab(_kV30),
    reverb({'Tipo': _room, 'Mistura': 0.12}),
  ], inspiration: 'Rock and Roll All Nite — Kiss'),
  _P(
    'Exército de Sete Nações',
    catBases,
    [
      octave({'Direto': 0.5, 'Oitava -1': 0.8, 'Tom': 0.5}),
      fuzz({'Fuzz': 7, 'Tom': 5, 'Nível': 6}),
      amp(_cleanUS, {'Ganho': 6, 'Graves': 6}),
      cab(_kV30),
    ],
    inspiration: 'Seven Nation Army — The White Stripes',
    tip: 'Guitarra soando como baixo: o octaver uma oitava abaixo com fuzz.',
  ),
  _P(
    'Mais que um Sentimento',
    catBases,
    [
      comp({'Limiar': -30, 'Razão': 4, 'Ganho': 6}),
      amp(_brit800, {'Ganho': 6, 'Médios': 7, 'Agudos': 5.5}),
      cab(_kV30),
      chorus({'Velocidade': 0.5, 'Profundidade': 0.4, 'Mistura': 0.25}),
      delay({'Tempo': 120, 'Repetições': 0.1, 'Mistura': 0.15}),
      reverb({'Tipo': _hall, 'Mistura': 0.22}),
    ],
    inspiration: 'More Than a Feeling — Boston',
    tip: 'Distorção comprimida e "polida", com chorus e um eco curto.',
  ),
  _P(
    'Barracuda',
    catBases,
    [
      amp(_brit800, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 6}),
      cab(_kV30),
      delay({'Tempo': 130, 'Repetições': 0.25, 'Mistura': 0.32}),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: 'Barracuda — Heart',
    tip: 'O eco curto cria o galope; abafe as cordas com a mão direita.',
  ),
  _P(
    'Dinheiro por Nada',
    catBases,
    [
      wah({'Modo': 0, 'Pedal': 0.62, 'Ressonância': 5}),
      amp(_brit800, {'Ganho': 6.5, 'Graves': 4.5, 'Médios': 6.5, 'Agudos': 5.5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: 'Money for Nothing — Dire Straits',
    tip: 'O wah parado no meio dá o timbre anasalado do riff.',
  ),
  _P(
    'Blitz Punk',
    catBases,
    [
      amp(_brit800, {'Ganho': 7, 'Graves': 6, 'Médios': 5, 'Agudos': 6}),
      cab(_kV30),
    ],
    inspiration: 'Blitzkrieg Bop — Ramones',
    tip: 'Só palhetadas para baixo, acordes de quinta e muita energia.',
  ),
  _P('Cidade Paraíso', catBases, [
    amp(_brit800, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6}),
    cab(_kV30),
    delay({'Tempo': 360, 'Repetições': 0.15, 'Mistura': 0.12}),
    reverb({'Tipo': _hall, 'Mistura': 0.15}),
  ], inspiration: "Paradise City — Guns N' Roses"),
  _P(
    'Caxemira',
    catBases,
    [
      amp(_plexi, {'Ganho': 6.5, 'Graves': 5.5, 'Médios': 6, 'Agudos': 6}),
      cab(_kGreen),
      phaser({'Velocidade': 0.2, 'Profundidade': 0.4, 'Mistura': 0.2}),
      reverb({'Tipo': _hall, 'Decaimento': 2.5, 'Mistura': 0.22}),
    ],
    inspiration: 'Kashmir — Led Zeppelin',
    tip: 'Afinação DADGAD; o phaser lento dá o movimento.',
  ),
  _P(
    'Amor Demais',
    catBases,
    [
      combo(_cTweed, {'Ganho': 7.5, 'Médios': 6, 'Agudos': 6}),
      delay({'Tipo': _tape, 'Tempo': 250, 'Repetições': 0.2, 'Mistura': 0.15}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Whole Lotta Love — Led Zeppelin',
    tip: 'Um combo pequeno no talo: é assim que o riff soa gordo.',
  ),

  // ================================================================ Blues
  _P(
    'Inundação Texana',
    catBlues,
    [
      od({'Drive': 2, 'Tom': 6, 'Nível': 6}),
      amp(_cleanUS, {'Ganho': 6.5, 'Graves': 5.5, 'Médios': 5, 'Agudos': 6}),
      cab(_k210, {'Microfone': 0.3}),
      reverb({'Tipo': _plate, 'Mistura': 0.2}),
    ],
    inspiration: 'Texas Flood — Stevie Ray Vaughan',
    tip: 'Cordas grossas, palhetada forte e captador do braço.',
  ),
  _P(
    'Orgulho e Alegria',
    catBlues,
    [
      od({'Drive': 2.5, 'Tom': 6, 'Nível': 7}),
      combo(_cBlues, {'Ganho': 6, 'Médios': 5.5, 'Agudos': 6}),
      reverb({'Tipo': _plate, 'Mistura': 0.18}),
    ],
    inspiration: 'Pride and Joy — Stevie Ray Vaughan',
    tip: 'Shuffle com as cordas soltas abafadas pela palma da mão.',
  ),
  _P(
    'A Emoção Acabou',
    catBlues,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
      amp(_jazz, {'Ganho': 6, 'Graves': 5, 'Médios': 7, 'Agudos': 6}),
      cab(_k212),
      reverb({'Tipo': _hall, 'Mistura': 0.25}),
    ],
    inspiration: 'The Thrill Is Gone — B.B. King',
    tip: 'Poucas notas, vibrato de pulso e captador do braço.',
  ),
  _P('Ainda Tenho o Blues', catBlues, [
    od({'Drive': 4, 'Tom': 5, 'Nível': 7}),
    amp(_brit800, {'Ganho': 6, 'Médios': 7, 'Agudos': 5.5}),
    cab(_kGreen),
    delay({'Tempo': 420, 'Repetições': 0.2, 'Mistura': 0.2}),
    reverb({'Tipo': _hall, 'Mistura': 0.3}),
  ], inspiration: 'Still Got the Blues — Gary Moore'),
  _P(
    'Homem Hoochie Coochie',
    catBlues,
    [
      combo(_cTweed, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 5.5}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Hoochie Coochie Man — Muddy Waters',
    tip: 'Blues de Chicago: combo tweed pequeno e palhetada com o polegar.',
  ),
  _P(
    'Casa Vermelha',
    catBlues,
    [
      amp(_plexi, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.18}),
    ],
    inspiration: 'Red House — Jimi Hendrix',
    tip: 'Controle o drive pelo volume da guitarra: baixo nas bases, cheio nos solos.',
  ),
  _P(
    'Gelo Cortante',
    catBlues,
    [
      amp(_cleanUS, {'Ganho': 5.5, 'Graves': 4, 'Médios': 6, 'Agudos': 8, 'Presença': 6.5}),
      cab(_k210),
      reverb({'Tipo': _plate, 'Mistura': 0.2}),
    ],
    inspiration: 'Frosty — Albert Collins',
    tip: 'Telecaster no captador da ponte, tocando com os dedos: ataque "gelado".',
  ),
  _P('Amor Antigo', catBlues, [
    combo(_cUS, {'Ganho': 6, 'Médios': 6, 'Agudos': 6}),
    chorus({'Velocidade': 0.8, 'Profundidade': 0.5, 'Mistura': 0.3}),
    reverb({'Tipo': _hall, 'Mistura': 0.25}),
  ], inspiration: 'Old Love — Eric Clapton'),
  _P(
    'Nascido Sob Mau Signo',
    catBlues,
    [
      amp(_jazz, {'Ganho': 6.5, 'Médios': 7, 'Agudos': 6.5}),
      cab(_k212),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Born Under a Bad Sign — Albert King',
    tip: 'Bends enormes: amp transistorizado limpo e alto.',
  ),
  _P(
    'Gravidade',
    catBlues,
    [
      od({'Drive': 2.5, 'Tom': 5.5, 'Nível': 6.5}),
      amp(_cleanUS, {'Ganho': 5.5, 'Médios': 5.5, 'Agudos': 5.5}),
      cab(_k112),
      delay({'Tipo': _ana, 'Tempo': 380, 'Repetições': 0.15, 'Mistura': 0.12}),
      reverb({'Tipo': _plate, 'Mistura': 0.25}),
    ],
    inspiration: 'Gravity — John Mayer',
    tip: 'Posição 4 da Strat (ponte + meio) e dinâmica: toque leve, depois forte.',
  ),

  // ================================================================ Metal & Hard Rock
  _P(
    'Mestre dos Bonecos',
    catMetal,
    [
      gate({'Limiar': -55, 'Liberação': 50}),
      od({'Drive': 0, 'Tom': 6, 'Nível': 8}),
      amp(_hiGain, {'Ganho': 6.5, 'Graves': 6, 'Médios': 3, 'Agudos': 6.5}),
      cab(_kV30),
    ],
    inspiration: 'Master of Puppets — Metallica',
    tip: 'Palhetada alternada abafada (palm mute) e graves cheios.',
  ),
  _P('Desvanecer no Escuro', catMetal, [
    amp(_hiGain, {'Ganho': 6, 'Médios': 5, 'Agudos': 6}),
    cab(_kV30),
    delay({'Tempo': 450, 'Repetições': 0.25, 'Mistura': 0.25}),
    reverb({'Tipo': _hall, 'Mistura': 0.22}),
  ], inspiration: 'Fade to Black (solo) — Metallica'),
  _P(
    'Areia de Sono',
    catMetal,
    [
      gate({'Limiar': -55}),
      wah({'Modo': 0, 'Pedal': 0.6, 'Ressonância': 6}),
      amp(_hiGain, {'Ganho': 6.5, 'Graves': 6, 'Médios': 4, 'Agudos': 6}),
      cab(_kV30),
      delay({'Tempo': 400, 'Repetições': 0.15, 'Mistura': 0.15}),
    ],
    inspiration: 'Enter Sandman — Metallica',
    tip: 'Desligue o wah para o riff e ligue no solo.',
  ),
  _P('Paranoia Pesada', catMetal, [
    boost({'Ganho': 12, 'Graves': -3, 'Agudos': 4}),
    amp(_plexi, {'Ganho': 7, 'Graves': 5.5, 'Médios': 7, 'Agudos': 6}),
    cab(_kGreen),
  ], inspiration: 'Paranoid — Black Sabbath'),
  _P(
    'Homem de Ferro',
    catMetal,
    [
      fuzz({'Fuzz': 6, 'Tom': 4.5, 'Nível': 6}),
      amp(_plexi, {'Ganho': 6, 'Graves': 7, 'Médios': 6, 'Agudos': 5}),
      cab(_kGreen),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: 'Iron Man — Black Sabbath',
    tip: 'Afinação mais baixa deixa o riff ainda mais pesado.',
  ),
  _P(
    'Corra pras Colinas',
    catMetal,
    [
      amp(_brit800, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6}),
      cab(_kGreen),
      delay({'Tempo': 380, 'Repetições': 0.15, 'Mistura': 0.13}),
      reverb({'Tipo': _hall, 'Mistura': 0.15}),
    ],
    inspiration: 'Run to the Hills / The Trooper — Iron Maiden',
    tip: 'Galopes e harmonias em duas guitarras (use o looper).',
  ),
  _P('Matador de Dor', catMetal, [
    gate({'Limiar': -58}),
    od({'Drive': 0, 'Tom': 6, 'Nível': 8}),
    amp(_brit800, {'Ganho': 7.5, 'Médios': 6, 'Agudos': 6.5}),
    cab(_kV30),
    delay({'Tempo': 420, 'Repetições': 0.15, 'Mistura': 0.15}),
  ], inspiration: 'Painkiller — Judas Priest'),
  _P(
    'Enchentes',
    catMetal,
    [
      gate({'Limiar': -55}),
      amp(_ssDrive, {'Ganho': 8, 'Graves': 7, 'Médios': 3, 'Agudos': 7}),
      cab(_kV30),
      delay({'Tempo': 400, 'Repetições': 0.3, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Decaimento': 3, 'Mistura': 0.3}),
    ],
    inspiration: 'Floods (solo) — Pantera',
    tip: 'Distorção transistorizada, médios cavados e harmônicos artificiais.',
  ),
  _P('Caubóis do Inferno', catMetal, [
    gate({'Limiar': -52, 'Liberação': 40}),
    amp(_ssDrive, {'Ganho': 7.5, 'Graves': 7, 'Médios': 2.5, 'Agudos': 7}),
    cab(_kV30),
  ], inspiration: 'Cowboys from Hell — Pantera'),
  _P(
    'Chuva de Sangue',
    catMetal,
    [
      gate({'Limiar': -52}),
      od({'Drive': 0, 'Tom': 6.5, 'Nível': 8}),
      amp(_brit800, {'Ganho': 8, 'Graves': 6, 'Médios': 5, 'Agudos': 6.5}),
      cab(_kV30),
    ],
    inspiration: 'Raining Blood — Slayer',
    tip: 'Tremolo picking rápido no captador da ponte.',
  ),
  _P('Guerras Santas', catMetal, [
    gate({'Limiar': -55}),
    amp(_brit800, {'Ganho': 7, 'Graves': 5.5, 'Médios': 6, 'Agudos': 6.5}),
    cab(_kV30),
  ], inspiration: 'Holy Wars... The Punishment Due — Megadeth'),
  _P(
    'Djent Simbiótico',
    catMetal,
    [
      gate({'Limiar': -50, 'Liberação': 30}),
      od({'Drive': 0, 'Tom': 7, 'Nível': 8}),
      amp(_m5150, {'Ganho': 6, 'Graves': 6, 'Médios': 5, 'Agudos': 6.5}),
      cab(_kV30, {'Corte graves': 100, 'Corte agudos': 7000}),
    ],
    inspiration: 'Bleed — Meshuggah',
    tip: 'Para guitarras de 7/8 cordas: graves apertados e ataque seco.',
  ),
  _P(
    'Aqui Vou Eu de Novo',
    catMetal,
    [
      amp(_brit800, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6}),
      cab(_kV30),
      chorus({'Velocidade': 0.6, 'Profundidade': 0.4, 'Mistura': 0.25}),
      delay({'Tempo': 400, 'Repetições': 0.2, 'Mistura': 0.2}),
      reverb({'Tipo': _hall, 'Mistura': 0.3}),
    ],
    inspiration: 'Here I Go Again — Whitesnake',
    tip: 'O "hard rock de arena" dos anos 80: chorus e reverb grande.',
  ),
  _P(
    'Bem-vindo à Selva',
    catMetal,
    [
      amp(_brit800, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6}),
      cab(_kV30),
      delay({'Tempo': 400, 'Repetições': 0.6, 'Mistura': 0.4}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: "Welcome to the Jungle — Guns N' Roses",
    tip: 'A introdução vive do delay com muitas repetições; desligue-o para o riff.',
  ),

  // ================================================================ Grunge & Alternativo
  _P(
    'Espírito Adolescente',
    catAlt,
    [
      dist({'Distorção': 6.5, 'Filtro': 4, 'Nível': 6}),
      amp(_cleanUS, {'Ganho': 5.5, 'Graves': 6, 'Médios': 5}),
      cab(_kV30),
    ],
    inspiration: 'Smells Like Teen Spirit (refrão) — Nirvana',
    tip: 'Pedal de distorção num amp limpo: power chords cheios.',
  ),
  _P('Espírito Adolescente (verso)', catAlt, [
    amp(_cleanUS, {'Ganho': 4, 'Agudos': 5.5}),
    cab(_kV30),
    chorus({'Velocidade': 0.6, 'Profundidade': 0.7, 'Mistura': 0.5}),
  ], inspiration: 'Smells Like Teen Spirit (verso) — Nirvana'),
  _P(
    'Venha Como Você É',
    catAlt,
    [
      amp(_cleanUS, {'Ganho': 5, 'Graves': 5.5}),
      cab(_kV30),
      chorus({'Velocidade': 1.2, 'Profundidade': 0.8, 'Mistura': 0.5}),
    ],
    inspiration: 'Come as You Are — Nirvana',
    tip: 'Chorus fundo e "aquoso" no riff de cordas graves.',
  ),
  _P(
    'Sol de Buraco Negro',
    catAlt,
    [
      amp(_cleanUS, {'Ganho': 5, 'Médios': 6}),
      cab(_k212),
      vib({'Velocidade': 6, 'Profundidade': 0.25}),
      trem({'Velocidade': 6, 'Profundidade': 0.15, 'Forma': 0}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Black Hole Sun — Soundgarden',
    tip: 'Vibrato + tremolo imitam uma caixa rotativa (Leslie).',
  ),
  _P(
    'Homem na Caixa',
    catAlt,
    [
      wah({'Modo': 0, 'Pedal': 0.5, 'Ressonância': 7}),
      amp(_hiGain, {'Ganho': 6, 'Médios': 5.5, 'Agudos': 5.5}),
      cab(_kV30),
    ],
    inspiration: 'Man in the Box — Alice in Chains',
    tip: 'Wah parado, quase "falando", no riff principal.',
  ),
  _P('Zumbi', catAlt, [
    dist({'Distorção': 6, 'Filtro': 4.5, 'Nível': 6}),
    amp(_tweed, {'Ganho': 5.5}),
    cab(_kV30),
    reverb({'Tipo': _hall, 'Mistura': 0.2}),
  ], inspiration: 'Zombie — The Cranberries'),
  _P('Supernova de Champanhe', catAlt, [
    amp(_plexi, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 6}),
    cab(_kGreen),
    phaser({'Velocidade': 0.3, 'Profundidade': 0.6, 'Mistura': 0.3}),
    delay({'Tempo': 420, 'Repetições': 0.3, 'Mistura': 0.2}),
    reverb({'Tipo': _hall, 'Decaimento': 3, 'Mistura': 0.3}),
  ], inspiration: 'Champagne Supernova — Oasis'),
  _P(
    'Esquisito',
    catAlt,
    [
      dist({'Distorção': 7, 'Filtro': 4, 'Nível': 6.5}),
      amp(_cleanUS, {'Ganho': 5, 'Agudos': 5.5}),
      cab(_k212),
    ],
    inspiration: 'Creep — Radiohead',
    tip: 'Ligue a distorção só no "chunk" antes do refrão.',
  ),
  _P('Andróide Paranoico', catAlt, [
    dist({'Distorção': 7, 'Filtro': 5, 'Nível': 6}),
    amp(_cleanUS, {'Ganho': 5.5, 'Médios': 6}),
    cab(_k212),
    delay({'Tempo': 300, 'Repetições': 0.2, 'Mistura': 0.15}),
  ], inspiration: 'Paranoid Android — Radiohead'),
  _P(
    'Senhor Lado Bom',
    catAlt,
    [
      amp(_chime, {'Ganho': 5.5, 'Agudos': 6.5}),
      cab(_k212),
      chorus({'Velocidade': 0.7, 'Profundidade': 0.3, 'Mistura': 0.2}),
      delay({'Tempo': 350, 'Repetições': 0.2, 'Mistura': 0.2}),
    ],
    inspiration: 'Mr. Brightside — The Killers',
    tip: 'Palhetada constante em colcheias, notas soltas soando.',
  ),

  // ================================================================ Funk, Soul & Pop
  _P(
    'Entrega Tudo',
    catFunk,
    [
      comp({'Limiar': -32, 'Razão': 4, 'Ataque': 4, 'Ganho': 7}),
      amp(_plexi, {'Ganho': 5, 'Médios': 6, 'Agudos': 6.5}),
      cab(_kGreen),
    ],
    inspiration: 'Give It Away — Red Hot Chili Peppers',
    tip: 'Funk com cordas abafadas e palhetada "solta" de pulso.',
  ),
  _P(
    'Debaixo da Ponte',
    catFunk,
    [
      amp(_plexi, {'Ganho': 3.5, 'Médios': 5.5, 'Agudos': 6}),
      cab(_kGreen),
      chorus({'Velocidade': 0.5, 'Profundidade': 0.3, 'Mistura': 0.2}),
      reverb({'Tipo': _room, 'Mistura': 0.25}),
    ],
    inspiration: 'Under the Bridge — Red Hot Chili Peppers',
    tip: 'Acordes com bordaduras de Hendrix, toque delicado.',
  ),
  _P(
    'Sortudo',
    catFunk,
    [
      comp({'Limiar': -36, 'Razão': 6, 'Ataque': 2, 'Ganho': 10}),
      amp(_jazz, {'Ganho': 4, 'Graves': 4, 'Médios': 5, 'Agudos': 6.5}),
      cab(_k212),
      reverb({'Tipo': _room, 'Mistura': 0.1}),
    ],
    inspiration: 'Get Lucky — Daft Punk (Nile Rodgers)',
    tip: 'Strat no captador do meio, semicolcheias "chiclete" muito regulares.',
  ),
  _P(
    'Superstição',
    catFunk,
    [
      comp({'Limiar': -32, 'Razão': 5, 'Ganho': 8}),
      wah({'Modo': 1, 'Sensibilidade': 0.65, 'Ressonância': 8}),
      amp(_jazz, {'Ganho': 5, 'Agudos': 6}),
      cab(_k212),
    ],
    inspiration: 'Superstition — Stevie Wonder',
    tip: 'Imite o clavinete: notas curtas e abafadas.',
  ),
  _P(
    'Tema do Detetive',
    catFunk,
    [
      comp({'Limiar': -32, 'Razão': 5, 'Ganho': 8}),
      wah({'Modo': 1, 'Sensibilidade': 0.8, 'Ressonância': 8}),
      amp(_cleanUS, {'Ganho': 4.5, 'Agudos': 6}),
      cab(_k112),
    ],
    inspiration: 'Theme from Shaft — Isaac Hayes',
    tip: 'Semicolcheias abafadas; o wah automático faz o "chicka-wah".',
  ),
  _P(
    'Cada Respiração',
    catFunk,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
      amp(_jazz, {'Ganho': 4, 'Agudos': 6}),
      cab(_k212),
      chorus({'Velocidade': 0.7, 'Profundidade': 0.5, 'Mistura': 0.45}),
      delay({'Tempo': 300, 'Repetições': 0.25, 'Mistura': 0.2}),
    ],
    inspiration: 'Every Breath You Take — The Police',
    tip: 'Arpejos com notas abertas; o chorus faz todo o clima.',
  ),
  _P('Mensagem na Garrafa', catFunk, [
    comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
    amp(_cleanUS, {'Ganho': 4.5, 'Agudos': 6}),
    cab(_k212),
    chorus({'Velocidade': 0.8, 'Profundidade': 0.6, 'Mistura': 0.4}),
    delay({'Tempo': 330, 'Repetições': 0.2, 'Mistura': 0.18}),
  ], inspiration: 'Message in a Bottle — The Police'),
  _P('Funk do Centro', catFunk, [
    comp({'Limiar': -34, 'Razão': 5, 'Ataque': 3, 'Ganho': 9}),
    amp(_cleanUS, {'Ganho': 4, 'Graves': 4, 'Agudos': 7}),
    cab(_k112),
  ], inspiration: 'Uptown Funk — Mark Ronson ft. Bruno Mars'),
  _P(
    'Máquina do Ritmo',
    catFunk,
    [
      comp({'Limiar': -34, 'Razão': 5, 'Ataque': 3, 'Ganho': 9}),
      amp(_cleanUS, {'Ganho': 4, 'Graves': 3.5, 'Médios': 6, 'Agudos': 7.5}),
      cab(_k210),
    ],
    inspiration: 'Sex Machine — James Brown',
    tip: 'Acorde de nona no alto do braço, palhetada curta e seca.',
  ),

  // ================================================================ Ambiente & Psicodelia
  _P(
    'Ruas Sem Nome',
    catAmbient,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
      amp(_chime, {'Ganho': 4.5, 'Agudos': 6.5}),
      cab(_k212),
      delay({'Tempo': 375, 'Repetições': 0.45, 'Mistura': 0.4, 'Tom': 0.6}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Where the Streets Have No Name — U2',
    tip: 'Delay em colcheia pontuada (375 ms a 120 bpm). Use o tap tempo se a música mudar.',
  ),
  _P(
    'Com ou Sem Você',
    catAmbient,
    [
      amp(_chime, {'Ganho': 5}),
      cab(_k212),
      delay({'Tempo': 480, 'Repetições': 0.6, 'Mistura': 0.4}),
      reverb({'Tipo': _plate, 'Decaimento': 6, 'Mistura': 0.5}),
    ],
    inspiration: 'With or Without You — U2',
    tip: 'Notas longas que se fundem numa nuvem de eco.',
  ),
  _P(
    'Parede de Som',
    catAmbient,
    [
      fuzz({'Fuzz': 8, 'Tom': 5, 'Nível': 6}),
      vib({'Velocidade': 4, 'Profundidade': 0.4}),
      amp(_cleanUS, {'Ganho': 5.5}),
      cab(_k212),
      reverb({'Tipo': _hall, 'Decaimento': 7, 'Mistura': 0.5}),
    ],
    inspiration: 'Only Shallow — My Bloody Valentine',
    tip: 'Shoegaze: acordes cheios com a alavanca sempre balançando.',
  ),
  _P(
    'Céu em Expansão',
    catAmbient,
    [
      amp(_cleanUS, {'Ganho': 4, 'Agudos': 6}),
      cab(_k212),
      delay({'Tempo': 450, 'Repetições': 0.5, 'Mistura': 0.35}),
      reverb({'Tipo': _hall, 'Decaimento': 6, 'Mistura': 0.45}),
    ],
    inspiration: 'Your Hand in Mine — Explosions in the Sky',
    tip: 'Pós-rock: tremolo picking em notas agudas sobre o reverb.',
  ),
  _P('Ecos Cósmicos', catAmbient, [
    amp(_cleanUS, {'Ganho': 5}),
    cab(_kV30),
    flanger({'Velocidade': 0.1, 'Profundidade': 0.6, 'Realimentação': 0.4, 'Mistura': 0.3}),
    delay({'Tipo': _tape, 'Tempo': 560, 'Repetições': 0.5, 'Mistura': 0.35}),
    reverb({'Tipo': _hall, 'Decaimento': 5, 'Mistura': 0.4}),
  ], inspiration: 'Echoes — Pink Floyd'),
  _P('Coelho Branco', catAmbient, [
    fuzz({'Fuzz': 6.5, 'Tom': 5.5, 'Nível': 6}),
    amp(_chime, {'Ganho': 5}),
    cab(_k212),
    reverb({'Tipo': _plate, 'Decaimento': 3, 'Mistura': 0.35}),
  ], inspiration: 'White Rabbit — Jefferson Airplane'),
  _P('Amanhã Nunca Sabe', catAmbient, [
    fuzz({'Fuzz': 5.5, 'Tom': 6, 'Nível': 6}),
    flanger({'Velocidade': 0.25, 'Profundidade': 0.7, 'Realimentação': 0.5, 'Mistura': 0.4}),
    amp(_chime, {'Ganho': 5.5}),
    cab(_k212),
    delay({'Tipo': _tape, 'Tempo': 280, 'Repetições': 0.35, 'Mistura': 0.25}),
  ], inspiration: 'Tomorrow Never Knows — The Beatles'),
  _P('Albatroz', catAmbient, [
    amp(_cleanUS, {'Ganho': 4.5, 'Médios': 5.5}),
    cab(_k112),
    trem({'Velocidade': 5, 'Profundidade': 0.3, 'Forma': 0.1}),
    reverb({'Tipo': _plate, 'Decaimento': 3.5, 'Mistura': 0.4}),
  ], inspiration: 'Albatross — Fleetwood Mac'),
  _P('Respire', catAmbient, [
    comp({'Limiar': -28, 'Razão': 3, 'Ganho': 5}),
    amp(_cleanUS, {'Ganho': 5}),
    cab(_kV30),
    chorus({'Velocidade': 0.4, 'Profundidade': 0.4, 'Mistura': 0.25}),
    delay({'Tempo': 400, 'Repetições': 0.3, 'Mistura': 0.25}),
    reverb({'Tipo': _hall, 'Decaimento': 3.5, 'Mistura': 0.35}),
  ], inspiration: 'Breathe — Pink Floyd'),

  // ================================================================ Jazz & Fusion
  _P(
    'Folhas de Outono',
    catJazz,
    [
      amp(_jazz, {'Ganho': 4.5, 'Graves': 6, 'Médios': 5, 'Agudos': 3.5, 'Master': 6.5}),
      cab(_k212, {'Microfone': 0.5}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Autumn Leaves — Joe Pass',
    tip: 'Captador do braço e tom fechado; acordes com baixo caminhante.',
  ),
  _P(
    'Quatro em Seis',
    catJazz,
    [
      amp(_jazz, {'Ganho': 4.5, 'Graves': 6, 'Médios': 5.5, 'Agudos': 3, 'Master': 7}),
      cab(_k212, {'Microfone': 0.55}),
      reverb({'Tipo': _room, 'Mistura': 0.12}),
    ],
    inspiration: 'Four on Six — Wes Montgomery',
    tip: 'Oitavas tocadas com o polegar.',
  ),
  _P('Vida Brilhante', catJazz, [
    combo(_cJazz, {'Ganho': 4.5, 'Graves': 5.5, 'Agudos': 4, 'Master': 6.5}),
    chorus({'Velocidade': 0.5, 'Profundidade': 0.5, 'Mistura': 0.35}),
    delay({'Tempo': 350, 'Repetições': 0.25, 'Mistura': 0.2}),
    reverb({'Tipo': _hall, 'Mistura': 0.3}),
  ], inspiration: 'Bright Size Life — Pat Metheny'),
  _P(
    'Rodovia Livre',
    catJazz,
    [
      amp(_plexi, {'Ganho': 6, 'Médios': 6, 'Agudos': 5.5}),
      cab(_kGreen),
      delay({'Tempo': 300, 'Repetições': 0.15, 'Mistura': 0.12}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Freeway Jam — Jeff Beck',
    tip: 'Sem palheta, usando o volume e a alavanca para "cantar" as notas.',
  ),
  _P(
    'Diabo Leva o Último',
    catJazz,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
      amp(_hiGain, {'Ganho': 6, 'Médios': 6, 'Agudos': 5}),
      cab(_k212),
      chorus({'Velocidade': 0.4, 'Profundidade': 0.3, 'Mistura': 0.2}),
      delay({'Tempo': 400, 'Repetições': 0.25, 'Mistura': 0.2}),
      reverb({'Tipo': _hall, 'Mistura': 0.25}),
    ],
    inspiration: 'Devil Take the Hindmost — Allan Holdsworth',
    tip: 'Legato total (quase sem palhetar) e muita sustentação.',
  ),
  _P('Vai e Vem', catJazz, [
    od({'Drive': 3, 'Tom': 5, 'Nível': 6}),
    amp(_cleanUS, {'Ganho': 5, 'Médios': 6}),
    cab(_k112),
    chorus({'Velocidade': 0.6, 'Profundidade': 0.3, 'Mistura': 0.2}),
    reverb({'Tipo': _room, 'Mistura': 0.15}),
  ], inspiration: 'A Go Go — John Scofield'),

  // ================================================================ Brasil
  _P(
    'Raízes',
    catBrasil,
    [
      gate({'Limiar': -52, 'Liberação': 40}),
      od({'Drive': 0, 'Tom': 6, 'Nível': 8}),
      amp(_m5150, {'Ganho': 6.5, 'Graves': 7, 'Médios': 4, 'Agudos': 6}),
      cab(_kV30),
    ],
    inspiration: 'Roots Bloody Roots — Sepultura',
    tip: 'Afinação bem baixa (B ou C) e palhetada só para baixo.',
  ),
  _P('Tempo Perdido', catBrasil, [
    combo(_cChime, {'Ganho': 5, 'Agudos': 6}),
    chorus({'Velocidade': 0.6, 'Profundidade': 0.4, 'Mistura': 0.3}),
    delay({'Tempo': 340, 'Repetições': 0.2, 'Mistura': 0.15}),
    reverb({'Tipo': _hall, 'Mistura': 0.2}),
  ], inspiration: 'Tempo Perdido — Legião Urbana'),
  _P(
    'Alagados',
    catBrasil,
    [
      comp({'Limiar': -32, 'Razão': 4, 'Ganho': 7}),
      amp(_cleanUS, {'Ganho': 4, 'Agudos': 7}),
      cab(_k112),
      chorus({'Velocidade': 0.7, 'Profundidade': 0.3, 'Mistura': 0.2}),
      delay({'Tempo': 280, 'Repetições': 0.2, 'Mistura': 0.18}),
    ],
    inspiration: 'Alagados — Os Paralamas do Sucesso',
    tip: 'Ska/reggae: acordes curtos no contratempo.',
  ),
  _P('Polícia', catBrasil, [
    amp(_brit800, {'Ganho': 6.5, 'Médios': 6, 'Agudos': 6}),
    cab(_kV30),
  ], inspiration: 'Polícia — Titãs'),
  _P(
    'Mulher de Fases',
    catBrasil,
    [
      gate({'Limiar': -58}),
      amp(_brit800, {'Ganho': 7, 'Graves': 6, 'Médios': 5.5, 'Agudos': 6}),
      cab(_kV30),
    ],
    inspiration: 'Mulher de Fases — Raimundos',
    tip: 'Forrocore: riff de forró com distorção e palhetada rápida.',
  ),
  _P('Zóio de Lula', catBrasil, [
    amp(_hiGain, {'Ganho': 6, 'Médios': 5, 'Agudos': 6}),
    cab(_kV30),
    reverb({'Tipo': _room, 'Mistura': 0.12}),
  ], inspiration: 'Zóio de Lula — Charlie Brown Jr.'),
  _P('Me Adora', catBrasil, [
    amp(_brit800, {'Ganho': 6.5, 'Graves': 6, 'Médios': 6, 'Agudos': 6}),
    cab(_kV30),
    reverb({'Tipo': _room, 'Mistura': 0.12}),
  ], inspiration: 'Me Adora — Pitty'),
  _P(
    'Ando Meio Desligado',
    catBrasil,
    [
      fuzz({'Fuzz': 7, 'Tom': 6, 'Nível': 6}),
      amp(_chime, {'Ganho': 5}),
      cab(_k212),
      trem({'Velocidade': 4.5, 'Profundidade': 0.3}),
      reverb({'Tipo': _plate, 'Mistura': 0.25}),
    ],
    inspiration: 'Ando Meio Desligado — Os Mutantes',
    tip: 'Tropicália psicodélica: fuzz caseiro e muito reverb de placa.',
  ),
  _P('Pro Dia Nascer Feliz', catBrasil, [
    combo(_cBrit, {'Ganho': 6.5, 'Médios': 6.5, 'Agudos': 6}),
    reverb({'Tipo': _room, 'Mistura': 0.12}),
  ], inspiration: 'Pro Dia Nascer Feliz — Barão Vermelho'),
  _P(
    'Guitarra Baiana',
    catBrasil,
    [
      od({'Drive': 5, 'Tom': 8, 'Nível': 4.5}),
      amp(_cleanUS, {'Ganho': 5, 'Graves': 4, 'Agudos': 8, 'Presença': 6.5}),
      cab(_k112),
      delay({'Tempo': 280, 'Repetições': 0.25, 'Mistura': 0.2}),
      reverb({'Tipo': _hall, 'Mistura': 0.2}),
    ],
    inspiration: 'Chame Gente — Armandinho, Dodô & Osmar',
    tip: 'Agudo e cortante, para frevos e solos de trio elétrico.',
  ),
  _P(
    'Frevo Elétrico',
    catBrasil,
    [
      od({'Drive': 4.5, 'Tom': 7.5, 'Nível': 5}),
      amp(_cleanUS, {'Ganho': 6, 'Graves': 4, 'Agudos': 7.5}),
      cab(_k112),
      delay({'Tempo': 200, 'Repetições': 0.2, 'Mistura': 0.18}),
      reverb({'Tipo': _hall, 'Mistura': 0.18}),
    ],
    inspiration: 'Vassourinhas — Matias da Rocha e Joana Batista (frevo de Recife)',
    tip: 'Melodias rápidas em palhetada alternada, como os metais do frevo.',
  ),
  _P(
    'Manguetown',
    catBrasil,
    [
      wah({'Modo': 1, 'Sensibilidade': 0.6, 'Ressonância': 7}),
      fuzz({'Fuzz': 6.5, 'Tom': 5, 'Nível': 6}),
      amp(_plexi, {'Ganho': 6, 'Graves': 6, 'Médios': 6}),
      cab(_kGreen),
    ],
    inspiration: 'Manguetown — Chico Science & Nação Zumbi',
    tip: 'Mangue beat: riffs pesados encaixados no maracatu.',
  ),
  _P(
    'Guitarrada Paraense',
    catBrasil,
    [
      amp(_jazz, {'Ganho': 4.5, 'Agudos': 7}),
      cab(_k212),
      chorus({'Velocidade': 0.8, 'Profundidade': 0.5, 'Mistura': 0.35}),
      delay({'Tempo': 300, 'Repetições': 0.3, 'Mistura': 0.25}),
      reverb({'Tipo': _hall, 'Mistura': 0.3}),
    ],
    inspiration: 'Lambadas instrumentais — Mestre Vieira',
    tip: 'Melodias em terças com muito chorus e eco.',
  ),
  _P(
    'Samba-rock',
    catBrasil,
    [
      comp({'Limiar': -30, 'Razão': 4, 'Ganho': 6}),
      amp(_cleanUS, {'Ganho': 4.5, 'Médios': 6, 'Agudos': 6}),
      cab(_k112),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Taj Mahal — Jorge Ben Jor',
    tip: 'A batida do samba-rock pede acordes curtos e muito balanço.',
  ),
  _P(
    'Bossa de Ipanema',
    catBrasil,
    [
      amp(_jazz, {'Ganho': 4.5, 'Graves': 5.5, 'Agudos': 3.5, 'Master': 7}),
      cab(_k212, {'Microfone': 0.5}),
      reverb({'Tipo': _room, 'Mistura': 0.15}),
    ],
    inspiration: 'Garota de Ipanema — Tom Jobim',
    tip: 'Batida de bossa com o polegar no baixo e acordes dissonantes.',
  ),

  // ================================================================ Baixo
  _P('Mais Um que Cai', catBaixo, [
    comp({'Limiar': -30, 'Razão': 5, 'Ataque': 5, 'Ganho': 6}),
    amp(_bassAmp, {'Ganho': 4, 'Graves': 6, 'Médios': 5, 'Agudos': 5}),
    cab(_k810),
  ], inspiration: 'Another One Bites the Dust — Queen'),
  _P(
    'Histeria',
    catBaixo,
    [
      fuzz({'Fuzz': 6, 'Tom': 4.5, 'Nível': 6}),
      amp(_bassAmp, {'Ganho': 6, 'Graves': 6.5}),
      cab(_k810),
    ],
    inspiration: 'Hysteria — Muse',
    tip: 'Baixo com fuzz: semicolcheias rápidas com dedos ou palheta.',
  ),
  _P(
    'Cidade Adolescente',
    catBaixo,
    [
      comp({'Limiar': -28, 'Razão': 3, 'Ganho': 5}),
      amp(_bassAmp, {'Ganho': 3.5, 'Graves': 5, 'Médios': 6.5, 'Agudos': 6.5}),
      cab(_k115),
      chorus({'Velocidade': 0.5, 'Profundidade': 0.3, 'Mistura': 0.15}),
    ],
    inspiration: 'Teen Town — Weather Report (Jaco Pastorius)',
    tip: 'Baixo fretless (ou jazz bass) no captador da ponte.',
  ),
  _P(
    'Venha Junto',
    catBaixo,
    [
      comp({'Limiar': -30, 'Razão': 3, 'Ganho': 5}),
      combo(_cBass, {'Ganho': 4, 'Graves': 6, 'Agudos': 3.5}),
    ],
    inspiration: 'Come Together — The Beatles',
    tip: 'Timbre redondo e abafado: toque com os dedos perto do braço.',
  ),
  _P(
    'Cisma',
    catBaixo,
    [
      comp({'Limiar': -30, 'Razão': 4, 'Ganho': 5}),
      amp(_bassAmp, {'Ganho': 6.5, 'Graves': 6, 'Médios': 6, 'Agudos': 6}),
      cab(_k810),
    ],
    inspiration: 'Schism — Tool',
    tip: 'Baixo levemente saturado com bastante ataque de palheta.',
  ),
];

Preset _build(_P p, Catalog catalog) {
  final rb = <RigBlock>[];
  for (final b in p.blocks) {
    final def = catalog.byId(b.type);
    if (def == null) continue;
    final block = RigBlock.create(def, def.hasModels ? b.model.clamp(0, def.models.length - 1) : 0);
    b.values.forEach((k, v) {
      final i = def.paramIndex(k);
      if (i >= 0) block.params[i] = def.params[i].clamp(v);
    });
    rb.add(block);
  }
  return Preset(
    name: p.name,
    blocks: rb,
    factory: true,
    category: p.category,
    inspiration: kShowInspirations ? p.inspiration : null,
    tip: p.tip,
  );
}

List<Preset> buildFactoryPresets(Catalog catalog) => [for (final p in _library) _build(p, catalog)];

/// Problemas na biblioteca (parâmetro com nome errado, bloco ou modelo
/// inexistente, nomes duplicados). Usado pelos testes.
List<String> validateFactoryPresets(Catalog catalog) {
  final problems = <String>[];
  final names = <String>{};
  for (final p in _library) {
    if (!names.add(p.name)) problems.add('nome duplicado: ${p.name}');
    if (!factoryCategories.contains(p.category)) problems.add('${p.name}: categoria ${p.category}');
    for (final b in p.blocks) {
      final def = catalog.byId(b.type);
      if (def == null) {
        problems.add('${p.name}: bloco ${b.type}');
        continue;
      }
      if (def.hasModels && (b.model < 0 || b.model >= def.models.length)) {
        problems.add('${p.name}: modelo ${b.model} de ${b.type}');
      }
      for (final k in b.values.keys) {
        final i = def.paramIndex(k);
        if (i < 0) {
          problems.add('${p.name}: parâmetro "$k" em ${b.type}');
        } else {
          final pd = def.params[i];
          final v = b.values[k]!;
          if (v < pd.min || v > pd.max) problems.add('${p.name}: $k=$v fora de ${pd.min}..${pd.max}');
        }
      }
    }
  }
  return problems;
}
