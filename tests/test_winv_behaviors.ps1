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

Assert-Equal $defaultLinesPerRow 2 "Default text wrap cap is 2 lines (Win+V); row pitch (IMAGE_CARD_LINES) is taller for image previews"

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

Assert-Equal $topBorder 14 "ROW_TOP_BORDER is 14 (tighter padding for compact 2-line cards)"
Assert-Equal $bottomBorder 14 "ROW_BOTTOM_BORDER is 14 (reduces empty lower band)"
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

# Win+V amplitude: generous spacing between cards (matches the airy WinUI3 layout)
$gapMatch = [regex]::Match($qlistSrc, 'cardGap\s*=\s*m_windowDpi->Scale\((\d+)\)')
$insetMatch = [regex]::Match($qlistSrc, 'cardInsetX\s*=\s*m_windowDpi->Scale\((\d+)\)')
$radiusMatch = [regex]::Match($qlistSrc, 'cornerRadius\s*=\s*m_windowDpi->Scale\((\d+)\)')
$cardGap = if ($gapMatch.Success) { [int]$gapMatch.Groups[1].Value } else { -1 }
$cardInsetX = if ($insetMatch.Success) { [int]$insetMatch.Groups[1].Value } else { -1 }
$cornerRadius = if ($radiusMatch.Success) { [int]$radiusMatch.Groups[1].Value } else { -1 }
Assert-Equal $cardGap 5 "cardGap is 5 (~10px even gap matching Win+V row spacing)"
Assert-Equal $cardInsetX 10 "cardInsetX is 10 (Win+V side margins)"
Assert-Equal $cornerRadius 8 "cornerRadius is 8 (Fluent card corner radius)"

# Win+V selection: clear 2px bright outline on the selected card
Assert-Match $qlistSrc 'borderPen\(PS_SOLID,\s*m_windowDpi->Scale\(2\)' "Selected card uses a 2px outline"
Assert-Match $qlistSrc 'rcBorder\.DeflateRect' "Selection outline inset so the stroke is not clipped"

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
    Assert-Equal $oddBg "RGB(48,48,48)" "ListBoxOddRowsBG matches Win+V card background"
    Assert-Equal $evenBg "RGB(48,48,48)" "ListBoxEvenRowsBG uniform (Win+V has no zebra striping)"
    Assert-True ($oddBg -eq $evenBg) "Card color is uniform across rows (no zebra, matching Win+V)"
    Assert-Equal $oddText "RGB(232,232,232)" "Text color matches Win+V light text"
    Assert-True ($captionText -ne "RGB(127,127,127)") "Caption text brighter than original"
} else {
    Write-Host "  FAIL: DarkerDitto.xml not found at $themePath" -ForegroundColor Red
    $script:failures += 5
}

# ============================================================
# Behavior 6: Fluent type ramp — content and chrome at Body 14, no inversion
# Given  Ditto source
# When   the item, search and group font sizes are checked
# Then   item=14, search=14, group=14 (all Body); Fluent de-emphasizes chrome by
#        COLOR (lighter neutral), not by shrinking the glyph below the 14px content
# ============================================================
Write-Host "`nBehavior 6: Fluent type ramp (content and chrome at Body 14)" -ForegroundColor Cyan

$pasteSrc = Get-Content "src/QPasteWnd.cpp" -Raw

$itemFontMatch = [regex]::Match($optionsSrc, 'font\.lfHeight\s*=\s*-(\d+);')
$searchFontMatch = [regex]::Match($pasteSrc, 'm_SearchFont\.CreateFont\(-m_DittoWindow\.m_dpi\.Scale\((\d+)\)')
$groupFontMatch = [regex]::Match($pasteSrc, 'm_groupFont\.CreateFont\(-m_DittoWindow\.m_dpi\.Scale\((\d+)\)')
$itemFont = if ($itemFontMatch.Success) { [int]$itemFontMatch.Groups[1].Value } else { -1 }
$searchFont = if ($searchFontMatch.Success) { [int]$searchFontMatch.Groups[1].Value } else { -1 }
$groupFont = if ($groupFontMatch.Success) { [int]$groupFontMatch.Groups[1].Value } else { -1 }

Assert-Equal $itemFont 14 "Item content font is 14px (Fluent Body)"
Assert-Equal $searchFont 14 "Search font is 14px (Fluent Body, parity with content)"
Assert-Equal $groupFont 14 "Group label font is 14px (Body); de-emphasized by color, not by shrinking"
Assert-True ($itemFont -ge $searchFont) "Content font >= search chrome (no inverted hierarchy)"
Assert-True ($searchFont -ge $groupFont) "Chrome fonts at parity (Body 14); hierarchy via color not size"

# ============================================================
# Behavior 7: Item text word-wraps and is top-aligned (Win+V)
# Given  Ditto item drawing
# When   the DrawText/DrawHTML flags are checked
# Then   they use DT_WORDBREAK + DT_TOP (+ DT_END_ELLIPSIS), not DT_VCENTER
# ============================================================
Write-Host "`nBehavior 7: Item text word-wraps and top-aligns" -ForegroundColor Cyan

Assert-Match $qlistSrc 'DT_WORDBREAK \| DT_TOP \| DT_EXPANDTABS \| DT_NOPREFIX' "Item text uses word-break + top-align (no DT_END_ELLIPSIS/DT_EDITCONTROL which suppress multiline wrap in GDI)"
Assert-True (-not ($qlistSrc -match 'DT_END_ELLIPSIS')) "DT_END_ELLIPSIS removed (it collapses DT_WORDBREAK to a single ellipsized line)"
Assert-True (-not ($qlistSrc -match 'DT_VCENTER \| DT_EXPANDTABS')) "DT_VCENTER no longer used for item text (was single-line centered)"
Assert-Match $qlistSrc 'csText\.Replace\(_T\("\\r\\n"\), _T\("\\n"\)\)' "Newlines normalized to CR-LF before draw (safe DT_WORDBREAK)"

# ============================================================
# Summary
# ============================================================
Write-Host "`n========================================" -ForegroundColor White
Write-Host "Results: $($script:passes) passed, $($script:failures) failed" -ForegroundColor $(if ($script:failures -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor White

exit $script:failures
