DoScreenFadeOut(0)

AddEventHandler('onClientMapStart', function()
  exports.spawnmanager:setAutoSpawn(true)
  exports.spawnmanager:forceRespawn()
end)
