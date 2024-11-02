# 花のうた

| 4V4 Config               |
| ------------------------ |
| ZoneMod v2.8.9/1.9.3     |
| ZoneMod v2.8.1(克局ONLY) |
| ZoneMod Retro v2.8.9     |
| ZoneMod Quad(4控)        |
| ZoneHunters v2.8.9       |
| NeoMod Tourney 0.4a      |
| NextMod v1.0.5           |
| Promod Elite v1.1        |
| Deadman v5.0.3           |
| Acemod RV v1.3           |
| Equilibrium v3.0c        |
| Apex v1.1.2              |

| 3V3 Configs     |
| --------------- |
| 3v3 ZoneMod     |
| 3v3 NextMod     |
| 3v3 Acemod RV   |
| 3v3 EQ          |
| 3v3 ZoneHunters |

| 2V2 Configs     |
| --------------- |
| 2v2 ZoneMod     |
| 2v2 NextMod     |
| 2v2 Acemod RV   |
| 2v2 EQ          |
| 2v2 ZoneHunters |

| 1V1 Configs     |
| --------------- |
| 1v1 NextMod     |
| 1v1 ZoneHunters |
| 1v1 ZoneMod     |
| 1v1 Acemod RV   |
| 1v1 EQ          |

| 娱乐 Configs |
| :----------: |
| ZoneMod 6V6 |
|    躲猫猫    |
|   幽灵模式   |

本库大部分插件来源于Sir.P

介个地方: [PencilMario/L4D2-Competitive-Rework: 0721服务器的Zonemod插件配置 (github.com)](https://github.com/PencilMario/L4D2-Competitive-Rework)

Sir.P 么么么么~

# **L4D2 Competitive Rework**

**IMPORTANT NOTES** - **DON'T IGNORE THESE!**

* The goal for this repo is to work on **Linux**, but Windows support is available.
* Ensure that your machine is running at least **Ubuntu 20.04** (GLIBC minimum of 2.31)

> While Windows is supported by the repository, there may be things that don't fully function on Windows that we may have missed.
> Please report any issues you run into!

* This repository only supports Sourcemod **1.11** and up.
* Everything on this repository is being tested on Sourcemod **1.12** (specifically **1.12.7137**) as of the 25th of May, 2024.

## **About:**

This project started off with a focus on reworking the very outdated platform for competitive L4D2.
In its current state it allows anyone to host their own up to date competitive L4D2 servers.
This project is **Actively Developed**.

> **Included Matchmodes:**

* **Zonemod 2.8.9c**
* **Zonemod Hunters**
* **Zonemod Retro**
* **NeoMod 0.4a**
* **NextMod 1.0.5**
* **Promod Elite 1.1**
* **Acemod Revamped 1.2**
* **Equilibrium 3.0c**
* **Apex 1.1.2**

---

## **Important Notes**

* We've added "**mv_maxplayers**" that replaces sv_maxplayers in the Server.cfg, this is used to prevent it from being overwritten every map change.
  * On config unload, the value will be to the value used in the Server.cfg
* Every Confogl matchmode will now execute 2 additional files, namely "**sharedplugins.cfg**" and "**generalfixes.cfg**" which are located in your **left4dead2/cfg** folder.
  * "**General Fixes**" simply ensures that all the Fixes discussed in here are loaded by every Matchmode.
  * "**Shared Plugins**" is for you, the Server host. You surely have some plugins that you'd like to be loaded in every matchmode, you can define them here.
    * **NOTE:** Plugin load locking and unlocking is no longer handled by the Configs themselves, so if you're using this project do **NOT** define plugin load locks/unlocks within the configs you're adding manually.

---

## **Credits:**

> **Foundation/Advanced Work:**

* A1m`
* AlliedModders LLC.
* "Confogl Team"
* Dr!fter
* Forgetest
* Jahze
* Lux
* Prodigysim
* Silvers
* XutaxKamay
* Visor

> **Additional Plugins/Extensions:**

* Accelerator74
* Arti
* AtomicStryker
* Backwards
* BHaType
* Blade
* Buster
* Canadarox
* CircleSquared
* Darkid
* DarkNoghri
* Dcx
* Devilesk
* Die Teetasse
* Disawar1
* Don
* Dragokas
* Dr. Gregory House
* Epilimic
* Estoopi
* Griffin
* Harry Potter
* Jacob
* Luckylock
* Madcap
* Mr. Zero
* Nielsen
* Powerlord
* Rena
* Sheo
* Sir
* Spoon
* Stabby
* Step
* Tabun
* Target
* TheTrick
* V10
* Vintik
* VoiDeD
* xoxo
* $atanic $pirit

> **Competitive Mapping Rework:**

* Aiden
* Derpduck

> **Testing/Issue Reporting:**

* Too many to list, keep up the great work in reporting issues!

**NOTE:** If your work is being used and I forgot to credit you, my sincere apologies.
I've done my best to include everyone on the list, simply create an issue and name the plugin/extension you've made/contributed to and I'll make sure to credit you properly.
