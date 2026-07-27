# sourcemod-plugins
A collection of sourcemod plugins I've edited or made from scratch

## Index 📝
 * [[TF2 MvM] Wave Start Announcer](#tf2-mvm-wave-start-announcer)
 * [[TF2 MvM] Shop for spawning props](#tf2-mvm-shop-for-spawning-props-and-entities)

### [TF2 MvM] Wave Start Announcer
A simple announcer on wave start, printing out the following string in chat:
```
[MvM] Map: "mvm_mannworks" - Difficulty: "normal" - Wave: 1/6"
```
#### Installing
- Copy [mvm_wave_start_announcer.smx](./compiled/mvm_wave_start_announcer.smx) to `sourcemod/plugins`

Source code: [mvm_wave_start_announcer.sp](./scripting/mvm_wave_start_announcer.sp)

### [TF2 MvM] Shop for spawning props and entities
A shop for players with deep pockets who want to spawn some stuff. Allows for refunding the last spawned item so no hard feelings.

![Prop store in-game](docs/prop_store.png)

The config file defines available props and entities, their price and health (before they break).

#### How to use
**In chat:** !props & !refund \
**In console:** `sm_props` & `sm_refund`

#### Installing
- Copy [prop_shop.cfg](./configs/prop_store.cfg) to `sourcemod/configs`
- Copy [mvm_prop_shop.smx](./compiled/mvm_prop_shop.smx) to `sourcemod/plugins`

Source code: [mvm_prop_shop.sp](./scripting/mvm_prop_shop.sp)
