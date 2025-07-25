local SettingsManager = {}
SettingsManager.__index = SettingsManager

-- Version info
SettingsManager.VERSION = "1.0.0"
SettingsManager.AUTHOR = "Genzura Hub"

-- Create new settings manager instance
function SettingsManager.new(config)
    local self = setmetatable({}, SettingsManager)
    
    -- Configuration
    self.SETTINGS_FILE = config.fileName or "ScriptSettings.json"
    self.AUTO_SAVE_INTERVAL = config.autoSaveInterval or 30
    self.DEBUG_MODE = config.debug or false
    
    -- Default settings structure
    self.DEFAULT_SETTINGS = config.defaultSettings or {
        toggles = {},
        dropdowns = {},
        inputs = {},
        other = {}
    }
    
    -- Initialize getgenv storage with unique key
    local envKey = config.envKey or "ScriptSettings"
    if not getgenv()[envKey] then
        getgenv()[envKey] = {}
    end
    
    self.currentSettings = getgenv()[envKey]
    self.envKey = envKey
    self.autoSaveConnection = nil
    self.isInitialized = false
    
    return self
end

-- Debug logging (removed - silent operation)
function SettingsManager:log(message, level)
    -- Silent operation - no console output
end

-- Deep copy function for tables
function SettingsManager:deepCopy(original)
    if type(original) ~= "table" then return original end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = self:deepCopy(value)
    end
    return copy
end

-- Merge two tables (second table overwrites first)
function SettingsManager:mergeTables(table1, table2)
    local result = self:deepCopy(table1)
    
    if type(table2) ~= "table" then return result end
    
    for key, value in pairs(table2) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = self:mergeTables(result[key], value)
        else
            result[key] = self:deepCopy(value)
        end
    end
    
    return result
end

-- File operations
function SettingsManager:saveToFile()
    if not writefile then
        self:log("writefile not supported by executor", "warning")
        return false
    end
    
    local success, err = pcall(function()
        local jsonData = game:GetService("HttpService"):JSONEncode(self.currentSettings)
        writefile(self.SETTINGS_FILE, jsonData)
    end)
    
    if success then
        self:log("Settings saved to file: " .. self.SETTINGS_FILE, "success")
        return true
    else
        warn("Failed to save settings: " .. tostring(err))
        return false
    end
end

function SettingsManager:loadFromFile()
    if not readfile or not isfile then
        self:log("File operations not supported", "warning")
        return nil
    end
    
    if not isfile(self.SETTINGS_FILE) then
        self:log("Settings file not found: " .. self.SETTINGS_FILE)
        return nil
    end
    
    local success, result = pcall(function()
        local jsonData = readfile(self.SETTINGS_FILE)
        return game:GetService("HttpService"):JSONDecode(jsonData)
    end)
    
    if success and type(result) == "table" then
        self:log("Settings loaded from file: " .. self.SETTINGS_FILE, "success")
        return result
    else
        warn("Failed to load settings: " .. tostring(result))
        return nil
    end
end

-- Initialize the settings system
function SettingsManager:init()
    if self.isInitialized then
        self:log("Already initialized", "warning")
        return self
    end
    
    -- Try to load from file first
    local fileSettings = self:loadFromFile()
    
    if fileSettings then
        -- Merge file settings with defaults to ensure all keys exist
        self.currentSettings = self:mergeTables(self.DEFAULT_SETTINGS, fileSettings)
        getgenv()[self.envKey] = self.currentSettings
        self:log("Loaded settings from file and merged with defaults")
    else
        -- Check if we have session settings
        if next(self.currentSettings) == nil then
            -- No settings exist, use defaults
            self.currentSettings = self:deepCopy(self.DEFAULT_SETTINGS)
            getgenv()[self.envKey] = self.currentSettings
            self:log("Initialized with default settings")
        else
            -- Merge existing session settings with defaults
            self.currentSettings = self:mergeTables(self.DEFAULT_SETTINGS, self.currentSettings)
            getgenv()[self.envKey] = self.currentSettings
            self:log("Using existing session settings, merged with defaults")
        end
    end
    
    -- Start auto-save
    self:startAutoSave()
    self.isInitialized = true
    
    self:log("Settings Manager initialized successfully", "success")
    return self
end

-- Auto-save functionality
function SettingsManager:startAutoSave()
    if self.autoSaveConnection then
        self.autoSaveConnection:Disconnect()
    end
    
    self.autoSaveConnection = task.spawn(function()
        while self.isInitialized do
            task.wait(self.AUTO_SAVE_INTERVAL)
            self:saveToFile()
        end
    end)
    
    self:log("Auto-save started (interval: " .. self.AUTO_SAVE_INTERVAL .. "s)")
end

function SettingsManager:stopAutoSave()
    if self.autoSaveConnection then
        task.cancel(self.autoSaveConnection)
        self.autoSaveConnection = nil
        self:log("Auto-save stopped")
    end
end

-- Core setting functions
function SettingsManager:setSetting(category, key, value)
    if not self.isInitialized then
        self:log("Not initialized. Call :init() first", "error")
        return false
    end
    
    if not self.currentSettings[category] then
        self.currentSettings[category] = {}
    end
    
    self.currentSettings[category][key] = self:deepCopy(value)
    getgenv()[self.envKey] = self.currentSettings
    
    self:log(string.format("Setting saved: %s.%s = %s", category, key, tostring(value)))
    return true
end

function SettingsManager:getSetting(category, key, defaultValue)
    if not self.isInitialized then
        self:log("Not initialized. Call :init() first", "error")
        return defaultValue
    end
    
    if self.currentSettings[category] and self.currentSettings[category][key] ~= nil then
        return self.currentSettings[category][key]
    end
    
    return defaultValue
end

function SettingsManager:getAllSettings()
    return self:deepCopy(self.currentSettings)
end

function SettingsManager:hasCategory(category)
    return self.currentSettings[category] ~= nil
end

function SettingsManager:hasSetting(category, key)
    return self.currentSettings[category] and self.currentSettings[category][key] ~= nil
end

-- Convenience functions for common types
function SettingsManager:saveToggle(toggleName, value)
    return self:setSetting("toggles", toggleName, value)
end

function SettingsManager:loadToggle(toggleName, defaultValue)
    return self:getSetting("toggles", toggleName, defaultValue == nil and false or defaultValue)
end

function SettingsManager:saveDropdown(dropdownName, selectedValues)
    return self:setSetting("dropdowns", dropdownName, selectedValues)
end

function SettingsManager:loadDropdown(dropdownName, defaultValue)
    return self:getSetting("dropdowns", dropdownName, defaultValue or {})
end

function SettingsManager:saveInput(inputName, value)
    return self:setSetting("inputs", inputName, value)
end

function SettingsManager:loadInput(inputName, defaultValue)
    return self:getSetting("inputs", inputName, defaultValue or "")
end

function SettingsManager:saveOther(key, value)
    return self:setSetting("other", key, value)
end

function SettingsManager:loadOther(key, defaultValue)
    return self:getSetting("other", key, defaultValue)
end

-- Batch operations
function SettingsManager:saveMultiple(settings)
    if type(settings) ~= "table" then return false end
    
    for category, categoryData in pairs(settings) do
        if type(categoryData) == "table" then
            for key, value in pairs(categoryData) do
                self:setSetting(category, key, value)
            end
        end
    end
    
    return true
end

function SettingsManager:loadMultiple(settingsMap, defaultValues)
    local result = {}
    defaultValues = defaultValues or {}
    
    for category, keys in pairs(settingsMap) do
        result[category] = {}
        for _, key in pairs(keys) do
            local defaultVal = defaultValues[category] and defaultValues[category][key]
            result[category][key] = self:getSetting(category, key, defaultVal)
        end
    end
    
    return result
end

-- Management functions
function SettingsManager:save()
    return self:saveToFile()
end

function SettingsManager:reset(keepFile)
    self.currentSettings = self:deepCopy(self.DEFAULT_SETTINGS)
    getgenv()[self.envKey] = self.currentSettings
    
    if not keepFile then
        self:saveToFile()
    end
    
    self:log("Settings reset to defaults", "success")
    return true
end

function SettingsManager:clear()
    self.currentSettings = {}
    getgenv()[self.envKey] = self.currentSettings
    
    self:log("All settings cleared")
    return true
end

function SettingsManager:export()
    return game:GetService("HttpService"):JSONEncode(self.currentSettings)
end

function SettingsManager:import(jsonString)
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(jsonString)
    end)
    
    if success and type(data) == "table" then
        self.currentSettings = data
        getgenv()[self.envKey] = self.currentSettings
        self:log("Settings imported successfully", "success")
        return true
    else
        warn("Failed to import settings: Invalid JSON")
        return false
    end
end

-- Cleanup
function SettingsManager:destroy()
    self:stopAutoSave()
    self:saveToFile()
    self.isInitialized = false
    self:log("Settings Manager destroyed", "success")
end

-- Static create function for easy usage
function SettingsManager.create(config)
    return SettingsManager.new(config):init()
end

-- Return the module
return SettingsManager
