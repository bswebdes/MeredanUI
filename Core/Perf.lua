-- Performance measurement (developer tool, never listed in /mui help):
--   /mui perf         start measuring; again: print the results (chat + DevLog) and stop
--   /mui perf start / report   the same, explicitly
--
-- Sources: Blizzard's AddOn profiler (whole addon, since startup: only the tick counters are
-- shown as deltas), mUI's event dispatcher (time per event, Core.lua) and probes around hot
-- functions (ns.PerfProbe). Nothing is timed while no measurement runs: the dispatcher is
-- swapped only during a run and probes cost one flag check.
local ADDON_NAME, ns = ...
local L = ns.L

local active = false
local startTime, startGarbage, startOver5, startOver10
local events, probes = {}, {}

local function Record(store, name, ms)
    local entry = store[name]
    if not entry then
        entry = { count = 0, total = 0, peak = 0 }
        store[name] = entry
    end
    entry.count = entry.count + 1
    entry.total = entry.total + ms
    if ms > entry.peak then entry.peak = ms end
end

local function EventSink(event, ms) Record(events, event, ms) end

local function Finish(name, start, ...)
    Record(probes, name, debugprofilestop() - start)
    return ...
end

-- Wraps a hot function: timed only while a measurement runs
function ns.PerfProbe(name, fn)
    return function(...)
        if not active then return fn(...) end
        return Finish(name, debugprofilestop(), fn(...))
    end
end

local Profiler = C_AddOnProfiler
local Metric = Enum.AddOnProfilerMetric
local function AddonMetric(metric)
    if not (Profiler and Profiler.GetAddOnMetric and Metric) then return nil end
    local ok, value = pcall(Profiler.GetAddOnMetric, ADDON_NAME, metric)
    return ok and value or nil
end

local function Start()
    wipe(events)
    wipe(probes)
    active = true
    startTime = GetTime()
    collectgarbage("collect")
    startGarbage = collectgarbage("count")
    startOver5 = Metric and AddonMetric(Metric.CountTimeOver5Ms) or 0
    startOver10 = Metric and AddonMetric(Metric.CountTimeOver10Ms) or 0
    ns.SetEventSink(EventSink)
    ns.Print(L["Performance measurement started. Play normally, then /mui perf again to stop and show the results."])
end

local function Top(store, count)
    local list = {}
    for name, entry in pairs(store) do list[#list + 1] = { name = name, entry = entry } end
    table.sort(list, function(a, b) return a.entry.total > b.entry.total end)
    local result = {}
    for i = 1, math.min(count, #list) do result[i] = list[i] end
    return result
end

local function Report()
    if not active then return ns.Print(L["No measurement running. Start with /mui perf start."]) end
    active = false
    ns.SetEventSink(nil)
    local seconds = math.max(GetTime() - startTime, 0.001)
    local P = ns.Print
    P(L["Measurement: %d s"], seconds)

    -- Blizzard's profiler (milliseconds per tick)
    if Metric then
        P("  %s: %.3f ms  ·  %s: %.3f ms  ·  %s: %.3f ms  ·  %s: %.2f ms",
            L["Average (60 ticks)"], AddonMetric(Metric.RecentAverageTime) or 0,
            L["Session"], AddonMetric(Metric.SessionAverageTime) or 0,
            L["Boss fight"], AddonMetric(Metric.EncounterAverageTime) or 0,
            L["Peak"], AddonMetric(Metric.PeakTime) or 0)
        P("  " .. L["Ticks over 5 ms: %d, over 10 ms: %d (during the measurement)"],
            (AddonMetric(Metric.CountTimeOver5Ms) or 0) - startOver5, (AddonMetric(Metric.CountTimeOver10Ms) or 0) - startOver10)
        if Profiler.GetTopKAddOnsForMetric then
            local ok, top = pcall(Profiler.GetTopKAddOnsForMetric, Metric.RecentAverageTime, 5)
            if ok and type(top) == "table" then
                local parts = {}
                for _, item in ipairs(top) do
                    parts[#parts + 1] = ("%s %.3f"):format(item.addOnName or "?", item.metricValue or 0)
                end
                P("  " .. L["Top addons (ms): %s"], table.concat(parts, ", "))
            end
        end
    end

    -- Events (mUI dispatcher)
    P(L["Events (total ms, calls, peak ms):"])
    for _, item in ipairs(Top(events, 10)) do
        local e = item.entry
        P("  %s  %.1f  ·  %dx  ·  %.2f", item.name, e.total, e.count, e.peak)
    end

    -- Probes
    if next(probes) then
        P(L["Functions (total ms, calls, peak ms):"])
        for _, item in ipairs(Top(probes, 12)) do
            local e = item.entry
            P("  %s  %.1f  ·  %dx  ·  %.2f", item.name, e.total, e.count, e.peak)
        end
    end

    -- Memory
    UpdateAddOnMemoryUsage()
    local memory = GetAddOnMemoryUsage(ADDON_NAME) or 0
    local garbage = (collectgarbage("count") - startGarbage) / (seconds / 60)
    P(L["Memory: %.1f MB  ·  garbage (all addons): %.0f KB per minute"], memory / 1024, garbage)
end

-- /mui perf toggles: start, then stop + results; "start" / "report" (or "stop") still work
ns.AddCommand("perf", nil, function(arg)
    arg = (arg or ""):lower()
    if arg == "start" or (arg == "" and not active) then return Start() end
    if arg == "report" or arg == "stop" or arg == "" then
        if not active then return ns.Print(L["No measurement running. Start one with /mui perf."]) end
        return Report()
    end
    ns.Print(L["/mui perf: start a measurement, /mui perf again: stop and show the results."])
end)
