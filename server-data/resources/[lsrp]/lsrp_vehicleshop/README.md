# LSRP Vehicle Shop

## Overview

`lsrp_vehicleshop` provides the dealership UI where players browse, preview, and purchase vehicles.

It integrates with the economy resource for payment, with vehicle parking for persistent ownership registration, and with vehicle behaviour for owner key assignment.

## Main Files

- `client/client.lua`: shop UI flow, demo vehicle spawning, demo vehicle cleanup, and balance updates.
- `server/server.lua`: purchase validation, pricing, ownership registration, owner key assignment, and economy integration.
- `shared/config.lua`: shop, category, and vehicle definitions.
- `html/`: NUI for the dealership.

## Current Features

- Category-based vehicle browsing.
- Demo vehicle spawning for preview.
- Purchase flow with LS$ balance checks.
- Persistent registration of bought vehicles through the parking resource.
- Automatic owner key assignment for the purchased vehicle plate.

## Integrations

- `lsrp_core`
- `lsrp_economy`
- `lsrp_vehicleparking`
- `oxmysql`
- `lsrp_zones` for interaction entry points.

## Notes

- Demo vehicle placement and stabilization are handled on the client side.
- Purchased vehicles are not owned here directly; ownership is registered through `lsrp_vehicleparking`, then the owner key is granted through `lsrp_vehiclebehaviour`.