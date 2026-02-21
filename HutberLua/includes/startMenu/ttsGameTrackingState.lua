trackedGameId = nil
trackedSnapshotTimerId = nil
endGameSubmitted = false
trackedMainRedSteamId = nil
trackedMainBlueSteamId = nil
endApprovalPending = false
endApprovalRequestedBy = nil
resultConfirmationPending = false
resultConfirmedRed = false
resultConfirmedBlue = false
lastEndedTrackedGameId = nil
trackedActionArmRed = false
trackedActionArmBlue = false
trackedAutoEndWatchTimerId = nil
trackedAutoEndTimerId = nil
trackedAutoEndPending = false
trackedRoundValidationCache = {}

trackedActionStartPosRed = {-34, 5, -8.2}
trackedActionStartPosBlue = {34, 5, -8.2}
trackedActionRoundFivePosRed = {-13, 5, 3.8}
trackedActionRoundFivePosBlue = {13, 5, 3.8}

endTrackedGameBtn = {
    index = 1, label = "Get Game Stats and Finish Game", tooltip = "Send final game result to API", click_function = "endTrackedGame", function_owner = self,
    position = {0, 5, 3.8}, rotation = {0, 0, 0}, height = 700, width = 5600,
    font_size = 280, color = {0.1, 0.1, 0.1}, font_color = {1, 1, 1}
}

confirmTrackedResultRedBtn = {
    index = 1, label = "Finish Game", tooltip = "Round 5 only. Click twice to confirm.", click_function = "confirmTrackedResultRed", function_owner = self,
    position = {-25, 5, 1.6}, rotation = {0, 0, 0}, height = 650, width = 3200,
    font_size = 300, color = {0.55, 0.05, 0.05}, font_color = {1, 1, 1}, visibility = "Red"
}

confirmTrackedResultBlueBtn = {
    index = 1, label = "Finish Game", tooltip = "Round 5 only. Click twice to confirm.", click_function = "confirmTrackedResultBlue", function_owner = self,
    position = {25, 5, 1.6}, rotation = {0, 0, 0}, height = 650, width = 3200,
    font_size = 300, color = {0.05, 0.15, 0.55}, font_color = {1, 1, 1}, visibility = "Blue"
}
