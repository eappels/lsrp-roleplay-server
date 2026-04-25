MenuItems = {
    {
        id = 'dev',
        label = 'Dev',
        icon = 'screwdriver-wrench',
        canOpen = function()
            return CodemDevAccess and CodemDevAccess.isAuthorized == true
        end,
        items = {
            {
                id = 'dev_movement',
                label = 'Movement',
                icon = 'person-walking',
                items = {
                    {
                        id = 'dev_tp_legion',
                        label = 'TP Legion',
                        icon = 'location-dot',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'tp',
                            x = 215.76,
                            y = -920.07,
                            z = 30.69,
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_tp_airport',
                        label = 'TP Airport',
                        icon = 'plane-departure',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'tp',
                            x = -1037.08,
                            y = -2737.03,
                            z = 20.17,
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_tp_sandy',
                        label = 'TP Sandy',
                        icon = 'mountain-sun',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'tp',
                            x = 1737.29,
                            y = 3288.92,
                            z = 41.14,
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_tp_custom',
                        label = 'TP Custom',
                        icon = 'location-crosshairs',
                        event = 'codem-supreme-radialmenu:client:RunLocalDevAction',
                        type = 'client',
                        args = {
                            action = 'tp_custom'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_noclip',
                        label = 'Toggle Noclip',
                        icon = 'feather-pointed',
                        event = 'codem-supreme-radialmenu:client:RunLocalDevAction',
                        type = 'client',
                        args = {
                            action = 'noclip'
                        },
                        shouldClose = true
                    }
                }
            },
            {
                id = 'dev_vehicle',
                label = 'Vehicle',
                icon = 'car-side',
                items = {
                    {
                        id = 'dev_vehicle_comet',
                        label = 'Spawn Comet',
                        icon = 'car',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'veh',
                            modelArg = 'comet7'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_vehicle_police',
                        label = 'Spawn Police',
                        icon = 'shield-halved',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'veh',
                            modelArg = 'police3'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_vehicle_plate',
                        label = 'Set DEV Plate',
                        icon = 'id-card',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'setplate',
                            plateText = 'DEV001'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_vehicle_delete_closest',
                        label = 'Delete Closest',
                        icon = 'trash',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'delveh'
                        },
                        shouldClose = true
                    }
                }
            },
            {
                id = 'dev_player',
                label = 'Player',
                icon = 'user',
                items = {
                    {
                        id = 'dev_heal',
                        label = 'Heal',
                        icon = 'heart-pulse',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'heal'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_revive',
                        label = 'Revive',
                        icon = 'kit-medical',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'revive'
                        },
                        shouldClose = true
                    }
                }
            },
            {
                id = 'dev_combat',
                label = 'Combat',
                icon = 'gun',
                items = {
                    {
                        id = 'dev_wep_pistol',
                        label = 'Pistol',
                        icon = 'gun',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'wep',
                            weaponArg = 'pistol'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_wep_rifle',
                        label = 'Rifle',
                        icon = 'crosshairs',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'wep',
                            weaponArg = 'rifle'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_wep_shotgun',
                        label = 'Shotgun',
                        icon = 'burst',
                        event = 'codem-supreme-radialmenu:client:RequestDevAction',
                        type = 'client',
                        args = {
                            action = 'wep',
                            weaponArg = 'shotgun'
                        },
                        shouldClose = true
                    }
                }
            },
            {
                id = 'dev_utility',
                label = 'Utility',
                icon = 'toolbox',
                items = {
                    {
                        id = 'dev_pos',
                        label = 'Print Position',
                        icon = 'map-pin',
                        event = 'codem-supreme-radialmenu:client:RunLocalDevAction',
                        type = 'client',
                        args = {
                            action = 'pos'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_ids',
                        label = 'Toggle IDs',
                        icon = 'id-badge',
                        event = 'codem-supreme-radialmenu:client:RunLocalDevAction',
                        type = 'client',
                        args = {
                            action = 'ids'
                        },
                        shouldClose = true
                    },
                    {
                        id = 'dev_identityaudit',
                        label = 'Identity Audit',
                        icon = 'clipboard-check',
                        event = 'codem-supreme-radialmenu:client:RunLocalDevAction',
                        type = 'client',
                        args = {
                            action = 'identityaudit'
                        },
                        shouldClose = true
                    }
                }
            }
        }
    },
}

-- Job-specific menu items (shown based on player's job)
-- Same structure as qb-radialmenu Config.JobInteractions
JobInteractions = {
    ['police'] = {
        id = 'police',
        label = 'Police Actions',
        icon = 'shield-halved',
        items = {
            {
                id = 'emergencybutton',
                label = 'Emergency Button',
                icon = 'bell',
                event = 'police:client:SendPoliceEmergencyAlert',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'checkstatus',
                label = 'Check Status',
                icon = 'heart-pulse',
                event = 'police:client:CheckStatus',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'handcuff',
                label = 'Handcuff',
                icon = 'hands',
                event = 'police:client:CuffPlayer',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'escort',
                label = 'Escort',
                icon = 'user-friends',
                event = 'police:client:EscortPlayer',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'search',
                label = 'Search Player',
                icon = 'magnifying-glass',
                event = 'police:server:SearchPlayer',
                type = 'server',
                shouldClose = true
            },
            {
                id = 'jail',
                label = 'Jail',
                icon = 'building-lock',
                event = 'police:client:JailPlayer',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'takedriverlicense',
                label = 'Revoke License',
                icon = 'id-card',
                event = 'police:client:SeizeDriverLicense',
                type = 'client',
                shouldClose = true
            }
        }
    },
    ['ambulance'] = {
        id = 'ambulance',
        label = 'EMS Actions',
        icon = 'truck-medical',
        items = {
            {
                id = 'checkstatus',
                label = 'Check Status',
                icon = 'stethoscope',
                event = 'hospital:client:CheckStatus',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'revive',
                label = 'Revive Player',
                icon = 'heart-pulse',
                event = 'hospital:client:RevivePlayer',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'heal',
                label = 'Heal Wounds',
                icon = 'bandage',
                event = 'hospital:client:TreatWounds',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'emergencybutton',
                label = 'Emergency Button',
                icon = 'bell',
                event = 'police:client:SendPoliceEmergencyAlert',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'escort',
                label = 'Escort',
                icon = 'user-friends',
                event = 'police:client:EscortPlayer',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'takestretcher',
                label = 'Take Stretcher',
                icon = 'bed',
                event = 'codem-supreme-radialmenu:client:TakeStretcher',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'removestretcher',
                label = 'Remove Stretcher',
                icon = 'trash',
                event = 'codem-supreme-radialmenu:client:RemoveStretcher',
                type = 'client',
                shouldClose = true
            }
        }
    },
    ['mechanic'] = {
        id = 'mechanic',
        label = 'Mechanic Actions',
        icon = 'wrench',
        items = {
            {
                id = 'towvehicle',
                label = 'Tow Vehicle',
                icon = 'truck-pickup',
                event = 'qb-tow:client:TowVehicle',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'repair',
                label = 'Repair Vehicle',
                icon = 'screwdriver-wrench',
                event = 'mechanic:client:RepairVehicle',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'clean',
                label = 'Clean Vehicle',
                icon = 'spray-can',
                event = 'mechanic:client:CleanVehicle',
                type = 'client',
                shouldClose = true
            }
        }
    },
    ['taxi'] = {
        id = 'taxi',
        label = 'Taxi Actions',
        icon = 'taxi',
        items = {
            {
                id = 'togglemeter',
                label = 'Show/Hide Meter',
                icon = 'eye-slash',
                event = 'qb-taxi:client:toggleMeter',
                type = 'client',
                shouldClose = false
            },
            {
                id = 'togglemouse',
                label = 'Start/Stop Meter',
                icon = 'hourglass-start',
                event = 'qb-taxi:client:enableMeter',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'npc_mission',
                label = 'NPC Mission',
                icon = 'taxi',
                event = 'qb-taxi:client:DoTaxiNpc',
                type = 'client',
                shouldClose = true
            }
        }
    },
    ['tow'] = {
        id = 'tow',
        label = 'Tow Actions',
        icon = 'truck-pickup',
        items = {
            {
                id = 'togglenpc',
                label = 'Toggle NPC',
                icon = 'toggle-on',
                event = 'jobs:client:ToggleNpc',
                type = 'client',
                shouldClose = true
            },
            {
                id = 'towtruck',
                label = 'Tow Vehicle',
                icon = 'truck-pickup',
                event = 'qb-tow:client:TowVehicle',
                type = 'client',
                shouldClose = true
            }
        }
    },
    ['hotdog'] = {
        id = 'hotdog',
        label = 'Hotdog Actions',
        icon = 'hotdog',
        items = {
            {
                id = 'togglesell',
                label = 'Toggle Sell',
                icon = 'circle-dollar-to-slot',
                event = 'qb-hotdogjob:client:ToggleSell',
                type = 'client',
                shouldClose = true
            }
        }
    }
}

-- Vehicle door labels (used by main.lua for dynamic vehicle menu)
VehicleDoorLabels = {
    [0] = "Driver's Door",
    [1] = "Passenger's Door",
    [2] = "Back Left Door",
    [3] = "Back Right Door",
    [4] = "Hood",
    [5] = "Trunk"
}
