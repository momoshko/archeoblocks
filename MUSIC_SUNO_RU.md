# Музыка для Археоблоков (Suno)

## Сколько треков нужно

| Файл | Где играет | Нужен? |
| --- | --- | --- |
| `menu` | Главное меню, выбор глав, коллекция, настройки | **обязательно** |
| `gameplay_ancient_courtyard` | Глава I «Древний двор» | **обязательно** |
| `gameplay_ruined_shrine` | Глава II «Разрушенное святилище» | желательно |
| `gameplay_overgrown_catacombs` | Глава III «Заросшие катакомбы» | желательно |
| `gameplay_endless` | Бесконечные раскопки | желательно |
| `restoration` | Реставрация находки | можно позже |
| `gameplay` | Запасной: играет в главе, у которой нет своего трека | только если делаете один общий трек для всех глав |

**Минимум — 2 трека** (`menu` + `gameplay`), **хорошо — 5** (меню, три главы, бесконечные),
**полный набор — 6** (+ реставрация). Музыка победы не нужна — там звук `victory`.

Длина каждого — **1,5–3 минуты**. Трек играет по кругу; в конце скрипт делает
плавное затухание, поэтому шов почти не слышен.

## Куда класть

1. Скачанные из Suno файлы (mp3 или wav) — в **`audio_review/music_raw/`**, переименовав
   точно как в таблице: `menu.mp3`, `gameplay_ruined_shrine.mp3` и т. д.
2. Запустить из папки проекта: **`python tools/prepare_music.py`** (нужен ffmpeg:
   `winget install ffmpeg`). Скрипт выровняет громкость, обрежет тишину, сделает затухание
   и положит `.ogg` в **`assets/audio/music/`**.
   Нет ffmpeg — просто положите файлы в `music_raw` и скажите Claude.
3. Открыть проект в Godot (импорт) — музыка заиграет сама, код менять не нужно.
4. Записать каждый трек в `CREDITS.md` (название, дата, тариф Suno).

**Лицензия:** треки с бесплатного тарифа Suno нельзя использовать в коммерческой игре
(реклама в Яндекс Играх — это коммерция). Генерировать на платном тарифе (Pro/Premier)
и сохранить скриншот/ссылку на трек как подтверждение.

## Как генерировать в Suno

- Режим **Custom**, переключатель **Instrumental — включён** (без слов).
- **Style of Music** — текст из блока «Стиль» ниже.
- **Exclude Styles** (в расширенных настройках) — `vocals, choir, lyrics, EDM, dubstep, heavy drums, distorted guitar`.
- **Lyrics** — блок «Структура» (теги в квадратных скобках задают части трека).
- **Title** — имя файла.
- Делать 2–4 варианта и выбирать тот, где **нет резких пиков и навязчивой мелодии**:
  под головоломку музыка должна «держать настроение», а не отвлекать. Слушать на тихой
  громкости — если через 3 минуты не надоело, подходит.
- Общая палитра для всех треков (чтобы игра звучала цельно): уд, арфа, лютня, калимба,
  ханг, мягкие струнные, деревянная перкуссия, рамочный бубен. Тёплая, «солнечно-пыльная».

---

### 1. menu — главное меню

**Стиль:**
```
Instrumental, warm cinematic adventure, ancient Mediterranean ruins, curious and inviting, oud and harp lead, soft pizzicato strings, gentle frame drum, light shaker, airy flute, 85 BPM, major key with a hint of mystery, cozy casual mobile game menu music, seamless loop, no vocals
```
**Структура:**
```
[Intro: soft harp arpeggio]
[Main Theme: oud melody, light frame drum]
[Variation: flute answers the oud]
[Bridge: strings swell gently]
[Main Theme]
[Outro: back to the soft harp arpeggio, ends quietly to loop]
```

### 2. gameplay_ancient_courtyard — глава I «Древний двор»

**Стиль:**
```
Instrumental, calm focused puzzle music, sunny ancient courtyard, plucked lute and marimba, soft hand percussion, warm pad, light bells, 90 BPM, steady relaxed groove, unobtrusive background for thinking, no big drops, seamless loop, no vocals
```
**Структура:**
```
[Intro: marimba pattern]
[Groove: lute melody over hand percussion]
[Variation: bells and pad, lighter]
[Groove]
[Breakdown: percussion only, very soft]
[Outro: marimba pattern, quiet ending for loop]
```

### 3. gameplay_ruined_shrine — глава II «Разрушенное святилище»

**Стиль:**
```
Instrumental, mysterious ancient temple, ruined stone shrine, kalimba and hang drum, low cello drone, soft temple chimes, distant wooden percussion, 80 BPM, slightly minor, meditative but warm, puzzle game background, seamless loop, no vocals
```
**Структура:**
```
[Intro: low drone and chimes]
[Theme: kalimba melody, hang drum pulse]
[Variation: cello takes the melody softly]
[Theme]
[Interlude: chimes and drone only]
[Outro: kalimba fades, quiet ending for loop]
```

### 4. gameplay_overgrown_catacombs — глава III «Заросшие катакомбы»

**Стиль:**
```
Instrumental, underground overgrown catacombs, roots and moss, dark but cozy, cello pizzicato, hang drum, soft woody percussion, water drop textures, deep warm pads, 75 BPM, minor key, curious and slightly tense, puzzle game background, no jump scares, seamless loop, no vocals
```
**Структура:**
```
[Intro: water drops and deep pad]
[Theme: cello pizzicato with hang drum]
[Variation: woody percussion grows a little]
[Theme]
[Calm Break: pads and drops only]
[Outro: back to water drops, quiet ending for loop]
```

### 5. gameplay_endless — бесконечные раскопки

**Стиль:**
```
Instrumental, energetic but relaxed adventure groove, endless excavation, digging deeper, oud riff, marimba ostinato, frame drum and tabla groove, rising strings, 100 BPM, driving steady rhythm, motivating, casual puzzle game, no big drops, seamless loop, no vocals
```
**Структура:**
```
[Intro: marimba ostinato]
[Groove: oud riff with frame drum and tabla]
[Build: strings rise slowly]
[Groove: fuller, still not loud]
[Breakdown: ostinato only]
[Outro: groove thins out, ends quietly to loop]
```

### 6. restoration — реставрация находки (можно позже)

**Стиль:**
```
Instrumental, gentle restorer's workshop, careful cleaning of an ancient treasure, music box and soft felt piano, light harp, warm strings pad, 70 BPM, tender and satisfying, quiet focus, seamless loop, no vocals
```
**Структура:**
```
[Intro: music box]
[Theme: felt piano melody]
[Variation: harp joins]
[Theme]
[Outro: music box alone, quiet ending for loop]
```

### Если делаете один общий трек для всех глав — gameplay

Возьмите стиль трека №2 (Древний двор) и сохраните как `gameplay.mp3`.
