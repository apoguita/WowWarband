local function OnServerStartup()
    print("[WowWarband] ALE script smoke test passed")
end

RegisterServerEvent(33, OnServerStartup) -- SERVER_EVENT_ON_CONFIG_LOAD
