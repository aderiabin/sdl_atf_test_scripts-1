---------------------------------------------------------------------------------------------
-- Requirement summary:
--    [Policies] "default" policies and "default_hmi" validation
--
-- Description:
--     Validation of "default_hmi" sub-section in "default" if "default" policies assigned to the application.
--     Checking correct "default_hmi" value - BACKGROUND
--     1. Used preconditions:
--      SDL and HMI are running
--      Delete logs file and policy table
--      Activate app
--
--     2. Performed steps
--      Perform PTU
--
-- Expected result:
--     PoliciesManager must validate "default_hmi" sub-section in "default" and treat it as valid -> PTU invalid
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases_genivi/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases_genivi/commonSteps')

--[[ General Precondition before ATF start ]]
commonFunctions:cleanup_environment()
commonSteps:DeleteLogsFiles()
commonSteps:DeletePolicyTable()

--[[ General Settings for configuration ]]
Test = require('user_modules/shared_testcases_genivi/connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_Activate_app()
  local ServerAddress = commonFunctions:read_parameter_from_smart_device_link_ini("ServerAddress")
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications[config.application1.registerAppInterfaceParams.appName]})
  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,data)
    if data.result.isSDLAllowed ~= true then
      local RequestIdGetMes = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
      EXPECT_HMIRESPONSE(RequestIdGetMes)
      :Do(function()
        self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
          {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = ServerAddress}})
        EXPECT_HMICALL("BasicCommunication.ActivateApp")
        :Do(function(_,_data1)
          self.hmiConnection:SendResponse(_data1.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
        end)
      end)
    end
  end)
  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_Validate_default_hmi_in_default_upon_PTU()
  local RequestIdGetURLS = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(RequestIdGetURLS,{result = {code = 0, method = "SDL.GetURLS", urls = {{url = "http://policies.telematics.ford.com/api/policies"}}}})
  :Do(function(_,data)
    self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
      { requestType = "PROPRIETARY", fileName = "filename" } )
    EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "PROPRIETARY" })
    :Do(function()
      local CorIdSystemRequest = self.mobileSession:SendRPC("SystemRequest",
        { fileName = "PolicyTableUpdate", requestType = "PROPRIETARY" },
        "files/PTU_BackgroundDefaultHMI_InDefault.json")
      local systemRequestId
      EXPECT_HMICALL("BasicCommunication.SystemRequest")
      :Do(function()
        systemRequestId = data.id
        self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
          { policyfile = "/tmp/fs/mp/images/ivsu_cache/PolicyTableUpdate" })
        local function to_run()
          self.hmiConnection:SendResponse(systemRequestId,"BasicCommunication.SystemRequest", "SUCCESS", {})
        end
        RUN_AFTER(to_run, 500)
      end)
      self.mobileSession:ExpectResponse(CorIdSystemRequest, {})
    end)
  end)
  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status = "UPDATING"}, {status = "UP_TO_DATE"}):Times(2)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test