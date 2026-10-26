-- CB HUB | KEY SYSTEM + MULTI-LANGUAGE (TH / EN) & MARK & WAYPOINT
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

if _G.CBHubCleanup then
    pcall(_G.CBHubCleanup)
end

local RED = Color3.fromRGB(255, 48, 68)
local RED_DARK = Color3.fromRGB(100, 20, 34)
local BG = Color3.fromRGB(13, 14, 19)
local PANEL = Color3.fromRGB(23, 25, 33)
local PANEL2 = Color3.fromRGB(32, 34, 44)
local WHITE = Color3.fromRGB(245, 246, 250)
local MUTED = Color3.fromRGB(145, 149, 165)
local GREEN = Color3.fromRGB(95, 230, 160)

local alive = true
local marks = {}       
local keybinds = {}    
local connections = {}

local savedConfigs = {} 
local SAVE_FILENAME = "CBHub_SavedConfigs.json"

local selected = nil
local selectedSaveConfig = nil
local draftKey = nil
local waitingForMarkKey = false
local waitingForToggleKey = false
local toggleKey = Enum.KeyCode.RightAlt
local minimized = false
local currentLang = "TH" -- ค่าเริ่มต้นภาษาไทย ("TH" หรือ "EN")

local gui

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getKeyFromValue(val)
    if not val then return nil end
    for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
        if item.Value == val then
            return item
        end
    end
    return nil
end

local function saveToFile()
    if not writefile then return end
    local dataToSave = {}
    for configName, data in pairs(savedConfigs) do
        dataToSave[configName] = {
            marks = {},
            keybinds = {},
            toggleKey = data.toggleKey and data.toggleKey.Value or Enum.KeyCode.RightAlt.Value
        }
        for mName, pos in pairs(data.marks) do
            dataToSave[configName].marks[mName] = {pos.X, pos.Y, pos.Z}
        end
        for mName, keyCode in pairs(data.keybinds) do
            if keyCode then
                dataToSave[configName].keybinds[mName] = keyCode.Value
            end
        end
    end
    pcall(function()
        writefile(SAVE_FILENAME, HttpService:JSONEncode(dataToSave))
    end)
end

local function loadFromFile()
    if not readfile or not isfile or not isfile(SAVE_FILENAME) then return end
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(SAVE_FILENAME))
    end)
    if ok and type(result) == "table" then
        savedConfigs = {}
        for configName, data in pairs(result) do
            savedConfigs[configName] = { marks = {}, keybinds = {}, toggleKey = Enum.KeyCode.RightAlt }
            if data.marks then
                for mName, coords in pairs(data.marks) do
                    if type(coords) == "table" and #coords >= 3 then
                        savedConfigs[configName].marks[mName] = Vector3.new(coords[1], coords[2], coords[3])
                    end
                end
            end
            if data.keybinds then
                for mName, val in pairs(data.keybinds) do
                    local kc = getKeyFromValue(val)
                    if kc then
                        savedConfigs[configName].keybinds[mName] = kc
                    end
                end
            end
            if data.toggleKey then
                local tk = getKeyFromValue(data.toggleKey)
                if tk then
                    savedConfigs[configName].toggleKey = tk
                end
            end
        end
    end
end

loadFromFile()

local function cleanup()
    if not alive then return end
    alive = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)
    table.clear(marks)
    table.clear(keybinds)

    if gui then
        gui:Destroy()
        gui = nil
    end

    _G.CBHubCleanup = nil
end

gui = Instance.new("ScreenGui")
gui.Name = "CBHub_KeySystem_Lang"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ok = pcall(function()
    gui.Parent = CoreGui
end)

if not ok or not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

_G.CBHubCleanup = cleanup

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or RED
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = obj
end

local function makeLabel(parent, text, size, pos, textSize, color, bold)
    local label = Instance.new("TextLabel")
    label.Size = size
    label.Position = pos
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or WHITE
    label.TextSize = textSize or 13
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeButton(parent, text, size, pos, accent)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = accent and RED_DARK or PANEL2
    b.Text = text
    b.TextColor3 = WHITE
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Parent = parent

    corner(b, 7)
    stroke(
        b,
        accent and RED or Color3.fromRGB(55, 59, 73),
        1,
        0.15
    )

    return b
end

-- ==================== [ หน้าต่างใส่คีย์ (Key UI) ] ====================
local keyWindow = Instance.new("Frame")
keyWindow.Name = "KeyWindow"
keyWindow.Size = UDim2.fromOffset(320, 210)
keyWindow.Position = UDim2.new(0.5, -160, 0.5, -105)
keyWindow.BackgroundColor3 = BG
keyWindow.BorderSizePixel = 0
keyWindow.Active = true
keyWindow.ClipsDescendants = true
keyWindow.Parent = gui

corner(keyWindow, 12)
stroke(keyWindow, RED, 1.5, 0.1)

local keyHeader = Instance.new("Frame")
keyHeader.Size = UDim2.new(1, 0, 0, 45)
keyHeader.BackgroundColor3 = PANEL
keyHeader.BorderSizePixel = 0
keyHeader.Parent = keyWindow

corner(keyHeader, 12)

local keyTitleLabel = makeLabel(
    keyHeader, "CB HUB - Key Verification",
    UDim2.new(1, -20, 0, 25),
    UDim2.fromOffset(14, 10),
    14, WHITE, true
)

local keyInputBox = Instance.new("TextBox")
keyInputBox.Size = UDim2.new(1, -28, 0, 38)
keyInputBox.Position = UDim2.fromOffset(14, 65)
keyInputBox.BackgroundColor3 = PANEL
keyInputBox.TextColor3 = WHITE
keyInputBox.PlaceholderText = "Enter your key here..."
keyInputBox.PlaceholderColor3 = MUTED
keyInputBox.Text = ""
keyInputBox.ClearTextOnFocus = false
keyInputBox.Font = Enum.Font.Gotham
keyInputBox.TextSize = 13
keyInputBox.TextXAlignment = Enum.TextXAlignment.Left
keyInputBox.Parent = keyWindow

corner(keyInputBox, 8)
stroke(keyInputBox, Color3.fromRGB(55, 59, 73), 1)

local keyInputPadding = Instance.new("UIPadding")
keyInputPadding.PaddingLeft = UDim.new(0, 11)
keyInputPadding.PaddingRight = UDim.new(0, 8)
keyInputPadding.Parent = keyInputBox

local submitKeyBtn = makeButton(
    keyWindow, "Verify Key",
    UDim2.new(1, -28, 0, 38),
    UDim2.fromOffset(14, 115),
    true
)

local keyStatusLabel = makeLabel(
    keyWindow, "",
    UDim2.new(1, -28, 0, 20),
    UDim2.fromOffset(14, 162),
    11, RED, false
)
keyStatusLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ==================== [ หน้าต่างหลัก (Main UI) ซ่อนไว้ก่อน ] ====================
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(365, 490)
main.Position = UDim2.new(0.5, -182, 0.5, -245)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Visible = false 
main.Parent = gui

corner(main, 12)
stroke(main, RED, 1.5, 0.1)

-- HEADER
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = PANEL
header.BorderSizePixel = 0
header.Active = true
header.Parent = main

corner(header, 12)

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, 0, 0, 2)
headerAccent.Position = UDim2.new(0, 0, 1, -2)
headerAccent.BackgroundColor3 = RED
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(32, 32)
logo.Position = UDim2.fromOffset(12, 9)
logo.BackgroundColor3 = RED_DARK
logo.BorderSizePixel = 0
logo.Parent = header

corner(logo, 9)
stroke(logo, RED, 1)

local logoText = makeLabel(
    logo, "C",
    UDim2.fromScale(1, 1),
    UDim2.new(),
    18, WHITE, true
)
logoText.TextXAlignment = Enum.TextXAlignment.Center

local titleMain = makeLabel(
    header, "CB HUB",
    UDim2.new(0, 145, 0, 23),
    UDim2.fromOffset(52, 6),
    16, WHITE, true
)

local subTitleMain = makeLabel(
    header, "Waypoint System",
    UDim2.new(0, 160, 0, 16),
    UDim2.fromOffset(53, 27),
    10, MUTED, true
)

-- ปุ่มเปลี่ยนภาษา (TH / EN)
local langBtn = makeButton(
    header, "LANG: TH",
    UDim2.fromOffset(70, 26),
    UDim2.new(1, -140, 0, 13)
)
langBtn.TextSize = 11

local minimizeBtn = makeButton(
    header, "—",
    UDim2.fromOffset(29, 28),
    UDim2.new(1, -68, 0, 12)
)

local closeBtn = makeButton(
    header, "×",
    UDim2.fromOffset(29, 28),
    UDim2.new(1, -34, 0, 12),
    true
)
closeBtn.TextSize = 19

-- SCROLLABLE CONTENT
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(12, 62)
content.Size = UDim2.new(1, -24, 1, -74)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = RED
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.Active = true
content.Parent = main

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingBottom = UDim.new(0, 14)
contentPadding.Parent = content

local lblCreate = makeLabel(
    content, "Create Waypoint",
    UDim2.new(1, 0, 0, 22),
    UDim2.fromOffset(2, 0),
    12, RED, true
)

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, 0, 0, 39)
nameBox.Position = UDim2.fromOffset(0, 27)
nameBox.BackgroundColor3 = PANEL
nameBox.TextColor3 = WHITE
nameBox.PlaceholderText = "Enter waypoint name..."
nameBox.PlaceholderColor3 = MUTED
nameBox.Text = ""
nameBox.ClearTextOnFocus = false
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 13
nameBox.TextXAlignment = Enum.TextXAlignment.Left
nameBox.Parent = content

corner(nameBox, 8)
stroke(nameBox, Color3.fromRGB(55, 59, 73), 1)

local namePadding = Instance.new("UIPadding")
namePadding.PaddingLeft = UDim.new(0, 11)
namePadding.PaddingRight = UDim.new(0, 8)
namePadding.Parent = nameBox

local lblKeybind = makeLabel(
    content, "Teleport Keybind",
    UDim2.new(1, 0, 0, 19),
    UDim2.fromOffset(2, 74),
    11, MUTED, true
)

local keyBtn = makeButton(
    content, "＋   Select Keybind  ·  (Optional)",
    UDim2.new(1, 0, 0, 37),
    UDim2.fromOffset(0, 96)
)

local clearKeyBtn = makeButton(
    content, "Clear",
    UDim2.fromOffset(65, 29),
    UDim2.new(1, -65, 0, 139)
)

local keyStatus = makeLabel(
    content, "Current Key: None",
    UDim2.new(1, -75, 0, 29),
    UDim2.fromOffset(3, 139),
    11, MUTED, false
)

local createBtn = makeButton(
    content, "＋   Save Waypoint",
    UDim2.new(1, 0, 0, 39),
    UDim2.fromOffset(0, 178),
    true
)

local lblList = makeLabel(
    content, "Waypoints List",
    UDim2.new(1, -100, 0, 24),
    UDim2.fromOffset(2, 229),
    12, RED, true
)

local countLabel = makeLabel(
    content, "0 Points",
    UDim2.fromOffset(95, 24),
    UDim2.new(1, -95, 0, 229),
    10, MUTED, true
)
countLabel.TextXAlignment = Enum.TextXAlignment.Right

local rows = Instance.new("Frame")
rows.Position = UDim2.fromOffset(0, 258)
rows.Size = UDim2.new(1, 0, 0, 145)
rows.BackgroundColor3 = PANEL
rows.BorderSizePixel = 0
rows.Parent = content

corner(rows, 9)
stroke(rows, Color3.fromRGB(49, 52, 66), 1)

local rowScroll = Instance.new("ScrollingFrame")
rowScroll.Position = UDim2.fromOffset(6, 6)
rowScroll.Size = UDim2.new(1, -12, 1, -12)
rowScroll.BackgroundTransparency = 1
rowScroll.BorderSizePixel = 0
rowScroll.ScrollBarThickness = 3
rowScroll.ScrollBarImageColor3 = RED
rowScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rowScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rowScroll.Parent = rows

local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding = UDim.new(0, 5)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = rowScroll

local teleportBtn = makeButton(
    content, "Teleport to Selected",
    UDim2.new(1, 0, 0, 35),
    UDim2.fromOffset(0, 412)
)

local deleteSelectedBtn = makeButton(
    content, "Delete Selected",
    UDim2.new(0.5, -4, 0, 33),
    UDim2.fromOffset(0, 455)
)

local deleteAllBtn = makeButton(
    content, "Delete All",
    UDim2.new(0.5, -4, 0, 33),
    UDim2.new(0.5, 4, 0, 455)
)

local saveSettingsBtn = makeButton(
    content, "Save Profiles",
    UDim2.new(1, 0, 0, 34),
    UDim2.fromOffset(0, 497),
    true
)

local toggleBtn = makeButton(
    content, "UI Toggle Key: RightAlt",
    UDim2.new(1, 0, 0, 34),
    UDim2.fromOffset(0, 539)
)

-- EMPTY PAGE (SAVE & LOAD UI PAGE)
local emptyPage = Instance.new("Frame")
emptyPage.Name = "EmptyPage"
emptyPage.Size = UDim2.fromOffset(365, 490)
emptyPage.Position = UDim2.new(0.5, -182, 0.5, -245)
emptyPage.BackgroundColor3 = BG
emptyPage.BorderSizePixel = 0
emptyPage.Visible = false
emptyPage.Active = true
emptyPage.ClipsDescendants = true
emptyPage.Parent = gui

corner(emptyPage, 12)
stroke(emptyPage, RED, 1.5, 0.1)

local emptyHeader = Instance.new("Frame")
emptyHeader.Size = UDim2.new(1, 0, 0, 52)
emptyHeader.BackgroundColor3 = PANEL
emptyHeader.BorderSizePixel = 0
emptyHeader.Active = true
emptyHeader.Parent = emptyPage

corner(emptyHeader, 12)

local emptyAccent = Instance.new("Frame")
emptyAccent.Size = UDim2.new(1, 0, 0, 2)
emptyAccent.Position = UDim2.new(0, 0, 1, -2)
emptyAccent.BackgroundColor3 = RED
emptyAccent.BorderSizePixel = 0
emptyAccent.Parent = emptyHeader

local subTitleSaveHead = makeLabel(
    emptyHeader, "Save / Load Profiles",
    UDim2.new(1, -100, 0, 16),
    UDim2.fromOffset(15, 27),
    10, MUTED, true
)

local emptyClose = makeButton(
    emptyHeader, "×",
    UDim2.fromOffset(29, 28),
    UDim2.new(1, -38, 0, 12),
    true
)
emptyClose.TextSize = 19

local backBtn = makeButton(
    emptyPage,
    "←   Back",
    UDim2.fromOffset(100, 35),
    UDim2.fromOffset(14, 64)
)

local saveNameBox = Instance.new("TextBox")
saveNameBox.Size = UDim2.new(1, -28, 0, 38)
saveNameBox.Position = UDim2.fromOffset(14, 110)
saveNameBox.BackgroundColor3 = PANEL
saveNameBox.TextColor3 = WHITE
saveNameBox.PlaceholderText = "Enter profile name..."
saveNameBox.PlaceholderColor3 = MUTED
saveNameBox.Text = ""
saveNameBox.ClearTextOnFocus = false
saveNameBox.Font = Enum.Font.Gotham
saveNameBox.TextSize = 13
saveNameBox.TextXAlignment = Enum.TextXAlignment.Left
saveNameBox.Parent = emptyPage

corner(saveNameBox, 8)
stroke(saveNameBox, Color3.fromRGB(55, 59, 73), 1)

local saveNamePadding = Instance.new("UIPadding")
saveNamePadding.PaddingLeft = UDim.new(0, 11)
saveNamePadding.PaddingRight = UDim.new(0, 8)
saveNamePadding.Parent = saveNameBox

local saveBtnShort = makeButton(
    emptyPage, "Save",
    UDim2.new(0.32, -6, 0, 36),
    UDim2.fromOffset(14, 158),
    true
)

local useSaveBtn = makeButton(
    emptyPage, "Load",
    UDim2.new(0.32, -6, 0, 36),
    UDim2.new(0.32, 6, 0, 158),
    false
)

local deleteSaveBtn = makeButton(
    emptyPage, "Delete",
    UDim2.new(0.32, -6, 0, 36),
    UDim2.new(0.64, 10, 0, 158),
    true
)

local lblProfilesList = makeLabel(
    emptyPage, "Saved Profiles",
    UDim2.new(1, -28, 0, 20),
    UDim2.fromOffset(14, 204),
    12, RED, true
)

local saveRows = Instance.new("Frame")
saveRows.Position = UDim2.fromOffset(14, 228)
saveRows.Size = UDim2.new(1, -28, 0, 240)
saveRows.BackgroundColor3 = PANEL
saveRows.BorderSizePixel = 0
saveRows.Parent = emptyPage

corner(saveRows, 9)
stroke(saveRows, Color3.fromRGB(49, 52, 66), 1)

local saveRowScroll = Instance.new("ScrollingFrame")
saveRowScroll.Position = UDim2.fromOffset(6, 6)
saveRowScroll.Size = UDim2.new(1, -12, 1, -12)
saveRowScroll.BackgroundTransparency = 1
saveRowScroll.BorderSizePixel = 0
saveRowScroll.ScrollBarThickness = 3
saveRowScroll.ScrollBarImageColor3 = RED
saveRowScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
saveRowScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
saveRowScroll.Parent = saveRows

local saveRowLayout = Instance.new("UIListLayout")
saveRowLayout.Padding = UDim.new(0, 5)
saveRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
saveRowLayout.Parent = saveRowScroll

-- ฟังก์ชันอัปเดตภาษา UI
local function updateLanguage()
    if currentLang == "TH" then
        langBtn.Text = "LANG: TH"
        subTitleMain.Text = "ระบบบันทึกพิกัด"
        lblCreate.Text = "สร้างจุดพิกัด"
        nameBox.PlaceholderText = "พิมพ์ชื่อจุดพิกัด..."
        lblKeybind.Text = "ปุ่มลัดวาป (คีย์ลัด)"
        if not draftKey then
            keyBtn.Text = "＋   เลือกปุ่มคีย์ลัด  ·  (ไม่บังคับ)"
            keyStatus.Text = "ปุ่มปัจจุบัน: ไม่มี"
        end
        clearKeyBtn.Text = "ล้างค่า"
        createBtn.Text = "＋   บันทึกจุดพิกัด"
        lblList.Text = "รายการพิกัด"
        teleportBtn.Text = "วาปไปยังจุดที่เลือก"
        deleteSelectedBtn.Text = "ลบจุดที่เลือก"
        deleteAllBtn.Text = "ลบทั้งหมด"
        saveSettingsBtn.Text = "บันทึกโปรไฟล์"
        toggleBtn.Text = "ปุ่มเปิด-ปิด UI: " .. toggleKey.Name
        subTitleSaveHead.Text = "บันทึก / โหลด โปรไฟล์"
        backBtn.Text = "←   กลับ"
        saveNameBox.PlaceholderText = "พิมพ์ชื่อโปรไฟล์..."
        saveBtnShort.Text = "บันทึก"
        useSaveBtn.Text = "ใช้งาน"
        deleteSaveBtn.Text = "ลบ"
        lblProfilesList.Text = "โปรไฟล์ที่บันทึกไว้"
    else
        langBtn.Text = "LANG: EN"
        subTitleMain.Text = "Waypoint System"
        lblCreate.Text = "Create Waypoint"
        nameBox.PlaceholderText = "Enter waypoint name..."
        lblKeybind.Text = "Teleport Keybind"
        if not draftKey then
            keyBtn.Text = "＋   Select Keybind  ·  (Optional)"
            keyStatus.Text = "Current Key: None"
        end
        clearKeyBtn.Text = "Clear"
        createBtn.Text = "＋   Save Waypoint"
        lblList.Text = "Waypoints List"
        teleportBtn.Text = "Teleport to Selected"
        deleteSelectedBtn.Text = "Delete Selected"
        deleteAllBtn.Text = "Delete All"
        saveSettingsBtn.Text = "Save Profiles"
        toggleBtn.Text = "UI Toggle Key: " .. toggleKey.Name
        subTitleSaveHead.Text = "Save / Load Profiles"
        backBtn.Text = "←   Back"
        saveNameBox.PlaceholderText = "Enter profile name..."
        saveBtnShort.Text = "Save"
        useSaveBtn.Text = "Load"
        deleteSaveBtn.Text = "Delete"
        lblProfilesList.Text = "Saved Profiles"
    end
end

track(langBtn.Activated:Connect(function()
    currentLang = currentLang == "TH" and "EN" or "TH"
    updateLanguage()
end))

-- ==================== [ ระบบตรวจสอบคีย์ผ่าน GitHub ที่ใส่ลิงก์แล้ว ] ====================
track(submitKeyBtn.Activated:Connect(function()
    local inputKey = keyInputBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if inputKey == "" then
        keyStatusLabel.Text = "Please enter your key!"
        return
    end

    keyStatusLabel.Text = "Verifying..."
    keyStatusLabel.TextColor3 = WHITE

    local success, response = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Ajiranokun/Ford-keys/refs/heads/main/keys.json")
    end)

    if not success then
        keyStatusLabel.Text = "Connection failed!"
        keyStatusLabel.TextColor3 = RED
        return
    end

    local ok, allowedKeys = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not ok or type(allowedKeys) ~= "table" then
        keyStatusLabel.Text = "Invalid key data format!"
        keyStatusLabel.TextColor3 = RED
        return
    end

    local myUsername = player.Name

    if allowedKeys[myUsername] and allowedKeys[myUsername] == inputKey then
        keyWindow.Visible = false
        main.Visible = true
    else
        keyStatusLabel.Text = "Invalid key or not bound to this account!"
        keyStatusLabel.TextColor3 = RED
    end
end))

-- TELEPORT
local function teleport(name)
    if not alive or not marks[name] then return end

    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(
            marks[name] + Vector3.new(0, 3, 0)
        )
    end
end

-- REDRAW MARK LIST
local redraw
local redrawSaveFiles

redraw = function()
    for _, child in ipairs(rowScroll:GetChildren()) do
        if child ~= rowLayout then
            child:Destroy()
        end
    end

    local names = {}
    for name in pairs(marks) do
        table.insert(names, name)
    end
    table.sort(names)

    countLabel.Text = tostring(#names) .. (currentLang == "TH" and " จุด" or " Points")

    for i, name in ipairs(names) do
        local key = keybinds[name]
        local keyName = key and key.Name or (currentLang == "TH" and "ไม่มี" or "None")
        local prefix = name == selected and "✓   " or "   "

        local row = makeButton(
            rowScroll,
            prefix .. name .. "     [" .. keyName .. "]",
            UDim2.new(1, -4, 0, 34),
            UDim2.new(),
            name == selected
        )

        row.LayoutOrder = i
        row.TextXAlignment = Enum.TextXAlignment.Left

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.Parent = row

        track(row.Activated:Connect(function()
            if not alive then return end
            selected = name
            redraw()
        end))
    end
end

local function loadSelectedConfig()
    if not selectedSaveConfig then return end
    if savedConfigs[selectedSaveConfig] then
        marks = {}
        keybinds = {}
        
        for mName, pos in pairs(savedConfigs[selectedSaveConfig].marks) do
            marks[mName] = pos
        end
        for mName, keyCode in pairs(savedConfigs[selectedSaveConfig].keybinds) do
            keybinds[mName] = keyCode
        end
        if savedConfigs[selectedSaveConfig].toggleKey then
            toggleKey = savedConfigs[selectedSaveConfig].toggleKey
            toggleBtn.Text = (currentLang == "TH" and "ปุ่มเปิด-ปิด UI: " or "UI Toggle Key: ") .. toggleKey.Name
        end

        selected = nil
        redraw()
        emptyPage.Visible = false
        main.Visible = true
    end
end

redrawSaveFiles = function()
    for _, child in ipairs(saveRowScroll:GetChildren()) do
        if child ~= saveRowLayout then
            child:Destroy()
        end
    end

    local configNames = {}
    for cName in pairs(savedConfigs) do
        table.insert(configNames, cName)
    end
    table.sort(configNames)

    for i, cName in ipairs(configNames) do
        local prefix = cName == selectedSaveConfig and "✓   " or "📁  "
        local row = makeButton(
            saveRowScroll,
            prefix .. cName,
            UDim2.new(1, -4, 0, 34),
            UDim2.new(),
            cName == selectedSaveConfig
        )

        row.LayoutOrder = i
        row.TextXAlignment = Enum.TextXAlignment.Left

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.Parent = row

        track(row.Activated:Connect(function()
            if not alive then return end
            selectedSaveConfig = cName
            redrawSaveFiles()
        end))
    end
end

local function createMark()
    local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")

    if name == "" then
        nameBox.PlaceholderText = currentLang == "TH" and "กรุณาพิมพ์ชื่อก่อน!" or "Please enter a name!"
        return
    end

    local root = getRoot()
    if not root then return end

    if draftKey then
        for existingName, existingKey in pairs(keybinds) do
            if existingKey == draftKey and existingName ~= name then
                keyStatus.Text = currentLang == "TH" and "ปุ่มนี้ถูกใช้งานแล้ว!" or "Key already in use!"
                keyStatus.TextColor3 = RED
                return
            end
        end
    end

    marks[name] = root.Position
    keybinds[name] = draftKey
    selected = name

    nameBox.Text = ""
    draftKey = nil
    keyBtn.Text = currentLang == "TH" and "＋   เลือกปุ่มคีย์ลัด  ·  (ไม่บังคับ)" or "＋   Select Keybind  ·  (Optional)"
    keyStatus.Text = currentLang == "TH" and "ปุ่มปัจจุบัน: ไม่มี" or "Current Key: None"
    keyStatus.TextColor3 = MUTED

    redraw()
end

track(keyBtn.Activated:Connect(function()
    waitingForMarkKey = true
    waitingForToggleKey = false
    keyBtn.Text = currentLang == "TH" and "กดปุ่มคีย์ลัด... (Esc ยกเลิก)" or "Press a key... (Esc to cancel)"
    keyStatus.Text = currentLang == "TH" and "สถานะ: กำลังรอปุ่ม..." or "Status: Waiting for key..."
    keyStatus.TextColor3 = RED
end))

track(clearKeyBtn.Activated:Connect(function()
    draftKey = nil
    waitingForMarkKey = false
    keyBtn.Text = currentLang == "TH" and "＋   เลือกปุ่มคีย์ลัด  ·  (ไม่บังคับ)" or "＋   Select Keybind  ·  (Optional)"
    keyStatus.Text = currentLang == "TH" and "ปุ่มปัจจุบัน: ไม่มี" or "Current Key: None"
    keyStatus.TextColor3 = MUTED
end))

track(createBtn.Activated:Connect(createMark))

track(saveSettingsBtn.Activated:Connect(function()
    main.Visible = false
    emptyPage.Visible = true
    redrawSaveFiles()
end))

track(backBtn.Activated:Connect(function()
    emptyPage.Visible = false
    main.Visible = true
end))

track(saveBtnShort.Activated:Connect(function()
    local cName = saveNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if cName == "" then
        saveNameBox.PlaceholderText = currentLang == "TH" and "กรุณาพิมพ์ชื่อก่อน!" or "Please enter a name!"
        return
    end

    local marksCopy = {}
    for mName, pos in pairs(marks) do
        marksCopy[mName] = pos
    end

    local keybindsCopy = {}
    for mName, keyCode in pairs(keybinds) do
        keybindsCopy[mName] = keyCode
    end

    savedConfigs[cName] = {
        marks = marksCopy,
        keybinds = keybindsCopy,
        toggleKey = toggleKey
    }

    saveToFile()
    saveNameBox.Text = ""
    selectedSaveConfig = cName
    redrawSaveFiles()
end))

track(useSaveBtn.Activated:Connect(function()
    loadSelectedConfig()
end))

track(deleteSaveBtn.Activated:Connect(function()
    if not selectedSaveConfig then return end
    
    if savedConfigs[selectedSaveConfig] then
        savedConfigs[selectedSaveConfig] = nil
        saveToFile()
        selectedSaveConfig = nil
        redrawSaveFiles()
    end
end))

track(teleportBtn.Activated:Connect(function()
    if selected then
        teleport(selected)
    end
end))

track(deleteSelectedBtn.Activated:Connect(function()
    if not selected then return end

    marks[selected] = nil
    keybinds[selected] = nil
    selected = nil
    redraw()
end))

track(deleteAllBtn.Activated:Connect(function()
    table.clear(marks)
    table.clear(keybinds)
    selected = nil
    draftKey = nil

    keyStatus.Text = currentLang == "TH" and "ปุ่มปัจจุบัน: ไม่มี" or "Current Key: None"
    keyStatus.TextColor3 = MUTED
    keyBtn.Text = currentLang == "TH" and "＋   เลือกปุ่มคีย์ลัด  ·  (ไม่บังคับ)" or "＋   Select Keybind  ·  (Optional)"

    redraw()
end))

track(toggleBtn.Activated:Connect(function()
    waitingForToggleKey = true
    waitingForMarkKey = false
    toggleBtn.Text = currentLang == "TH" and "กดปุ่มเปิด-ปิด UI... (Esc ยกเลิก)" or "Press toggle key... (Esc to cancel)"
end))

track(UIS.InputBegan:Connect(function(input, processed)
    if not alive then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if waitingForToggleKey then
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingForToggleKey = false
            toggleBtn.Text = (currentLang == "TH" and "ปุ่มเปิด-ปิด UI: " or "UI Toggle Key: ") .. toggleKey.Name
            return
        end

        if input.KeyCode ~= Enum.KeyCode.Unknown then
            local conflict = input.KeyCode == draftKey

            for _, key in pairs(keybinds) do
                if key == input.KeyCode then
                    conflict = true
                    break
                end
            end

            if not conflict then
                toggleKey = input.KeyCode
            end
        end

        waitingForToggleKey = false
        toggleBtn.Text = (currentLang == "TH" and "ปุ่มเปิด-ปิด UI: " or "UI Toggle Key: ") .. toggleKey.Name
        return
    end

    if input.KeyCode == toggleKey and main.Visible then
        main.Visible = false
        return
    elseif input.KeyCode == toggleKey and not main.Visible and keyWindow.Visible == false then
        main.Visible = true
        return
    end

    if waitingForMarkKey then
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingForMarkKey = false
            keyBtn.Text = currentLang == "TH" and "＋   เลือกปุ่มคีย์ลัด  ·  (ไม่บังคับ)" or "＋   Select Keybind  ·  (Optional)"
            keyStatus.Text = draftKey
                and ((currentLang == "TH" and "ปุ่มปัจจุบัน: " or "Current Key: ") .. draftKey.Name)
                or (currentLang == "TH" and "ปุ่มปัจจุบัน: ไม่มี" or "Current Key: None")
            keyStatus.TextColor3 = draftKey and GREEN or MUTED
            return
        end

        if input.KeyCode ~= Enum.KeyCode.Unknown then
            local conflict = input.KeyCode == toggleKey

            for _, key in pairs(keybinds) do
                if key == input.KeyCode then
                    conflict = true
                    break
                end
            end

            if conflict then
                keyStatus.Text = currentLang == "TH" and "ปุ่มนี้ถูกใช้งานแล้ว!" or "Key already in use!"
                keyStatus.TextColor3 = RED
            else
                draftKey = input.KeyCode
                keyStatus.Text = (currentLang == "TH" and "ปุ่มปัจจุบัน: " or "Current Key: ") .. draftKey.Name
                keyStatus.TextColor3 = GREEN
                keyBtn.Text = "✓   " .. draftKey.Name
            end
        end

        waitingForMarkKey = false
        return
    end

    if processed then return end

    for name, key in pairs(keybinds) do
        if key and input.KeyCode == key then
            teleport(name)
            return
        end
    end
end))

-- DRAG MAIN WINDOW
local dragging = false
local dragStart
local startPosition

track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end))

track(UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end))

-- MINIMIZE
track(minimizeBtn.Activated:Connect(function()
    minimized = not minimized
    content.Visible = not minimized

    main.Size = minimized
        and UDim2.fromOffset(240, 52)
        or UDim2.fromOffset(365, 490)

    minimizeBtn.Text = minimized and "+" or "—"
end))

-- CLOSE EVERYTHING
track(closeBtn.Activated:Connect(cleanup))

updateLanguage()
redraw()
