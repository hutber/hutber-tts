ttsGameApiBaseUrl = "https://apistats.hutber.com/api/ttsGame"
ttsSnapshotIntervalSeconds = 300
ttsAutoEndDelaySeconds = 120
ttsAutoEndPollSeconds = 5
ttsDebugEnabled = false

function ttsDebugLog(message)
    if ttsDebugEnabled then
        print(message)
    end
end

function ttsGameLog(message, color)
    printToAll(message, color or "White")
end
