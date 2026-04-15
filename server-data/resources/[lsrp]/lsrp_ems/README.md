# LSRP Resource Template

# lsrp_ems

EMS starter resource built on top of `lsrp_framework`.

## Current Scope

- Registers the private `ems_responder` job through `lsrp_framework`.
- Provides a Pillbox duty locker marker for clocking in and out.
- Includes owner or admin self-assignment support through toggle command `/emsme [grade]` gated by ACE `lsrp.ems.assignself`.
- Supports nearby-patient EMS vitals checks and stabilization while on duty.
- Supports ambulance transport for stabilized patients and treatment-bed recovery at Pillbox.
- Uses framework-native notify, player context, and job mutation helpers from day one.

## Main Files

- `shared/config.lua`: EMS job definition, duty marker, and blip config.
- `server/server.lua`: job registration, duty toggling, self-assignment helpers, and medical action validation.
- `client/client.lua`: duty locker loop, nearby patient care, ambulance loading, and hospital drop-off interactions.

## Commands

- `/lsrp_ems_debug`: show a simple framework-context debug notification.
- `/emsme [grade]`: toggle EMS employment for yourself if you have the required ACE. If you are not EMS, it assigns the requested grade; if you are already EMS, it resigns you.
- `/emsrelease [playerId]`: on-duty EMS can fully revive the specified patient, including early release from an active treatment bed.

## Current Gameplay

- When a patient collapses from hunger or thirst, they stay down on the floor until hospital-bed treatment completes or EMS uses `/emsrelease [playerId]`.
- On-duty EMS responders can press `E` near a collapsed patient to kneel and check their vitals, putting them into a stabilized transport state instead of reviving them on the spot.
- Stabilized collapsed patients stop hunger and thirst decay plus damage while they wait for transport and treatment.
- Non-EMS players can still escort, load into a normal road vehicle, drop off, and check in a collapsed patient so they can reach hospital treatment even when no medic is around.
- Once stabilized, the patient should be loaded directly into a nearby ambulance with `E` rather than escorted on foot.
- Stabilized patients who are still mobile can still be escorted on foot first if needed.
- An actively escorted patient can be checked in at the EMS desk and placed directly onto a treatment bed.
- Patients who make it to the Pillbox check-in desk on their own can also press `E` to admit themselves for treatment.
- The driver can get out anywhere near the active transport vehicle, press `E` to pull the patient from it, and then escort them to the Pillbox check-in desk.
- Completing the treatment-bed timer revives the patient, restores hunger to 100, restores thirst to 100, and releases them beside the bed.
- Completing hospital treatment automatically charges the patient a configurable Pillbox treatment fee from their LS$ balance.
- `/emsrelease [playerId]` uses the same full-revive path and can be used as the manual EMS revive command.
- Revive uses the existing respawn flow from `lsrp_spawner` and clears hunger or thirst collapse state.
- Stabilize still restores health for injured patients who are alive, but collapsed patients remain down until full revive.

## Notes

- This is still a starter resource, not a full medical gameplay system.
- It is intentionally small so future stretcher, treatment, billing, or dispatch systems can be layered onto the framework-native base.
- Once you are ready to run it on the server, add `ensure lsrp_ems` to `server.cfg` and add the ACE if you want `/emsme` available.