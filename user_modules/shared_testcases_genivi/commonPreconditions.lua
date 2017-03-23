common_functions = require('user_modules/common_functions')
common_functions:DeleteLogsFileAndPolicyTable()
if common_functions:IsFileExist("sdl.pid") then
  os.execute("rm sdl.pid")
end
os.execute("kill -9 $(ps aux | grep -e smartDeviceLinkCore | awk '{print$2}')")
-- Remove app_info.dat to avoid resumption.
if common_functions:IsFileExist(config.pathToSDL  .. "app_info.dat") then
  os.execute("rm -rf " .. config.pathToSDL  .. "app_info.dat")
end
local path_to_sdl_without_bin = string.gsub(config.pathToSDL, "bin/", "")
local sdl_bin_bk = path_to_sdl_without_bin .. "sdl_bin_bk/"
if common_functions:IsDirectoryExist(sdl_bin_bk) == false then
  os.execute("mkdir " .. sdl_bin_bk)
end
if common_functions:IsFileExist(sdl_bin_bk .. "hmi_capabilities.json") then
  os.execute("cp -f -r " .. sdl_bin_bk .. "hmi_capabilities.json " .. config.pathToSDL)
else
  os.execute("cp -f -r " .. config.pathToSDL .. "hmi_capabilities.json " ..  sdl_bin_bk .. "hmi_capabilities.json")
end
if common_functions:IsFileExist(sdl_bin_bk .. "smartDeviceLink.ini") then
  os.execute("cp -f -r " .. sdl_bin_bk .. "smartDeviceLink.ini " .. config.pathToSDL)
else
  os.execute("cp -f -r " .. config.pathToSDL .. "smartDeviceLink.ini " ..  sdl_bin_bk .. "smartDeviceLink.ini")
end
if common_functions:IsFileExist(sdl_bin_bk .. "sdl_preloaded_pt.json") then
  os.execute("cp -f -r " .. sdl_bin_bk .. "sdl_preloaded_pt.json " .. config.pathToSDL)
else
  os.execute("cp -f -r " .. config.pathToSDL .. "sdl_preloaded_pt.json " ..  sdl_bin_bk .. "sdl_preloaded_pt.json")
end

local Preconditions = {}
--------------------------------------------------------------------------------------------------------
-- Precondition for SendLocation script execution: Because of APPLINK-17511 SDL defect hmi_capabilities.json need to be updated : added textfields locationName, locationDescription, addressLines, phoneNumber.
--------------------------------------------------------------------------------------------------------
-- Precondition function is added needed fields.

function Preconditions:GetPathToSDL()
	local pathToSDL = config.pathToSDL
  if pathToSDL:sub(-1) ~= '/' then
    pathToSDL = pathToSDL .. "/"
  end
  return pathToSDL
end

function Preconditions:SendLocationPreconditionUpdateHMICap()
-- Update hmi_capabilities.json
local HmiCapabilities = Preconditions:GetPathToSDL() .. "hmi_capabilities.json"

f = assert(io.open(HmiCapabilities, "r"))

fileContent = f:read("*all")

fileContentTextFields = fileContent:match("%s-\".?textFields.?\"%s-:%s-%[[%w%d%s,:%{%}\"]+%]%s-,?")

	if not fileContentTextFields then
		print ( " \27[31m  textFields is not found in hmi_capabilities.json \27[0m " )
	else

		fileContentTextFieldsContant = fileContent:match("%s-\".?textFields.?\"%s-:%s-%[([%w%d%s,:%{%}\"]+)%]%s-,?")

		if not fileContentTextFieldsContant then
			print ( " \27[31m  textFields contant is not found in hmi_capabilities.json \27[0m " )
		else

			fileContentTextFieldsContantTab = fileContent:match("%s-\".?textFields.?\"%s-:%s-%[.+%{\n([^\n]+)(\"name\")")

			local StringToReplace = fileContentTextFieldsContant

			fileContentLocationNameFind = fileContent:match("locationName")
			if not fileContentLocationNameFind then
				local ContantToAdd = ",\n " .. tostring(fileContentTextFieldsContantTab)  .. "  { \"name\": \"locationName\",\"characterSet\": \"TYPE2SET\",\"width\": 500,\"rows\": 1 }"
				StringToReplace = StringToReplace .. ContantToAdd
			end

			fileContentLocationDescriptionFind = fileContent:match("locationDescription")
			if not fileContentLocationDescriptionFind then
				local ContantToAdd = ",\n " .. tostring(fileContentTextFieldsContantTab)  .. "  { \"name\": \"locationDescription\",\"characterSet\": \"TYPE2SET\",\"width\": 500,\"rows\": 1 }"
				StringToReplace = StringToReplace .. ContantToAdd
			end

			fileContentAddressLinesFind = fileContent:match("addressLines")
			if not fileContentAddressLinesFind then
				local ContantToAdd = ",\n " .. tostring(fileContentTextFieldsContantTab)  .. "  { \"name\": \"addressLines\",\"characterSet\": \"TYPE2SET\",\"width\": 500,\"rows\": 1 }"
				StringToReplace = StringToReplace .. ContantToAdd
			end

			fileContentPhoneNumberFind = fileContent:match("phoneNumber")
			if not fileContentPhoneNumberFind then
				local ContantToAdd = ",\n " .. tostring(fileContentTextFieldsContantTab)  .. "  { \"name\": \"phoneNumber\",\"characterSet\": \"TYPE2SET\",\"width\": 500,\"rows\": 1 }"
				StringToReplace = StringToReplace .. ContantToAdd
			end

			fileContentUpdated  =  string.gsub(fileContent, fileContentTextFieldsContant, StringToReplace)
			f = assert(io.open(HmiCapabilities, "w"))
			f:write(fileContentUpdated)
			f:close()

		end
	end
end


--------------------------------------------------------------------------------------------------------
-- function to update config.lua
function Preconditions:UpdateConfig(paramName, valueToSet)

  local PathToConfig = "./modules/config.lua"

  f = assert(io.open("./modules/config.lua", "r"))

  fileContent = f:read("*all")

  if type(valueToSet) == number then
    WhitespaceChar, fileContentTextFields = fileContent:match("(%s?)(" .. paramName .. "%s?=%s?%d+)%s?\n")
  else
    WhitespaceChar, fileContentTextFields = fileContent:match("(%s?)(" .. paramName .. "%s?=%s?[%w\"\"]+)%s?\n")
  end


  StringToReplace = paramName .. " = ".. tostring(valueToSet)

  if not fileContentTextFields then
      print ( " \27[31m " .. paramName .. " is not found in config.lua \27[0m " )
    else

      fileContentUpdated  =  string.gsub(fileContent, fileContentTextFields, StringToReplace)
      f = assert(io.open(PathToConfig, "w"))
      f:write(fileContentUpdated)
      f:close()
  end

end


----------------------------------------------------------------------------------------------
-- make reserve copy of file (FileName) in /bin folder
function Preconditions:BackupFile(FileName)
  os.execute(" cp " .. Preconditions:GetPathToSDL() .. FileName .. " " .. Preconditions:GetPathToSDL() .. FileName .. "_origin" )
end

-- restore origin of file (FileName) in /bin folder
function Preconditions:RestoreFile(FileName)
  os.execute(" cp " .. Preconditions:GetPathToSDL() .. FileName .. "_origin " .. Preconditions:GetPathToSDL() .. FileName )
  os.execute( " rm -f " .. Preconditions:GetPathToSDL() .. FileName .. "_origin" )
end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: removing from start app registration and remove closing script after SDL disconnect
function Preconditions:Connecttest_without_ExitBySDLDisconnect_WithoutOpenConnectionRegisterApp(FileName)
	-- copy initial connecttest.lua to FileName
	os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

	-- remove connectMobile, startSession call, quit(1) after SDL disconnect
	f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))

	fileContent = f:read("*all")
	f:close()

	local pattertConnectMobileCall = "function .?module%:ConnectMobile.-connectMobile.-end"
	local patternStartSessionCall = "function .?module%:StartSession.-startSession.-end"
	local connectMobileCall = fileContent:match(pattertConnectMobileCall)
	local startSessionCall = fileContent:match(patternStartSessionCall)

	if connectMobileCall == nil then
		print(" \27[31m ConnectMobile functions is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, pattertConnectMobileCall, "")
	end

	if startSessionCall == nil then
		print(" \27[31m StartSession functions is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, patternStartSessionCall, "")
	end

	local patternDisconnect = "print%(\"Disconnected%!%!%!\"%).-quit%(1%)"
	local DisconnectMessage = fileContent:match(patternDisconnect)
	if DisconnectMessage == nil then
		print(" \27[31m 'Disconnected!!!' message is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, patternDisconnect, 'print("Disconnected!!!")')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()
end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: removing close connection  and closing script after SDL disconnect
function Preconditions:Connecttest_without_ExitBySDLDisconnect_OpenConnection(FileName)
	-- copy initial connecttest.lua to FileName
	os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

	-- remove startSession call, quit(1) after SDL disconnect
	f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))

	fileContent = f:read("*all")
	f:close()

	local patternStartSessionCall = "function .?module%:StartSession.-startSession.-end"
	local startSessionCall = fileContent:match(patternStartSessionCall)

	if startSessionCall == nil then
		print(" \27[31m StartSession functions is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, patternStartSessionCall, "")
	end

	local patternDisconnect = "print%(\"Disconnected%!%!%!\"%).-quit%(1%)"
	local DisconnectMessage = fileContent:match(patternDisconnect)
	if DisconnectMessage == nil then
		print(" \27[31m 'Disconnected!!!' message is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, patternDisconnect, 'print("Disconnected!!!")')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()
end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: removing closing script after SDL disconnect
function Preconditions:Connecttest_without_ExitBySDLDisconnect(FileName)
	-- copy initial connecttest.lua to FileName
	os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

	-- remove quit(1) after SDL disconnect
	f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))

	fileContent = f:read("*all")
	f:close()

	local patternDisconnect = "print%(\"Disconnected%!%!%!\"%).-quit%(1%)"
	local DisconnectMessage = fileContent:match(patternDisconnect)
	if DisconnectMessage == nil then
		print(" \27[31m 'Disconnected!!!' message is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, patternDisconnect, 'print("Disconnected!!!")')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()
end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: adding self.timeOnReady = timestamp() string to connect test
function Preconditions:Connecttest_adding_timeOnReady(FileName, createFile)
	if createFile == true then
		-- copy initial connecttest.lua to FileName
		os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	else
		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	end

	fileContent = f:read("*all")
	f:close()

	local SearchPattern = 'self.hmiConnection%:.?SendNotification.?%(.?"BasicCommunication.OnReady".?%)'
	local OnReadyNotFinding = fileContent:match(SearchPattern)
	if OnReadyNotFinding == nil then
		print(" \27[31m 'self.hmiConnection:SendNotification(\"BasicCommunication.OnReady\")' string is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, SearchPattern, 'self.hmiConnection:SendNotification("BasicCommunication.OnReady")\nself.timeOnReady = timestamp()')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()

end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: sending Navigation.IsReady{ available = false } from HMI
function Preconditions:Connecttest_Navigation_IsReady_available_false(FileName, createFile)
	if createFile == true then
		-- copy initial connecttest.lua to FileName
		os.execute(  'cp ./connecttest.lua  ./user_modules/'  .. tostring(FileName))

		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	else
		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	end

	fileContent = f:read("*all")
	f:close()

	local SearchPattern = '%(%s?\"%s?Navigation.IsReady%s?\"%s?, %s?true%s?, %s?%{ %s?available %s?=%s?[%w]-%s-%}%)'
	local OnReadyNotFinding = fileContent:match(SearchPattern)
	if OnReadyNotFinding == nil then
		print(" \27[31m '(\"Navigation.IsReady\", true, { available = true })' string is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, SearchPattern, '("Navigation.IsReady", true, { available = false })')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()

end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: adding Buttons.OnButtonSubscription
function Preconditions:Connecttest_OnButtonSubscription(FileName, createFile)
	if createFile == true then
		-- copy initial connecttest.lua to FileName
		os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	else
		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	end

	fileContent = f:read("*all")
	f:close()

	-- add "Buttons.OnButtonSubscription"
	local pattern1 = "registerComponent%s-%(%s-\"Buttons\"%s-[%w%s%{%}.,\"]-%)"
	local pattern1Result = fileContent:match(pattern1)

	if pattern1Result == nil then
		print(" \27[31m Buttons registerComponent function is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		fileContent  =  string.gsub(fileContent, pattern1, 'registerComponent("Buttons", {"Buttons.OnButtonSubscription"})')
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()

end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: adding languages in language array
function Preconditions:Connecttest_Languages_update(FileName, createFile)
	if createFile == true then
		-- copy initial connecttest.lua to FileName
		os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	else
		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	end

	fileContent = f:read("*all")
	f:close()

	local function LanguageCheck(FileContent)
		local AddedLanguage = ""
		if not FileContent:match("NL%-BE") then
			AddedLanguage = AddedLanguage .. '"NL-BE",'
		end

		if not FileContent:match("EL%-GR") then
			AddedLanguage = AddedLanguage .. '"EL-GR",'
		end

		if not FileContent:match("HU%-HU") then
			AddedLanguage = AddedLanguage .. '"HU-HU",'
		end

		if not FileContent:match("FI%-FI") then
			AddedLanguage = AddedLanguage .. '"FI-FI",'
		end

		if not FileContent:match("SK%-SK") then
			AddedLanguage = AddedLanguage .. '"SK-SK",'
		end

		return AddedLanguage
	end

	-- update VR.GetSupportedLanguages with new language
	local pattern1 = 'ExpectRequest%s-%(%s-"VR.GetSupportedLanguages".-%{.-%}%s-%)'
	local pattern1Result = fileContent:match(pattern1)

	if pattern1Result == nil then
		print(" \27[31m ExpectRequest VR.GetSupportedLanguages function call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		local StringToAdd = LanguageCheck(pattern1Result)

		local pattern1_1 = 'ExpectRequest%s-%(%s-"VR.GetSupportedLanguages".-%{%s-languages%s-=%s-%{'
		local pattern1_1Result = pattern1Result:match(pattern1_1)
		if pattern1_1Result == nil then
			print(" \27[31m VR.GetSupportedLanguages call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
		else
			pattern1Result  =  string.gsub(pattern1Result, pattern1_1, pattern1_1Result .. StringToAdd)
			fileContent  =  string.gsub(fileContent, pattern1, pattern1Result)
		end
	end

	-- update TTS.GetSupportedLanguages with new language
	local pattern2 = 'ExpectRequest%s-%(%s-"TTS.GetSupportedLanguages".-%{.-%}%s-%)'
	local pattern2Result = fileContent:match(pattern2)

	if pattern2Result == nil then
		print(" \27[31m ExpectRequest TTS.GetSupportedLanguages function call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		local StringToAdd = LanguageCheck(pattern2Result)

		local pattern2_1 = 'ExpectRequest%s-%(%s-"TTS.GetSupportedLanguages".-%{%s-languages%s-=%s-%{'
		local pattern2_1Result = pattern2Result:match(pattern2_1)
		if pattern2_1Result == nil then
			print(" \27[31m TTS.GetSupportedLanguages call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
		else
			pattern2Result  =  string.gsub(pattern2Result, pattern2_1, pattern2_1Result .. StringToAdd)
			fileContent  =  string.gsub(fileContent, pattern2, pattern2Result)
		end
	end

	-- update UI.GetSupportedLanguages with new language
	local pattern3 = 'ExpectRequest%s-%(%s-"UI.GetSupportedLanguages".-%{.-%}%s-%)'
	local pattern3Result = fileContent:match(pattern3)

	if pattern3Result == nil then
		print(" \27[31m ExpectRequest UI.GetSupportedLanguages function call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
	else
		local StringToAdd = LanguageCheck(pattern3Result)

		local pattern3_1 = 'ExpectRequest%s-%(%s-"UI.GetSupportedLanguages".-%{%s-languages%s-=%s-%{'
		local pattern3_1Result = pattern3Result:match(pattern3_1)
		if pattern3_1Result == nil then
			print(" \27[31m UI.GetSupportedLanguages call is not found in /user_modules/" .. tostring(FileName) .. " \27[0m ")
		else
			pattern3Result  =  string.gsub(pattern3Result, pattern3_1, pattern3_1Result .. StringToAdd)
			fileContent  =  string.gsub(fileContent, pattern3, pattern3Result)
		end
	end

	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()

end

--------------------------------------------------------------------------------------------------------
-- Updating user connect test: removing InitHMI_onReady call
function Preconditions:Connecttest_InitHMI_onReady_call(FileName, createFile)
	if createFile == true then
		-- copy initial connecttest.lua to FileName
		os.execute(  'cp ./user_modules/shared_testcases_genivi/connecttest.lua  ./user_modules/'  .. tostring(FileName))

		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	else
		-- open file
		f = assert(io.open('./user_modules/'  .. tostring(FileName), "r"))
	end

	fileContent = f:read("*all")
	f:close()

  	local pattern1 = "function .?module%:InitHMI_onReady.-initHMI_onReady.-end"
  	local pattern1Result = fileContent:match(pattern1)

  	if pattern1Result == nil then
    	print(" \27[31m InitHMI_onReady functions is not found in /user_modules/" .. tostring(FileName) " \27[0m ")
  	else
    	fileContent  =  string.gsub(fileContent, pattern1, "")
  	end

  	f = assert(io.open('./user_modules/' .. tostring(FileName), "w+"))
	f:write(fileContent)
	f:close()

end

return Preconditions