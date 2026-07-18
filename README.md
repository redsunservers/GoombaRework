# GoombaRework

### Goomba Plugin for Issari's server. 

Fork of the Original Goomba Plugin by Flyflo

# Features

- Stomp to kill: Land on enemies from above to deal massive damage.

- Custom sounds & effects: Plays configurable stomp and rebound sounds, plus optional particle effects.

- Rebound jumps: Stomping launches you back up for stylish multi-stomps.

- Configurable damage system:

- Scales with victim’s health (goomba_dmg_lifemultiplier).

- Flat bonus damage (goomba_dmg_add).

- Immunity rules: Prevent stomps or stomping under special conditions (Uber, Bonk, Cloak, Stun, etc.).

- Friendly fire support (requires tf_avoidteammates 1 and mp_friendlyfire 1).

- Disguise handling: Stomps can force Spies out of disguise.


#  Installation

1. Compile `goomba.sp` with SourceMod.

2. Place `goomba.smx` into your `addons/sourcemod/plugins` folder.

3. Add the included sounds to your `sound/goomba/` directory:
    - `stomp.wav`
    - `rebound.wav`

4. Ensure your FastDL is set up so clients download the sounds.

5. Restart your server or use `sm plugins load goomba`.

# Configuration

The plugin auto-generates a config file:

`cfg/sourcemod/goomba.cfg`

# Core ConVars

| ConVar                      | Default | Description                                    |
| --------------------------- | ------- | ---------------------------------------------- |
| `goomba_enabled`            | `0`     | Enable/disable the plugin                      |
| `goomba_sounds`             | `1`     | Enable stomp & rebound sounds                  |
| `goomba_particles`          | `1`     | Enable particle effects                        |
| `goomba_rebound_power`      | `300.0` | Stomp rebound jump power                       |
| `goomba_minspeed`           | `360.0` | Minimum fall speed required to trigger a stomp |
| `goomba_dmg_lifemultiplier` | `0.025` | Damage multiplier based on victim’s health     |
| `goomba_dmg_add`            | `450.0` | Flat damage added after multiplier             |

# Immunity ConVars

| ConVar                 | Default | Description                                          |
| ---------------------- | ------- | ---------------------------------------------------- |
| `goomba_uber_immun`    | `1`     | Prevent stomping Ubercharged players                 |
| `goomba_cloak_immun`   | `1`     | Prevent cloaked Spies from stomping others           |
| `goomba_stun_immun`    | `1`     | Prevent stomping stunned players                     |
| `goomba_cloaked_immun` | `0`     | Prevent cloaked Spies from being stomped             |
| `goomba_bonked_immun`  | `1`     | Prevent Bonked Scouts from being stomped             |
| `goomba_undisguise`    | `1`     | Forces Spies to undisguise when stomping             |
| `goomba_friendlyfire`  | `0`     | Allow stomps against teammates (requires FF enabled) |

# Gameplay

Jump onto another player’s head at a sufficient fall speed.

Victim takes heavy damage (usually lethal).

Attacker rebounds into the air, with optional sounds/particles.

Kills are logged under the "Goomba" weapon name.

# Dependencies

SourceMod 1.11+

[TF2Items / TF2Stocks include (bundled with SM TF2 extension)]

[MoreColors include](https://github.com/DoctorMcKay/sourcemod-morecolors)
