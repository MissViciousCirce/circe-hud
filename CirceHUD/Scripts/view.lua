local E = require("engine")
local View = {}
View.__index = View

local function vector(x, y) return { X = x, Y = y } end
local function tint(r, g, b) return { SpecifiedColor = { R = r, G = g, B = b, A = 1 }, ColorUseRule = 0 } end
local function widget(kind, outer)
    local object = StaticConstructObject(E.lookup("/Script/UMG." .. kind), outer)
    assert(E.valid(object), "Cannot create " .. kind)
    object:SetVisibility(3) -- HitTestInvisible: the HUD must not block clicks.
    return object
end
local function place(parent, child, x, y, w, h, order)
    local slot = parent:AddChildToCanvas(child)
    assert(E.valid(slot), "HUD canvas rejected child")
    slot:SetAnchors({ Minimum = vector(0, 0), Maximum = vector(0, 0) })
    slot:SetAlignment(vector(0, 0))
    slot:SetPosition(vector(x, y))
    slot:SetSize(vector(w, h))
    slot:SetZOrder(order or 0)
    return slot
end
local function text(parent, outer, value, size, x, y, w, h)
    local node = widget("TextBlock", outer)
    node:SetText(FText(value))
    node:SetJustification(1)
    local font = node.Font
    font.Size = size
    node:SetFont(font)
    node:SetColorAndOpacity(tint(0.80, 0.97, 1.0))
    node:SetShadowOffset(vector(1, 1))
    node:SetShadowColorAndOpacity({ R = 0, G = 0, B = 0, A = 0.9 })
    return node, place(parent, node, x, y, w, h, 10)
end

function View.new(host, outer, world, target, config, directory)
    local self = setmetatable({}, View)
    local ok, err = pcall(function()
        self.host = host
        self.root = widget("CanvasPanel", outer)
        self.slot = place(host, self.root, config.Left, config.Top, config.Diameter, config.Diameter + 64, 9000)
        self.map = widget("Image", outer)
        self.map:SetBrushResourceObject(target)
        self.map:SetColorAndOpacity({ R = 1, G = 1, B = 1, A = 1 })
        self.mapSlot = place(self.root, self.map, 0, 0, config.Diameter, config.Diameter, 0)
        self.marker = widget("Image", outer)
        local renderer = E.lookup("/Script/Engine.Default__KismetRenderingLibrary")
        local arrow = renderer:ImportFileAsTexture2D(world, directory .. "../Assets/pointer.png.lua")
        assert(E.valid(arrow), "Missing generated pointer artwork")
        self.marker:SetBrushFromTexture(arrow, false)
        self.marker:SetRenderTransformPivot(vector(0.5, 0.5))
        self.markerSlot = place(self.root, self.marker, 0, 0, 24, 24, 5)
        self.region, self.regionSlot = text(self.root, outer, "Unknown region", 16, 0, 0, 1, 28)
        self.clock, self.clockSlot = text(self.root, outer, "--:--", 15, 0, 0, 1, 26)
        self.north, self.northSlot = text(self.root, outer, "N", 12, 0, 0, 24, 22)
        self.north:SetVisibility(config.ShowNorth and 3 or 1)
        self:layout(config, false)
    end)
    if not ok then self:dispose(); error(err) end
    return self
end

function View:layout(config, large)
    local d = large and config.LargeDiameter or config.Diameter
    local anchor = large and 0.5 or 0
    self.slot:SetAnchors({ Minimum = vector(anchor, anchor), Maximum = vector(anchor, anchor) })
    self.slot:SetAlignment(vector(anchor, anchor))
    self.slot:SetPosition(large and vector(0, 0) or vector(config.Left, config.Top))
    self.slot:SetSize(vector(d, d + 64))
    self.mapSlot:SetSize(vector(d, d))
    -- Slate's rounded-box shader masks the live texture and antialiases its
    -- outline. Four half-width radii produce a circle without strip clipping.
    local brush = self.map.Brush
    brush.DrawAs = 4 -- ESlateBrushDrawType::RoundedBox
    brush.ImageType = 1 -- FullColor
    brush.TintColor = tint(1, 1, 1)
    brush.ImageSize = vector(d, d)
    local outline = brush.OutlineSettings
    outline.RoundingType = 0 -- FixedRadius
    outline.CornerRadii = { X = d / 2, Y = d / 2, Z = d / 2, W = d / 2 }
    outline.Color = tint(0.08, 0.87, 0.94)
    outline.Width = 2
    outline.bUseBrushTransparency = true
    brush.OutlineSettings = outline
    self.map:SetBrush(brush)
    self.markerSlot:SetPosition(vector(d / 2 - 12, d / 2 - 12))
    self.regionSlot:SetPosition(vector(-24, d + 7)); self.regionSlot:SetSize(vector(d + 48, 28))
    self.clockSlot:SetPosition(vector(-24, d + 34)); self.clockSlot:SetSize(vector(d + 48, 26))
    self.northSlot:SetPosition(vector(d / 2 - 12, 5))
end

function View:update(region, clock)
    if self.lastRegion ~= region then self.region:SetText(FText(region)); self.lastRegion = region end
    if self.lastClock ~= clock then self.clock:SetText(FText(clock)); self.lastClock = clock end
end

function View:heading(bearing)
    self.marker:SetRenderTransformAngle(bearing)
end

function View:visible(visible) self.root:SetVisibility(visible and 3 or 1) end
function View:valid() return E.valid(self.root) and E.valid(self.host) and E.valid(self.map) end
function View:dispose()
    if E.valid(self.root) then pcall(function() self.root:RemoveFromParent() end) end
    self.root, self.host, self.map = nil, nil, nil
end

return View
