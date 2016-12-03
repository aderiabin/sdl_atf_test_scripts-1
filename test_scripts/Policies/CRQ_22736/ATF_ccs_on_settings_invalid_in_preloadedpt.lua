require('user_modules/all_common_modules')
--------------------------------- Variables -----------------------------------
local parent_item = {"policy_table", "functional_groupings", "Location-1"}
local sql_query = "select * from entities, functional_group where entities.group_id = functional_group.id"

------------------------------- Common functions -------------------------------
local match_result = "null"
local temp_replace_value = "\"Thi123456789\""
-- Add new structure into json_file
local function AddItemsIntoJsonFile(test_case_name, parent_item, added_json_items)
  Test["AddItemsIntoJsonFile"..test_case_name] = function (self)
    local json_file = config.pathToSDL .. 'sdl_preloaded_pt.json'
    local file = io.open(json_file, "r")
    local json_data = file:read("*all")
    file:close()
    json_data_update = string.gsub(json_data, match_result, temp_replace_value)
    local json = require("modules/json")
    local data = json.decode(json_data_update)
    -- Go to parent item
    local parent = data
    for i = 1, #parent_item do
      if not parent[parent_item[i]] then
        parent[parent_item[i]] = {}
      end
      parent = parent[parent_item[i]]
    end
    if type(added_json_items) == "string" then
      added_json_items = json.decode(added_json_items)
    end
    
    for k, v in pairs(added_json_items) do
      parent[k] = v
    end
    
    data = json.encode(data)	
    data_revert = string.gsub(data, temp_replace_value, match_result)
    file = io.open(json_file, "w")
    file:write(data_revert)
    file:close()	
  end
end

-- Verify new parameter is not saved in LPT
local function CheckPolicyTable(test_case_name, sql_query)
	Test[test_case_name] = function (self)
		-- Look for policy.sqlite file
		local policy_file1 = config.pathToSDL .. "storage/policy.sqlite"
		local policy_file2 = config.pathToSDL .. "policy.sqlite"
		local policy_file
		if common_functions:IsFileExist(policy_file1) then
			policy_file = policy_file1
		elseif common_functions:IsFileExist(policy_file2) then
			policy_file = policy_file2
		else
			common_functions:PrintError(" \27[32m policy.sqlite file is not exist \27[0m ")
		end
		if policy_file then
			local ful_sql_query = "sqlite3 " .. policy_file .. " \"" .. sql_query .. "\""
			local handler = io.popen(ful_sql_query, 'r')
			os.execute("sleep 1")
			local result = handler:read( '*l' )
			handler:close()
			if(result==nil) then
				return true
			else
				self:FailTestCase("SDL saved disallowed_by_ccs_entities_on although existed invalid settings in PreloadedPT.")
				return false
			end
		end
	end
end

-- Verify SDL can't start with invalid parameter in PreloadedPT
local function VerifySDLShutDownWithInvalidParamInPreloadedPT(test_case_name)
	Test["SDLShutDownWith"..test_case_name] = function (self)
		os.execute(" sleep 1 ")
		-- Remove sdl.pid file on ATF folder in case SDL is stopped not by script.
		os.execute("rm sdl.pid") 
		local status = sdl:CheckStatusSDL()
		if (status == 1) then
			self:FailTestCase(" smartDeviceLinkCore process is not stopped ")
			return false
		end
		common_functions:PrintError(" \27[32m SDL has already stoped.")
		return true
	end
end

------------------------------- Preconditions ---------------------------------
common_steps:BackupFile("Precondition_Backup_PreloadedPT", "sdl_preloaded_pt.json")

--------------------------------- BODY ----------------------------------------
-- Precondition: invalid disallowed_by_ccs_entities_on parameter existed in PreloadedPT 
-- Verification criteria: SDL considers PreloadedPT as invalid and shut SDL down
-------------------------------------------------------------------------------
-- Define disallowed_by_ccs_entities_on contains 101 entities
local out_upper_bound = {}
out_upper_bound.disallowed_by_ccs_entities_on = {}
for i = 1, 101 do
	table.insert(out_upper_bound.disallowed_by_ccs_entities_on, 
	{
		entityType = i,
		entityID = i
	}
	)
end
-- Define disallowed_by_ccs_entities_on contains 0 entity
local out_lower_bound = {
	disallowed_by_ccs_entities_on, 
	{
	}
}
-- Define disallowed_by_ccs_entities_on is invalid type (not array) 
local invalid_type = {
	disallowed_by_ccs_entities_on = {
		{
			10
		}
	} 
}
-- Define disallowed_by_ccs_entities_on contains valid entity and invalid entity
local valid_invalid_param = {
	disallowed_by_ccs_entities_on = { 
		{entityType = 100,
			entityID = 15
		},
		{entityType = "HELLO",
			entityID = 15
		}
	}
}

local test_data = {
	{description = "Out_Upper_Bound", value = out_upper_bound},
	{description = "Out_Lower_Bound", value = out_lower_bound},
	{description = "Invalid_Type", value = invalid_type},
	{description = "Existed_Valid_Invalid_Parm", value = valid_invalid_param}
}

for j=1, #test_data do
	local test_case_name = "TC_" ..test_data[j].description
	
	common_steps:AddNewTestCasesGroup(test_case_name)	
	
	Test[test_case_name .. "_Precondition_StopSDL"] = function(self)
		StopSDL()
	end	
	
	Test[test_case_name .. "_RemoveExistedLPT"] = function (self)
		common_functions:DeletePolicyTable()
	end 	
	
	common_steps:RestoreIniFile("Restore_PreloadedPT", "sdl_preloaded_pt.json")
	AddItemsIntoJsonFile(test_case_name, parent_item, test_data[j].value)
	
	Test[test_case_name .. "_StartSDL_WithInvalidParamInPreloadedPT"] = function(self)
		sdl.exitOnCrash = false
		StartSDL(config.pathToSDL, false)
	end	
	
	VerifySDLShutDownWithInvalidParamInPreloadedPT(test_case_name)
	CheckPolicyTable(test_case_name.."_CheckInvalidEntitiesOnNotExistedInLPT", sql_query)
end

-------------------------------------- Postconditions ----------------------------------------
common_steps:RestoreIniFile("Restore_PreloadedPT", "sdl_preloaded_pt.json")