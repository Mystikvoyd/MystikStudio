param(
    [string]$StoryBiblePath = (Join-Path $PSScriptRoot "..\..\..\webpage\story-dashboard\story-bible.json")
)

$ErrorActionPreference = "Stop"
$StoryBiblePath = [System.IO.Path]::GetFullPath($StoryBiblePath)
$bible = Get-Content -LiteralPath $StoryBiblePath -Raw | ConvertFrom-Json
$now = (Get-Date).ToString("o")

function Ensure-Prop {
    param($Object, [string]$Name, $Value)

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
    elseif ($null -eq $Object.$Name) {
        $Object.$Name = $Value
    }
}

function Set-MapPoint {
    param(
        [string]$Collection,
        [string]$Id,
        [double]$X,
        [double]$Y,
        [double]$Zoom,
        [string]$Kind,
        [string]$Note
    )

    $entry = @($script:bible.$Collection) | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if ($null -eq $entry) {
        return
    }

    $entryMap = [pscustomobject][ordered]@{
        x = $X
        y = $Y
        zoom = $Zoom
        kind = $Kind
        note = $Note
        updatedAt = $script:now
    }

    Ensure-Prop $entry "map" $entryMap
    $entry.map = $entryMap
    $entry.updatedAt = $script:now
}

Ensure-Prop $bible "map" ([pscustomobject][ordered]@{})
$bible.map = [pscustomobject][ordered]@{
    image = [pscustomobject][ordered]@{
        src = "/assets/maps/world-map.svg"
        name = "Working World Map"
    }
    notes = "Temporary local map. Replace the image by placing your real map in book/assets/maps and changing this src to /assets/maps/your-file-name.png."
    updatedAt = $now
}

Set-MapPoint "realms" "the-last-ward" 46.0 57.0 2.2 "realm" "Soft placeholder location for The Last Ward until the final map is supplied."
Set-MapPoint "cities" "the-last-hold" 46.0 57.0 3.4 "capital" "Capital fortress city and seat of the Proven Crown."
Set-MapPoint "cities" "hearthmere" 42.8 61.7 3.4 "city" "Agricultural city and breadbasket administration."
Set-MapPoint "cities" "redwall-ford" 50.8 58.8 3.4 "city" "River crossing and trade control."
Set-MapPoint "cities" "highmere-watch" 45.6 49.5 3.4 "city" "Mountain fortress town and pass defense."
Set-MapPoint "cities" "lanterns-rest" 48.3 63.2 3.4 "city" "Healing and refuge city."
Set-MapPoint "cities" "saints-crossing" 53.7 61.2 3.4 "city" "Road, rescue, scout, and messenger town."
Set-MapPoint "cities" "fisherward" 59.6 66.8 3.2 "city" "Water access, fish, salt, boats, trade, and patrols."
Set-MapPoint "cities" "stoneacre" 39.0 54.7 3.4 "city" "Quarry and craft town."
Set-MapPoint "cities" "mercyfield" 44.8 65.8 3.4 "city" "Protected farming and family province center."
Set-MapPoint "cities" "ashgate-march" 57.4 51.0 3.2 "city" "Dangerous border march and early warning shield."

Set-MapPoint "places" "crownhold-province" 46.2 57.4 2.8 "province" "The Last Hold and surrounding defensive belt."
Set-MapPoint "places" "hearthmere-province" 42.4 62.4 2.8 "province" "Primary farming province."
Set-MapPoint "places" "redwall-province" 51.2 59.2 2.8 "province" "River crossings, bridge forts, ferry towns, and trade roads."
Set-MapPoint "places" "highmere-province" 45.8 48.8 2.8 "province" "Mountain villages, ridge keeps, quarry towns, and pass defense."
Set-MapPoint "places" "fisherward-province" 59.9 67.2 2.7 "province" "Fishing villages, salt houses, boatyards, and water patrols."
Set-MapPoint "places" "lantern-vale" 48.5 63.8 2.8 "province" "Healing houses, refugee settlements, widows' farms, and recovery towns."
Set-MapPoint "places" "saints-road" 53.8 61.9 2.8 "province" "Road towns, messenger routes, caravan defense, and scout stations."
Set-MapPoint "places" "ashgate-march-province" 57.7 51.5 2.7 "province" "Most dangerous border province."
Set-MapPoint "places" "outer-hearths" 40.1 66.5 2.5 "province" "Outlier farms, converted refugee settlements, old allied villages, and scattered holds."

$bible.updatedAt = $now
$bible | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $StoryBiblePath -Encoding UTF8
Write-Output "Interactive map data added to $StoryBiblePath"
