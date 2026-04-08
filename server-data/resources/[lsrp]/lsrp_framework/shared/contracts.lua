LSRPFramework = LSRPFramework or {}

LSRPFramework.Version = '1.1.0'

LSRPFramework.Resources = {
	identity = 'lsrp_core',
	economy = 'lsrp_economy',
	jobs = 'lsrp_jobs',
	inventory = 'lsrp_inventory'
}

LSRPFramework.StateKeys = {
	hunger = 'lsrp_hunger',
	thirst = 'lsrp_thirst'
}

LSRPFramework.CallbackDefaults = {
	timeoutMs = 5000
}

LSRPFramework.CallbackEvents = {
	serverRequest = 'lsrp_framework:server:callback:request',
	serverResponse = 'lsrp_framework:server:callback:response',
	clientRequest = 'lsrp_framework:client:callback:request',
	clientResponse = 'lsrp_framework:client:callback:response'
}