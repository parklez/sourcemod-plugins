# sourcemod-plugins
A collection of sourcemod plugins I've edited or made from scratch

## Index 📝
 * [[TF2 MvM] Wave Start Announcer](#tf2-mvm-wave-start-announcer)
 * [[TF2 MvM] Shop for spawning props](#tf2-mvm-shop-for-spawning-props-and-entities)
 * [[TF2 MvM] Gift Drops](#tf2-mvm-gift-drops)
 * [[TF2 MvM] Auto Cash Pickup](#tf2-mvm-auto-cash-pickup)

### [TF2 MvM] Wave Start Announcer
A simple announcer on wave start, printing out the following string in chat:

![Wave Announcement](docs/wave_announcement.webp)

#### Installing
- Copy [mvm_wave_start_announcer.smx](./compiled/mvm_wave_start_announcer.smx) to `sourcemod/plugins`

Source code: [mvm_wave_start_announcer.sp](./scripting/mvm_wave_start_announcer.sp)

### [TF2 MvM] Shop for spawning props and entities
A shop for players with deep pockets who want to spawn some stuff. Allows for refunding the last spawned item so no hard feelings.

![Props shop in-game](docs/props_shop.png)

The config file defines available props and entities, their price and health (before they break).

#### How to use
**In chat:** !props, !prop, !shop, !buy, !store & !refund \
**In console:** `sm_props` & `sm_refund`

#### Installing
- Copy [mvm_props_shop.cfg](./configs/mvm_props_shop.cfg) to `sourcemod/configs`
- Copy [mvm_props_shop.smx](./compiled/mvm_props_shop.smx) to `sourcemod/plugins`

Source code: [mvm_props_shop.sp](./scripting/mvm_props_shop.sp)

### [TF2 MvM] Gift Drops
Machines may drop a floating xmas gift when killed. Gifts contain random perks.

![Dropped Gift](docs/dropped_gift.webp)

#### List of perks available:
 - Infinite ammo & Increased fire-rate (for 30 seconds)
 - Extra Money ($1000)
 - Crit boosted (for 60 seconds)
 - Instakill (for 15 seconds)
 - Speed & Healing (for 60 seconds)
 - Ubercharged (for 30 seconds)

#### Installing
- Install [tf2attributes](https://github.com/LauTrin/TF2Attributes).
- Copy [mvm_gift_drops.smx](./compiled/mvm_gift_drops.smx) to `sourcemod/plugins`
- A config will be generated in `/tf/cfg/sourcemod/mvm_gift_drops.cfg` - Server owners can configure what perks are active, fow how long, gift drop rate, etc. Restart to apply changes.

Source code: [mvm_gift_drops.sp](./scripting/mvm_gift_drops.sp) & everything inside `/scripting/mvm_gifts/*.sp`

### [TF2 MvM] Auto Cash Pickup
Teleports dropped cash from robots to Red Team's big pockets. Will attempt to do so even after respawning.

#### How to use

- **In console:** `sm_mvm_cash_pickup_enable 1` to enable, ` 0` to disable.

#### Installing
- Copy [mvm_cash_pickup.smx](./compiled/mvm_cash_pickup.smx) to `sourcemod/plugins`

Source code: [mvm_cash_pickup.sp](./scripting/mvm_cash_pickup.sp)
