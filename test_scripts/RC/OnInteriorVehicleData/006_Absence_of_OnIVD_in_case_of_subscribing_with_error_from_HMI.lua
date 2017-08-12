---------------------------------------------------------------------------------------------------
-- Requirement summary:
-- [SDL_RC] Subscribe on RC module change notification
--
-- Description: TRS: GetInteriorVehicleData, #7
-- In case:
-- 1) RC app sends valid and allowed-by-policies GetInteriorVehicleData request with "subscribe:true" parameter
-- 2) and SDL received GetInteriorVehicleData response with "resultCode: <any-erroneous-result>" from HMI
-- 3) and then SDL received OnInteriorVehicleData notification
-- SDL must:
-- 1) Transfer GetInteriorVehicleData response with "resultCode: <any-erroneous-result>"
-- and without "isSubscribed" param to the related app
-- 2) Does not re-send OnInteriorVehicleData notification to the app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Local Valiables ]]
local modules = { "CLIMATE", "RADIO" }
local error_codes = { "GENERIC_ERROR", "INVALID_DATA", "OUT_OF_MEMORY", "REJECTED" }

--[[ Local Functions ]]
local function subscriptionToModule(pModuleType, pResultCode, self)
  local cid = self.mobileSession:SendRPC("GetInteriorVehicleData", {
    moduleType = pModuleType,
    subscribe = true
  })

  EXPECT_HMICALL("RC.GetInteriorVehicleData", {
    appID = self.applications["Test Application"],
    moduleType = pModuleType,
    subscribe = true
  })
  :Do(function(_, data)
      self.hmiConnection:SendError(data.id, data.method, pResultCode, "Error error")
    end)

  EXPECT_RESPONSE(cid, { success = false, resultCode = pResultCode })
  :ValidIf(function(_, data) -- no isSubscribed parameter
      if data.payload.isSubscribed == nil then
        return true
      end
      return false, 'Parameter "isSubscribed" is transfered to App with value: ' .. tostring(data.payload.isSubscribed)
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Step("Activate App", commonRC.activate_app)

runner.Title("Test")

for _, mod in pairs(modules) do
  for _, err in pairs(error_codes) do
    runner.Step("Subscribe app to " .. mod .. " (" .. err .. " from HMI)", subscriptionToModule, { mod, err })
    runner.Step("Send notification OnInteriorVehicleData " .. mod .. ". App is not subscribed", commonRC.isUnsubscribed, { mod })
  end
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
