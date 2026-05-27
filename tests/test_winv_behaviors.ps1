# BDD Acceptance Tests for Win+V-style UI changes
# Each test verifies one observable behavior by inspecting source code constants,
# theme XML values, or runtime window measurements.
#
# Usage: pwsh tests/test_winv_behaviors.ps1
# Exit code: 0 = all pass, 1 = failures

$script:failures = 0
$script:passes = 0

function Assert-Equal($actual, $expected, $message) {
    if ($actual -eq $expected) {
        Write-Host "  PASS: $message" -ForegroundColor Green
        $script:passes++
    } else {
        Write-Host "  FAIL: $message (expected=$expected, actual=$actual)" -ForegroundColor Red
        $script:failures++
    }
}

function Assert-True($condition, $message) {
    if ($condition) {
        Write-Host "  PASS: $message" -ForegroundColor Green
        $script:passes++
    } else {
        Write-Host "  FAIL: $message" -ForegroundColor Red
        $script:failures++
    }
}

function Assert-Match($text, $pattern, $message) {
    if ($text -match $pattern) {
        Write-Host "  PASS: $message" -ForegroundColor Green
        $script:passes++
    } else {
        Write-Host "  FAIL: $message (pattern '$pattern' not found)" -ForegroundColor Red
        $script:failures++
    }
}

# ============================================================
# Behavior 1: Default window is portrait matching Win+V
# Given  Ditto with fresh config (no saved preferences)
# When   the default window size is queried
# Then   width=380, height=500 (portrait orientation)
# ============================================================
Write-Host "`nBehavior 1: Default window is portrait matching Win+V" -ForegroundColor Cyan

$optionsSrc = Get-Content "src/Options.cpp" -Raw

$cxMatch = [regex]::Match($optionsSrc, 'GetResolutionProfileLong\("QuickPasteCX",\s*(\d+)\)')
$cyMatch = [regex]::Match($optionsSrc, 'GetResolutionProfileLong\("QuickPasteCY",\s*(\d+)\)')

$defaultWidth = if ($cxMatch.Success) { [int]$cxMatch.Groups[1].Value } else { -1 }
$defaultHeight = if ($cyMatch.Success) { [int]$cyMatch.Groups[1].Value } else { -1 }

Assert-Equal $defaultWidth 380 "Default width is 380 (narrower than Win+V's ~480px at 125%)"
Assert-Equal $defaultHeight 500 "Default height is 500 (tall portrait orientation)"
Assert-True ($defaultHeight -gt $defaultWidth) "Window is portrait (height > width)"

# ============================================================
# Behavior 2: Items show more lines of text by default
# Given  Ditto with default settings
# When   the lines-per-row setting is queried
# Then   it returns 4 (showing more text per item like Win+V)
# ============================================================
Write-Host "`nBehavior 2: Items show 4 lines of text by default" -ForegroundColor Cyan

$lprMatch = [regex]::Match($optionsSrc, 'GetProfileLong\("LinesPerRow",\s*(\d+)\)')
$defaultLinesPerRow = if ($lprMatch.Success) { [int]$lprMatch.Groups[1].Value } else { -1 }

Assert-Equal $defaultLinesPerRow 4 "Default lines per row is 4"

# ============================================================
# Behavior 3: Items have generous Win+V-style padding
# Given  Ditto source code
# When   the row border constants are checked
# Then   ROW_TOP_BORDER=20, ROW_BOTTOM_BORDER=20, ROW_LEFT_BORDER=10
# ============================================================
Write-Host "`nBehavior 3: Items have generous Win+V-style padding" -ForegroundColor Cyan

$qlistSrc = Get-Content "src/QListCtrl.cpp" -Raw

$topMatch = [regex]::Match($qlistSrc, '#define\s+ROW_TOP_BORDER\s+(\d+)')
$bottomMatch = [regex]::Match($qlistSrc, '#define\s+ROW_BOTTOM_BORDER\s+(\d+)')
$leftMatch = [regex]::Match($qlistSrc, '#define\s+ROW_LEFT_BORDER\s+(\d+)')

$topBorder = if ($topMatch.Success) { [int]$topMatch.Groups[1].Value } else { -1 }
$bottomBorder = if ($bottomMatch.Success) { [int]$bottomMatch.Groups[1].Value } else { -1 }
$leftBorder = if ($leftMatch.Success) { [int]$leftMatch.Groups[1].Value } else { -1 }

Assert-Equal $topBorder 20 "ROW_TOP_BORDER is 20"
Assert-Equal $bottomBorder 20 "ROW_BOTTOM_BORDER is 20"
Assert-Equal $leftBorder 10 "ROW_LEFT_BORDER is 10"

# Item height includes top border in MeasureItem
Assert-Match $qlistSrc 'Scale\(ROW_TOP_BORDER\).*tmHeight.*Scale\(ROW_BOTTOM_BORDER\)' "MeasureItem includes ROW_TOP_BORDER in height calculation"

# ============================================================
# Behavior 4: Items rendered as rounded cards with gaps
# Given  Ditto source code for item drawing
# When   the rendering logic is inspected
# Then   it uses RoundRect for card background, fills gap with MainWindowBG,
#        and draws a border on selected items
# ============================================================
Write-Host "`nBehavior 4: Items rendered as rounded cards with gaps" -ForegroundColor Cyan

Assert-Match $qlistSrc 'FillSolidRect\(rcItem,\s*CGetSetOptions::m_Theme\.MainWindowBG\(\)\)' "Gap area filled with MainWindowBG"
Assert-Match $qlistSrc 'RoundRect\(rcCard' "Card drawn with RoundRect"
Assert-Match $qlistSrc 'cardGap' "Card gap variable exists for spacing between items"
Assert-Match $qlistSrc 'cardInsetX' "Card horizontal inset from edges"
Assert-Match $qlistSrc 'cornerRadius' "Corner radius variable for rounded cards"
Assert-Match $qlistSrc 'rcCard.*rcItem' "Card rect derived from item rect"
Assert-Match $qlistSrc 'rcText\s*=\s*rcCard' "Text rect based on card rect (not item rect)"

# ============================================================
# Behavior 5: Dark theme matches Win+V colors
# Given  Windows is in dark mode
# When   Ditto loads the DarkerDitto theme
# Then   colors match Win+V dark mode palette (sampled values)
# ============================================================
Write-Host "`nBehavior 5: Dark theme matches Win+V colors" -ForegroundColor Cyan

$themePath = "Debug/Themes/DarkerDitto.xml"
if (Test-Path $themePath) {
    [xml]$theme = Get-Content $themePath

    $mainBg = $theme.Ditto_Theme_File.MainWindowBG
    $oddBg = $theme.Ditto_Theme_File.ListBoxOddRowsBG
    $evenBg = $theme.Ditto_Theme_File.ListBoxEvenRowsBG
    $oddText = $theme.Ditto_Theme_File.ListBoxOddRowsText
    $captionText = $theme.Ditto_Theme_File.CaptionTextColor

    Assert-Equal $mainBg "RGB(34,34,34)" "MainWindowBG matches Win+V panel background"
    Assert-Equal $oddBg "RGB(47,47,47)" "ListBoxOddRowsBG matches Win+V card background"
    Assert-Equal $evenBg "RGB(42,42,42)" "ListBoxEvenRowsBG slightly darker alternate"
    Assert-Equal $oddText "RGB(232,232,232)" "Text color matches Win+V light text"
    Assert-True ($captionText -ne "RGB(127,127,127)") "Caption text brighter than original"
} else {
    Write-Host "  FAIL: DarkerDitto.xml not found at $themePath" -ForegroundColor Red
    $script:failures += 5
}

# ============================================================
# Summary
# ============================================================
Write-Host "`n========================================" -ForegroundColor White
Write-Host "Results: $($script:passes) passed, $($script:failures) failed" -ForegroundColor $(if ($script:failures -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor White

exit $script:failures
