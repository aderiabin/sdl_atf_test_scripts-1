---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: Registration of two mobile applications with the same appName and same appID from different mobile devices
-- Precondition:
-- 1)SDL and HMI are started
-- 2) Mobile №1 and №2 are connected to SDL
-- In case:
-- 1)Mobile №1 sends RegisterAppInterface request (with all mandatories) to SDL
-- 2)Mobile №2 sends RegisterAppInterface request (with all mandatories) with same appName and same appID to SDL
-- SDL does:
-- 1)Send RegisterAppInterface(resultCode = SUCCESS) response to Mobile №1
-- 2)Send RegisterAppInterface(resultCode = SUCCESS) response to Mobile №2
-- 3)Send first OnAppRegistered notification to HMI
-- 4)Send second OnAppRegistered notification to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/TheSameApp/commonTheSameApp')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1", port = config.mobilePort }
}

local appParams = {
	[1] = { appName = "Test Application",   appID = "0001", fullAppID = "0000001" },
  [2] = { appName = "Test Application 2", appID = "0001", fullAppID = "0000001" }

}

--[[ Local Functions ]]
local function registerAppFromSameDevice(pAppId, pAppParams, pMobConnId)
  local appParams = common.app.getParams(pAppId)
  for k, v in pairs(pAppParams) do
    appParams[k] = v
  end

  local session = common.mobile.createSession(pAppId, pMobConnId)
  session:StartService(7)
  :Do(function()
      local corId = session:SendRPC("RegisterAppInterface", appParams)
      session:ExpectResponse(corId, { success = false, resultCode = "APPLICATION_REGISTERED_ALREADY" })
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})

runner.Title("Test")
runner.Step("Register App1 from device 1", common.registerAppEx,      {1, appParams[1], 1})
runner.Step("Register App2 from device 1", registerAppFromSameDevice, {2, appParams[2], 1})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
