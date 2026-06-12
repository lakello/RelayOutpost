# Relay Outpost

Кооперативный wave-defense/extraction шутер на Roblox. Vertical slice: 2–4 игрока защищают генератор, активируют ретрансляторы и уходят на эвакуацию.

---

## Геймплей

```
Lobby (10s)
  └─► Wave 1  →  Relay A  →  Wave 2  →  Relay B  →  Wave 3  →  Relay C  →  Extraction  →  Victory
                                                                         ↓
                                                               Generator destroyed / all downed
                                                                         ↓
                                                                       Defeat
```

- **3 волны** врагов нарастающей сложности
- После каждой волны — активация **ретранслятора** (удерживай E рядом с маяком)
- После всех ретрансляторов — **волна эвакуации**, выживи и победи
- Игрок при 0 HP переходит в **downed-состояние** — союзник может поднять (удерживай E)
- Если все игроки downed или генератор уничтожен — **поражение**

---

## Стек

| Инструмент | Версия | Назначение |
|---|---|---|
| [Roblox Studio](https://www.roblox.com/create) | latest | движок и редактор |
| [Rojo](https://rojo.space) | 7.4.4 | синхронизация файлов ↔ Studio |
| [Wally](https://wally.run) | 0.3.2 | пакетный менеджер |
| [Matter ECS](https://eryn.io/matter) | 0.8.4 | игровой ECS runtime |
| [Selene](https://kampfkarren.github.io/selene) | 0.27.1 | статический анализатор Luau |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | 0.20.0 | форматирование кода |
| [TestEZ](https://roblox.github.io/testez) | 0.4.1 | unit-тестирование |

---

## Требования

- Roblox Studio (последняя версия)
- [Rokit](https://github.com/rojo-rbx/rokit) — для установки Rojo, Wally, Selene, StyLua

---

## Установка

```bash
# 1. Установить инструменты через Rokit
rokit install

# 2. Установить Wally-пакеты
wally install

# 3. Запустить Rojo-сервер
rojo serve default.project.json
```

Затем в Roblox Studio: **Plugins → Rojo → Connect**.

---

## Структура проекта

```
relay-outpost/
├── src/
│   ├── server/
│   │   ├── Bootstrap.server.lua        # точка входа сервера
│   │   ├── ECS/
│   │   │   ├── World.lua               # Matter world singleton
│   │   │   └── SystemScheduler.lua     # throttled scheduler (Hz per system)
│   │   ├── Services/
│   │   │   ├── MatchStateService.lua   # авторитетный match state
│   │   │   └── EnemyFactory.lua        # спавн enemy entities
│   │   └── Systems/
│   │       ├── WaveDirectorSystem.lua  # фазовый автомат матча
│   │       ├── CombatSystem.lua        # hitscan + валидация
│   │       ├── EnemyMovementSystem.lua # движение к цели
│   │       ├── PathfindingSystem.lua   # async NavMesh пути (2 Hz)
│   │       ├── TargetAcquisitionSystem.lua
│   │       ├── EnemyMeleeSystem.lua
│   │       ├── InteractionSystem.lua   # захват relay
│   │       ├── ReviveSystem.lua        # подъём downed игроков
│   │       ├── CleanupSystem.lua       # удаление мёртвых сущностей
│   │       ├── ReplicationBridgeSystem.lua
│   │       └── DebugSnapshotSystem.lua # 4 Hz снимок для overlay
│   │
│   ├── client/
│   │   ├── Bootstrap.client.lua        # точка входа клиента
│   │   ├── Controllers/
│   │   │   ├── HudController.lua       # retained HUD
│   │   │   ├── CrosshairController.lua # прицел по курсору
│   │   │   ├── InputController.lua     # стрельба (cursor-based)
│   │   │   ├── InteractionController.lua
│   │   │   ├── ReviveController.lua
│   │   │   ├── VfxController.lua       # трассер, вспышки, виньетка
│   │   │   ├── EndScreenController.lua # Victory/Defeat экран
│   │   │   └── StreamingAwarenessController.lua
│   │   ├── UI/
│   │   │   └── HudBuilder.lua          # чистый UI-конструктор
│   │   └── Debug/
│   │       ├── ImmediateGui.lua        # пул TextLabel-ов
│   │       └── DebugOverlayController.lua  # dev overlay (` или F3)
│   │
│   └── shared/
│       ├── Components/                 # Matter компоненты (data-only)
│       │   ├── init.lua
│       │   ├── Health.lua
│       │   ├── Enemy.lua
│       │   ├── DownedState.lua
│       │   └── ...
│       ├── Config/
│       │   ├── MatchConfig.lua         # HP, дистанции, таймеры
│       │   ├── EnemyConfig.lua         # статы врагов по типам
│       │   ├── WeaponConfig.lua        # урон, скорострельность
│       │   ├── WaveConfig.lua          # бюджет волн, spawn rate
│       │   └── ZoneConfig.lua          # зоны и relay ID
│       ├── Pure/
│       │   ├── DamageRules.lua         # чистая логика урона
│       │   ├── WaveScaling.lua         # формула врагов/множители
│       │   ├── ObjectiveRules.lua      # прогресс relay
│       │   └── InteractionValidation.lua
│       └── Remotes/
│           └── init.lua                # все RemoteEvent/Function
│
├── tests/
│   └── shared/
│       ├── DamageRules.spec.lua
│       ├── WaveScaling.spec.lua
│       ├── ObjectiveRules.spec.lua
│       └── InteractionValidation.spec.lua
│
├── default.project.json    # Rojo mapping
├── wally.toml              # зависимости
├── rokit.toml              # версии инструментов
├── selene.toml
└── stylua.toml
```

---

## Архитектура

### Server-authoritative

Сервер владеет всем важным состоянием: HP игроков и врагов, downed/revived, HP генератора, прогресс relay, фаза матча, спавн врагов, victory/defeat.

Клиент отправляет **намерения**, сервер **валидирует и применяет**:

```
Client  →  FireWeaponRequest(origin, direction, clientTime)
Server  →  validate cooldown, distance, alive state
Server  →  raycast, apply damage
Server  →  CombatEvent → all clients (VFX)
```

### ECS (Matter)

Gameplay runtime построен на Matter ECS. Сущности собираются из компонентов:

```
Enemy   = Health + Transform + ModelRef + Target + AttackCooldown + MeleeAttack
Relay   = Objective + CaptureProgress + RelayBeacon + Transform
Player  = Health + PlayerRef + CharacterRef + WeaponState + DownedState
```

Системы регистрируются с частотой (Hz) через `SystemScheduler`:

| Система | Hz | Назначение |
|---|---|---|
| WaveDirector | 2 | фазовый автомат матча |
| EnemySpawn | 2 | дренаж очереди спавна |
| TargetAcquisition | 5 | выбор цели |
| Pathfinding | 2 | async NavMesh пути |
| EnemyMovement | 20 | физическое движение |
| EnemyMelee | 10 | атаки врагов |
| Interaction | 10 | прогресс захвата relay |
| Revive | 10 | прогресс подъёма |
| Cleanup | 5 | удаление мёртвых сущностей |
| ReplicationBridge | 5 | рассылка MatchState клиентам |
| DebugSnapshot | 4 | снимок состояния для overlay |

### StreamingEnabled

Проект работает со `StreamingEnabled = true`. Клиентский код никогда не обращается к `workspace.Map.Zones.*` напрямую — только через `CollectionService` теги и атрибуты (`ObjectiveId`, `ZoneId`). `StreamingAwarenessController` централизует все stream-события.

---

## Конфигурация

Все числовые параметры вынесены в `src/shared/Config/`:

**`MatchConfig.lua`** — HP игрока/генератора, время revive, дистанции взаимодействия  
**`EnemyConfig.lua`** — HP, скорость, урон, cooldown для каждого типа врага  
**`WeaponConfig.lua`** — урон, скорострельность, дальность  
**`WaveConfig.lua`** — размер батча спавна, интервал, состав волн  

---

## Studio: настройка карты

Для работы pathfinding и streaming нужно добавить теги и атрибуты в редакторе:

| Объект | CollectionService тег | Атрибуты |
|---|---|---|
| Relay-маяк | `RelayBeacon` | `ObjectiveId = "Relay_A"`, `ZoneId = "A"` |
| Генератор | `Generator` | `ObjectiveId = "Generator"` |
| Точки спавна | `EnemySpawn` | `ZoneId = "A"`, `SpawnGroupId = "Zone_A"` |

После расстановки моделей: **Model → Generate Navigation Mesh** — для работы pathfinding.

---

## Разработка

```bash
# Форматирование
stylua src/

# Линтинг
selene src/

# Проверить Rojo-сборку
rojo build default.project.json -o build.rbxl
```

Тесты запускаются автоматически при старте сервера в Studio (только в Studio, безопасно в production).

---

## Debug overlay

В игре нажми **`` ` ``** (backtick) или **F3** — появится dev overlay с:
- фазой матча, номером волны, числом врагов
- HP генератора, статусами relay
- числом ECS-сущностей, тайминги систем (ms/tick)
- числом загруженных streaming-объектов, FPS клиента
