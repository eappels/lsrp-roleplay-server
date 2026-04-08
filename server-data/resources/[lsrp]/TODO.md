# LSRP TODO

## Planned Work

- EMS job

## Framework goal
turn LSRP into a small, opinionated platform, not a compatibility layer.

You already have the right starting shape: the server is split into focused services instead of one giant core. The resource index in server-data/resources/[lsrp]/README.md, plus the separation visible in server-data/resources/[lsrp]/lsrp_core/README.md, server-data/resources/[lsrp]/lsrp_jobs/README.md, server-data/resources/[lsrp]/lsrp_economy/README.md, and server-data/resources/[lsrp]/lsrp_inventory/README.md is a better base for extensibility than a monolithic framework. What is missing is not more features. It is a cleaner developer surface.

The right direction is:

One public API layer.
Create a single resource that becomes the official framework entrypoint, for example lsrp_framework.
Other resources should depend on that, not directly on five internal services.

Stable contracts.
Define a small set of framework services and freeze their payload shapes:
player
identity
money
inventory
jobs
notify
callbacks
permissions

Registries instead of hardcoding.
Make jobs, items, interactions, phone apps, and usable actions register themselves.
You already do this well with jobs. Extend that pattern everywhere.

Convention over improvisation.
Every resource should follow the same naming rules for exports, events, callbacks, state bags, and config layout.
That is what makes a framework feel easy.

Templates and docs.
A framework is only “easy to expand” if adding a new resource feels repetitive and obvious.
Each new LSRP resource should start from a standard skeleton with manifest, config, client, server, shared helpers, and README.

The most important design choice is this: do not expose database schema as framework API. Your DB can change. Your public contracts should not. A new job, business, or phone app should never need to know whether identity is keyed by license, account_id, or state_id.

If I were shaping LSRP for ease of use, I would define the framework around six developer-facing concepts:

Player
Read-only normalized view of the current player state.

Identity
Who this player is across systems.

Economy
Add, remove, transfer, format, and query balances.

Inventory
Has item, add item, remove item, register usable item.

Jobs
Register job, employ player, resign player, set duty, check permission.

UI and callbacks
One official request-response path for NUI, client-server, and server-client calls.

What to avoid:

No giant mutable player object like QB-Core.
That becomes convenient short-term and messy long-term.

No direct cross-resource table access.
Only exports, callbacks, and documented events.

No ad hoc event payloads.
Every framework event should have a documented schema.

No duplicated helper logic in every resource.
Identity lookup, notifications, and permission checks should be centralized.

A practical roadmap would be:

Build lsrp_framework as a facade over the current resources.
Move shared helper patterns into it first: player lookup, identity, notify, callbacks.
Standardize money, inventory, and job APIs behind that layer.
Add a registerItem, registerJob, registerInteraction, and registerApp style registry model.
Create a “new resource” template and require new LSRP resources to use it.
Gradually refactor older resources to consume the facade instead of each other directly.
If you want the blunt version: LSRP should become more like a clean internal SDK than like QB-Core. Small public surface, strict conventions, modular services, and easy resource scaffolding. That will make it easier to use and easier to grow without inheriting the usual framework bloat.

If you want, I can next do one of these:

Define the exact public API for a new lsrp_framework resource.
Draft the folder and file template for all future LSRP resources.
Review the current resources and identify which ones should be refactored first to support that design.