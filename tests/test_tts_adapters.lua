local Test = require("tests/support/Test")
local ObjectAdapter = require("src/tts/ObjectAdapter")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local UiAdapter = require("src/tts/UiAdapter")
local UiPatch = require("src/ui/UiPatch")
local WebAdapter = require("src/tts/WebAdapter")
local FakeTts = require("tests/support/FakeTts")

Test.case("runtime resolves TTS globals at call time", function()
    local runtime = Runtime.new()
    local object = {}
    local messages = {}
    local vectorLines = nil
    local globalObject = {
        setVectorLines = function(lines)
            vectorLines = lines
        end
    }

    Test.withGlobals({
        Player = {
            Red = {admin = true},
            Action = {Select = "select"},
            getPlayers = function()
                return {{color = "Red"}}
            end
        },
        getObjectFromGUID = function(guid)
            return guid == "known" and object or nil
        end,
        getAllObjects = function()
            return {object}
        end,
        broadcastToColor = function(message, color)
            messages[#messages + 1] = {message, color}
        end,
        Global = globalObject
    }, function()
        Test.truthy(runtime.getPlayer("Red").admin)
        Test.equal(1, #runtime.getPlayers())
        Test.equal("select", runtime.getSelectAction())
        Test.equal(object, runtime.getObject("known"))
        Test.equal(object, runtime.getObjectFromGUID("known"))
        Test.equal(object, runtime.getAllObjects()[1])
        Test.equal(globalObject, runtime.getGlobalOwner())
        runtime.setVectorLines({"line"})
        Test.equal("line", vectorLines[1])
        runtime.broadcastToColor("hello", "Red")
        Test.equal("hello", messages[1][1])
        Test.equal("Red", messages[1][2])
    end)
end)

Test.case("runtime dependencies override individual TTS ports", function()
    local destroyed = nil
    local runtime = Runtime.new({
        getObject = function(guid)
            return {guid = guid}
        end,
        destroyObject = function(object)
            destroyed = object
        end
    })
    local object = runtime.getObject("fixture")

    runtime.destroyObject(object)
    Test.equal("fixture", object.guid)
    Test.equal(object, destroyed)
end)

Test.case("scheduler delegates every timing primitive", function()
    local calls = {}
    local wait = {
        frames = function(callback, count)
            calls.frames = count
            callback()
            return "frames-id"
        end,
        time = function(callback, delay, repetitions)
            calls.time = {delay, repetitions}
            callback()
            return "time-id"
        end,
        condition = function(callback, predicate, timeout)
            calls.condition = timeout

            if predicate() then
                callback()
            end
        end,
        stop = function(identifier)
            calls.stopped = identifier
        end
    }
    local scheduler = Scheduler.new(wait)
    local callbackCount = 0

    Test.truthy(scheduler.hasFrames())
    Test.truthy(scheduler.hasTime())
    Test.truthy(scheduler.hasCondition())

    Test.equal("frames-id", scheduler.frames(function()
        callbackCount = callbackCount + 1
    end, 3))
    Test.equal("time-id", scheduler.time(function()
        callbackCount = callbackCount + 1
    end, 0.5, 4))
    scheduler.condition(function()
        callbackCount = callbackCount + 1
    end, function() return true end, 9)
    scheduler.stop("time-id")

    Test.equal(3, callbackCount)
    Test.equal(3, calls.frames)
    Test.deepEqual({0.5, 4}, calls.time)
    Test.equal(9, calls.condition)
    Test.equal("time-id", calls.stopped)
end)

Test.case("scheduler has deterministic no-TTS fallbacks", function()
    Test.withGlobals({Wait = Test.NIL}, function()
        local scheduler = Scheduler.new()
        local events = {}

        Test.falsy(scheduler.hasFrames())
        Test.falsy(scheduler.hasTime())
        Test.falsy(scheduler.hasCondition())

        scheduler.frames(function() events[#events + 1] = "frames" end, 2)
        scheduler.time(function() events[#events + 1] = "time" end, 1)
        scheduler.condition(
            function() events[#events + 1] = "ready" end,
            function() return false end,
            1,
            function() events[#events + 1] = "timeout" end
        )

        Test.deepEqual({"frames", "time", "timeout"}, events)
    end)
end)

Test.case("UI patches are applied through one adapter", function()
    local attributes = {}
    local adapter = UiAdapter.new({
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    })
    local patches = {}

    UiPatch.append(patches, "root", "active", "true")
    UiPatch.extend(patches, {
        UiPatch.set("label", "text", "Ready")
    })

    Test.equal(2, adapter.apply(patches))
    Test.equal("true", attributes["root.active"])
    Test.equal("Ready", attributes["label.text"])
end)

Test.case("object adapter tolerates missing and throwing methods", function()
    local removed = nil
    local object = {}

    object.getButtons = function()
            return {{index = 7}}
    end
    object.removeButton = function(index)
        removed = index
    end
    object.setPositionSmooth = function()
        error("smooth unavailable")
    end
    object.setPosition = function(position)
        object.position = position
    end

    Test.equal(7, ObjectAdapter.getButtons(object)[1].index)
    Test.truthy(ObjectAdapter.removeButton(object, 7))
    Test.equal(7, removed)
    Test.truthy(ObjectAdapter.moveSmooth(object, {x = 1, y = 2, z = 3}))
    Test.equal(1, object.position.x)
    Test.falsy(ObjectAdapter.clearButtons({}))
end)

Test.case("web adapter reports unavailable and available transports", function()
    local unavailableResponse = nil

    Test.withGlobals({WebRequest = Test.NIL}, function()
        Test.falsy(WebAdapter.new().get("url", function(response)
            unavailableResponse = response
        end))
    end)

    Test.truthy(unavailableResponse.is_error)

    local requestedUrl = nil
    local adapter = WebAdapter.new({
        get = function(url, callback)
            requestedUrl = url
            callback({is_error = false, text = "ok"})
        end
    })
    local responseText = nil

    Test.truthy(adapter.get("https://example.test", function(response)
        responseText = response.text
    end))
    Test.equal("https://example.test", requestedUrl)
    Test.equal("ok", responseText)
end)

Test.case("test helpers restore globals even when callbacks fail", function()
    local previousMarker = _G.__fixtureMarker

    Test.raises(function()
        Test.withGlobals({__fixtureMarker = "temporary"}, function()
            Test.equal("temporary", _G.__fixtureMarker)
            error("expected fixture failure")
        end)
    end, "expected fixture failure")

    Test.equal(previousMarker, _G.__fixtureMarker)
end)

Test.case("test runner permits temporary globals inside a case", function()
    _G.__lichTestLeakMarker = "temporary"
    package.loaded["tests/temporary-leak-marker"] = {}
    Test.equal("temporary", _G.__lichTestLeakMarker)
end)

Test.case("test runner restores globals and loaded modules per case", function()
    Test.nilValue(_G.__lichTestLeakMarker)
    Test.nilValue(package.loaded["tests/temporary-leak-marker"])
end)

Test.case("fake TTS advances frames and indexes players and objects", function()
    local fixture = FakeTts.new()
    local callbackCount = 0
    local object = {getGUID = function() return "object-guid" end}

    fixture.addPlayer("Red", {admin = true})
    fixture.addObject(object, {"placed"})
    fixture.wait.frames(function()
        callbackCount = callbackCount + 1
    end, 2)

    Test.withGlobals(fixture.globals(), function()
        Test.truthy(Player.Red.admin)
        Test.equal(object, getObjectFromGUID("object-guid"))
        Test.equal(object, getObjectsWithTag("placed")[1])
        fixture.wait.advanceFrames(1)
        Test.equal(0, callbackCount)
        fixture.wait.advanceFrames(1)
        Test.equal(1, callbackCount)
    end)
end)
