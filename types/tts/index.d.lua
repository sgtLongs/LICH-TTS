---@meta

---@alias PlayerColor
---| "White"
---| "Brown"
---| "Red"
---| "Orange"
---| "Yellow"
---| "Green"
---| "Teal"
---| "Blue"
---| "Purple"
---| "Pink"
---| "Grey"
---| "Black"

---@class TtsVector
---@field x number
---@field y number
---@field z number

---@class TtsBounds
---@field center TtsVector
---@field size TtsVector
---@field offset TtsVector

---@class TtsButton
---@field click_function string
---@field function_owner? TtsObject
---@field label? string
---@field position? TtsVector|number[]
---@field rotation? TtsVector|number[]
---@field scale? TtsVector|number[]
---@field width? integer
---@field height? integer
---@field font_size? integer

---@class TtsObject
---@field guid string
---@field tag string
---@field script_state string
---@field interactable boolean
---@field loading_custom boolean
---@field spawning boolean
---@field held_by_color PlayerColor|nil
---@field use_hands boolean
---@field remainder TtsObject|nil
local TtsObject = {}

---@return string
function TtsObject.getGUID() end

---@return TtsVector
function TtsObject.getPosition() end

---@return TtsVector
function TtsObject.getRotation() end

---@return TtsVector
function TtsObject.getScale() end

---@return TtsBounds
function TtsObject.getBounds() end

---@return TtsObject[]
function TtsObject.getZones() end

---@return table[]
function TtsObject.getObjects() end

---@return integer
function TtsObject.getQuantity() end

---@return boolean
function TtsObject.getLock() end

---@return boolean
function TtsObject.isDestroyed() end

---@return boolean
function TtsObject.isSmoothMoving() end

---@return TtsButton[]
function TtsObject.getButtons() end

---@param position TtsVector|number[]
function TtsObject.setPosition(position) end

---@param position TtsVector|number[]
---@param collide? boolean
---@param fast? boolean
function TtsObject.setPositionSmooth(position, collide, fast) end

---@param rotation TtsVector|number[]
function TtsObject.setRotation(rotation) end

---@param rotation TtsVector|number[]
---@param collide? boolean
---@param fast? boolean
function TtsObject.setRotationSmooth(rotation, collide, fast) end

---@param scale TtsVector|number[]
function TtsObject.setScale(scale) end

---@param velocity TtsVector|number[]
function TtsObject.setVelocity(velocity) end

---@param velocity TtsVector|number[]
function TtsObject.setAngularVelocity(velocity) end

---@param locked boolean
function TtsObject.setLock(locked) end

---@param tint string|number[]|table
function TtsObject.setColorTint(tint) end

---@param state integer
---@return TtsObject
function TtsObject.setState(state) end

---@return integer
function TtsObject.getStateId() end

---@param source string
function TtsObject.setLuaScript(source) end

---@return TtsObject
function TtsObject.reload() end

---@param lines table[]
function TtsObject.setVectorLines(lines) end

---@param button TtsButton
function TtsObject.createButton(button) end

---@param button table
function TtsObject.editButton(button) end

---@param index integer
function TtsObject.removeButton(index) end

function TtsObject.clearButtons() end

---@param name string
---@param parameters? table
---@return any
function TtsObject.call(name, parameters) end

---@param object TtsObject
---@return TtsObject
function TtsObject.putObject(object) end

---@param parameters table
---@return TtsObject
function TtsObject.takeObject(parameters) end

---@param localPosition TtsVector|number[]
---@return TtsVector
function TtsObject.positionToWorld(localPosition) end

---@param worldPosition TtsVector|number[]
---@return TtsVector
function TtsObject.positionToLocal(worldPosition) end

---@param color PlayerColor
---@param handIndex? integer
function TtsObject.deal(color, handIndex) end

---@class TtsPlayer
---@field color PlayerColor
---@field steam_name string
---@field admin boolean
---@field seated boolean
local TtsPlayer = {}

---@return TtsObject[]
function TtsPlayer.getHandObjects() end

---@return TtsObject|nil
function TtsPlayer.getHoverObject() end

---@return TtsVector
function TtsPlayer.getPointerPosition() end

---@class TtsPlayerManager
---@field Action table<string, integer>
---@field getPlayers fun(): TtsPlayer[]
---@field [PlayerColor] TtsPlayer
Player = {}

---@class TtsUi
UI = {}

---@param id string
---@param attribute string
---@param value string
function UI.setAttribute(id, attribute, value) end

---@param id string
---@param attribute string
---@return string
function UI.getAttribute(id, attribute) end

---@class TtsWait
Wait = {}

---@param callback fun()
---@param frames integer
---@return integer
function Wait.frames(callback, frames) end

---@param callback fun()
---@param seconds number
---@param repetitions? integer
---@return integer
function Wait.time(callback, seconds, repetitions) end

---@param callback fun()
---@param condition fun(): boolean
---@param timeout? number
---@param timeoutCallback? fun()
---@return integer
function Wait.condition(callback, condition, timeout, timeoutCallback) end

---@param identifier integer
function Wait.stop(identifier) end

---@class TtsJson
JSON = {}

---@param value any
---@return string
function JSON.encode(value) end

---@param value any
---@return string
function JSON.encode_pretty(value) end

---@param value string
---@return any
function JSON.decode(value) end

---@class TtsWebResponse
---@field is_error boolean
---@field error string
---@field text string
---@field response_code integer

---@class TtsWebRequest
WebRequest = {}

---@param url string
---@param callback fun(response: TtsWebResponse)
function WebRequest.get(url, callback) end

---@type TtsObject
Global = nil

---@type TtsObject
self = nil

---@param guid string
---@return TtsObject|nil
function getObjectFromGUID(guid) end

---@return TtsObject[]
function getAllObjects() end

---@param tag string
---@return TtsObject[]
function getObjectsWithTag(tag) end

---@param parameters table
---@return TtsObject
function spawnObjectData(parameters) end

---@param parameters table
---@return TtsObject
function spawnObjectJSON(parameters) end

---@param object TtsObject
function destroyObject(object) end

---@param message string
---@param color PlayerColor
---@param tint? string|number[]|table
function broadcastToColor(message, color, tint) end

---@param message string
---@param tint? string|number[]|table
function broadcastToAll(message, tint) end

---@param message string
---@param tint? string|number[]|table
function printToAll(message, tint) end

---@param callback fun()
---@param includeCurrentState? boolean
function storeRewindState(callback, includeCurrentState) end

---@type string
TEST_REPOSITORY_ROOT = nil

---@type fun(): number
TEST_CLOCK = nil

---@class TestRunnerOptions
---@field filters string[]
---@field files string[]
---@field tags string[]
---@field excludeTags string[]
---@field failedTests string[]
---@field failFast boolean
---@field timing boolean
---@field slowest integer
---@field failureFile string

---@type TestRunnerOptions
TEST_RUNNER_OPTIONS = nil
