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

function Set-Prop {
    param($Object, [string]$Name, $Value)

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
}

function Ensure-Collection {
    param([string]$Name)

    Ensure-Prop $script:bible $Name @()
    if ($script:bible.$Name -isnot [array]) {
        $script:bible.$Name = @($script:bible.$Name)
    }
}

function Upsert-Entry {
    param([string]$CollectionName, $Entry)

    Ensure-Collection $CollectionName
    $items = @($script:bible.$CollectionName)
    $existing = $items | Where-Object { $_.id -eq $Entry.id } | Select-Object -First 1

    if ($null -eq $existing) {
        $script:bible.$CollectionName = @($items + $Entry)
        return
    }

    foreach ($prop in $Entry.PSObject.Properties) {
        Set-Prop $existing $prop.Name $prop.Value
    }
}

function Ref {
    param([string]$Collection, [string]$Id, [string]$Label, [string]$Note)
    [pscustomobject][ordered]@{ collection = $Collection; id = $Id; label = $Label; note = $Note }
}

function Fact {
    param([string]$Label, [string]$Value)
    [pscustomobject][ordered]@{ label = $Label; value = $Value }
}

function Detail {
    param([string]$Text)
    [pscustomobject][ordered]@{ at = $script:now; text = $Text }
}

foreach ($name in @("realms", "characters", "visualReferences", "places", "cities", "factions", "politics", "rulers", "items", "events", "openQuestions", "intakeLog")) {
    Ensure-Collection $name
}

function Remove-BrokenImportRows {
    param([string]$CollectionName)

    $script:bible.$CollectionName = @(@($script:bible.$CollectionName) | Where-Object {
        $id = [string]$_.id
        $name = [string]$_.name
        -not ($id.Length -le 1 -and $name.Length -le 1 -and @($_.tags) -contains "last-ward")
    })
}

Remove-BrokenImportRows "cities"
Remove-BrokenImportRows "places"
Remove-BrokenImportRows "factions"

$lastWardCrossRefs = @(
    Ref "characters" "the-fool" "The Fool" "Main character with formation and origin tied to the Last Ward."
    Ref "cities" "the-last-hold" "The Last Hold" "Capital fortress city and seat of the Proven Crown."
    Ref "cities" "hearthmere" "Hearthmere" "Breadbasket city and household heartland."
    Ref "cities" "redwall-ford" "Redwall Ford" "River fortress city controlling the main crossing."
    Ref "cities" "highmere-watch" "Highmere Watch" "Mountain fortress town for pass defense and monster watch."
    Ref "cities" "lanterns-rest" "Lantern's Rest" "Healing and refuge city."
    Ref "cities" "saints-crossing" "Saint's Crossing" "Road, rescue, caravan, scout, and messenger town."
    Ref "cities" "fisherward" "Fisherward" "Water, fish, salt, boat, trade, and patrol city."
    Ref "cities" "stoneacre" "Stoneacre" "Quarry and craft town for walls, roads, ironwork, and siege materials."
    Ref "cities" "mercyfield" "Mercyfield" "Protected farming and family province center."
    Ref "cities" "ashgate-march" "Ashgate March" "Border march town and early shield against outer pressure."
    Ref "rulers" "crown-warden" "Crown Warden" "Ruler title and final executive burden under right order."
    Ref "politics" "ortharchy" "Ortharchy" "Government principle: rule under right order."
    Ref "politics" "the-proven-crown" "The Proven Crown" "Common government and crown system of the Last Ward."
    Ref "factions" "the-wardmoot" "The Wardmoot" "Choosing and recognition body for the Proven Crown."
    Ref "factions" "the-lawkeepers" "The Lawkeepers" "Courts, disputes, inheritance, family law, crimes, and oath matters."
    Ref "factions" "the-wallwardens" "The Wallwardens" "Walls, roads, passes, gates, and border keeps."
    Ref "factions" "the-hearthwardens" "The Hearthwardens" "Households, food security, children, marriage, inheritance, and domestic stability."
    Ref "factions" "the-lantern-orders" "The Lantern Orders" "Care, medicine, refuge, recovery, mercy, and grief tending."
    Ref "factions" "the-grayknights" "The Grayknights" "Heavy defense, breach response, and high-risk monster pressure."
    Ref "factions" "saints" "Saints" "Elite speed, rescue, terrain, discipline, and precision defenders."
    Ref "factions" "paladins" "Paladins" "Elite armored defenders for direct confrontation and last stands."
)

$lastWard = [pscustomobject][ordered]@{
    id = "the-last-ward"
    name = "The Last Ward"
    category = "Defensible remnant state"
    status = "soft locked"
    aliases = @("The Ward")
    image = [pscustomobject][ordered]@{
        src = ""
        prompt = "A fortified remnant country called The Last Ward: white stone walls, red banners, black ironwork, warm lantern streets, family courts, training yards, chapels or holy halls, terraced gardens, fortified gates, water channels, granaries like fortresses, disciplined defenders, peaceful because it is defended."
    }
    biography = "The Last Ward is a fortified remnant state of roughly 850,000 Wardborn, governed by Ortharchy through The Proven Crown. It is ordered under truth, oath, mercy, family, protected life, disciplined force, and right order. It is the last ordered remnant against collapse, large enough to be a real country with cities, farms, roads, families, military depth, trade, provinces, and pressure from the horrors."
    properties = [pscustomobject][ordered]@{
        officialName = "The Last Ward"
        commonName = "The Ward"
        people = "Wardborn"
        status = "soft locked"
        countryType = "defensible remnant state"
        government = "Ortharchy"
        commonGovernmentName = "The Proven Crown"
        rulerTitle = "Crown Warden"
        totalPopulation = "850,000"
        flexiblePopulationRange = "700,000 to 1,000,000"
        landArea = "32,000 square miles, flexible range 25,000 to 45,000 square miles"
        capital = "The Last Hold, population 115,000"
        majorProvinces = "9"
        majorCities = "8 to 10"
        defenseCapablePopulation = "50,000"
        primaryColors = "red, white, black accents"
        corePhrase = "A house worth defending in a world teaching itself how to die"
    }
    sections = @(
        [pscustomobject][ordered]@{
            title = "Core Identity"
            body = "The Last Ward should remain disciplined, burdened, and under pressure, but not helpless or village-sized. Its canon identity is that it resists horrors better because it still understands truth, burden, stewardship, mercy, oath, right order, and the house as something worth defending."
            items = @(
                Fact "Political principle" "rule under right order"
                Fact "Crown system" "The Proven Crown"
                Fact "Ruler" "The Crown Warden"
                Fact "Civilizational role" "the last ordered remnant against collapse"
                Fact "Moral center" "truth, mercy, burden, oath, ordered force, family, protection, and keeping"
                Fact "Core phrase" "A house worth defending in a world teaching itself how to die"
            )
        }
        [pscustomobject][ordered]@{
            title = "Political Structure: Ortharchy"
            body = "Ortharchy is not normal monarchy. A monarchy answers who rules. Ortharchy answers what rule is bound to. The Crown Warden wears the crown, but the crown is bound beneath right order. He cannot make evil good by decree, use crystals, command the destruction of innocent life, or dissolve family, duty, protection, or truth for convenience."
            items = @(
                Fact "Government system" "Ortharchy"
                Fact "Common institutional name" "The Proven Crown"
                Fact "Head of state" "Crown Warden"
                Fact "Selection method" "chosen from the proven"
                Fact "Selection body" "The Wardmoot"
                Fact "Selection rite" "The Proving"
                Fact "Crowning oath" "The Burden Oath"
                Fact "Supreme law" "The Law of Right Order"
                Fact "Emergency refusal law" "No oath binds a man to disorder"
                Fact "Ruling principle" "authority is burden before privilege"
                Fact "Main restraint on ruler" "right order, oath, office, tradition, lawful refusal, and the Wardmoot"
            )
        }
        [pscustomobject][ordered]@{
            title = "Major Political Bodies"
            entries = @(
                [pscustomobject][ordered]@{ name = "The Crown Warden"; role = "final executive burden"; duties = @("Commands in war", "Judges in great crisis", "Guards the Mercies if known or entrusted", "Protects the Ward from invasion and breach", "Carries final responsibility when lesser offices fail", "Cannot rule against right order") }
                [pscustomobject][ordered]@{ name = "The Wardmoot"; role = "choosing and recognition body"; members = @("household heads", "elders", "proven defenders", "craft masters", "mothers and fathers of standing", "order representatives", "provincial speakers", "road wardens", "Lantern representatives", "Grayknight or Paladin officers"); duties = @("Recognizes fitness", "Does not invent fitness by popularity", "Can reject an unproven claimant", "Can refuse a disordered command") }
                [pscustomobject][ordered]@{ name = "The Lawkeepers"; role = "courts, disputes, contracts, inheritance, family law, crimes, and oath matters"; description = "Law serves truth and keeping, not appetite or public feeling." }
                [pscustomobject][ordered]@{ name = "The Wallwardens"; role = "defense of walls, roads, passes, gates, and border keeps" }
                [pscustomobject][ordered]@{ name = "The Hearthwardens"; role = "households, food security, children, marriage order, inheritance, and domestic stability" }
                [pscustomobject][ordered]@{ name = "The Lantern Orders"; role = "care, medicine, refuge, recovery, mercy, and grief tending" }
                [pscustomobject][ordered]@{ name = "The Grayknights"; role = "heavy defense, high risk combat, breach response, and major monster pressure" }
                [pscustomobject][ordered]@{ name = "Saints"; role = "speed, discipline, precision, difficult terrain, and rescue" }
                [pscustomobject][ordered]@{ name = "Paladins"; role = "strength, armor, direct confrontation, breach holding, and last stands" }
            )
        }
        [pscustomobject][ordered]@{
            title = "Population and Scale"
            body = "The Ward is pressured but not helpless. It can field armies, defend cities, absorb refugees, and maintain farms, roads, fortresses, and trade."
            items = @(Fact "Total population" "850,000"; Fact "Flexible range" "700,000 to 1,000,000")
            entries = @(
                [pscustomobject][ordered]@{ name = "Capital hold"; population = "115,000" }
                [pscustomobject][ordered]@{ name = "Inner farming ring"; population = "210,000" }
                [pscustomobject][ordered]@{ name = "Fortress towns"; population = "160,000" }
                [pscustomobject][ordered]@{ name = "Fishing and river settlements"; population = "90,000" }
                [pscustomobject][ordered]@{ name = "Mountain and border provinces"; population = "125,000" }
                [pscustomobject][ordered]@{ name = "Outlier provinces"; population = "100,000" }
                [pscustomobject][ordered]@{ name = "Active defense population included inside total"; population = "50,000" }
            )
        }
        [pscustomobject][ordered]@{
            title = "Capital: The Last Hold"
            body = "The Last Hold should feel beautiful and coveted, but not soft. It is peaceful because it is defended."
            items = @(
                Fact "Name" "The Last Hold"
                Fact "Status" "soft locked name"
                Fact "Population" "115,000"
                Fact "Function" "seat of the Proven Crown; primary fortress city; spiritual and legal center; military command center; archive center; training center; refuge center; main symbol of the Ward"
            )
            list = @("white stone", "red banners", "black ironwork", "high walls", "warm lanterns", "family courts", "training yards", "chapels or holy halls", "terraced gardens", "fortified gates", "water channels", "inner hearth districts")
        }
        [pscustomobject][ordered]@{
            title = "Major Cities and Regions"
            entries = @(
                [pscustomobject][ordered]@{ name = "The Last Hold"; population = "115,000"; type = "capital fortress city"; purpose = "crown, law, archives, high defense, central worship, command, and refuge"; identity = "The Crown Seat, Wardmoot Hall, Hall of Right Order, Red and White Gate, Mercy Gardens, Great Granaries, Wallward Barracks, Lantern Houses, Grayknight Yard, Archive of Keeping" }
                [pscustomobject][ordered]@{ name = "Hearthmere"; population = "68,000"; type = "agricultural city"; purpose = "breadbasket administration, mills, grain stores, livestock exchange, family courts, harvest festivals"; identity = "warm fields, mills, orchards, large household compounds, granary towers, marriage registries, child formation schools"; strategicValue = "feeds the capital and inner ring" }
                [pscustomobject][ordered]@{ name = "Redwall Ford"; population = "42,000"; type = "river fortress city"; purpose = "river crossing, trade control, ferry defense, bridge tax, military movement"; identity = "red stone bridge towers, deep river walls, chain gates across the water, boat yards, bridge chapels, fish markets"; strategicValue = "controls the main river crossing into the heartland" }
                [pscustomobject][ordered]@{ name = "Highmere Watch"; population = "36,000"; type = "mountain fortress town"; purpose = "pass defense, monster watch, signal towers, mining, quarrying, cold weather training"; identity = "high walls, snow roads, granite keeps, signal fires, ridge shrines, wolf bells, hard people"; strategicValue = "makes northern or mountain invasion miserable" }
                [pscustomobject][ordered]@{ name = "Lantern's Rest"; population = "31,000"; type = "healing and refuge city"; purpose = "recovery, widows, orphans, refugees, wounded defenders, spiritual repair"; identity = "lantern streets, quiet gardens, white cloisters, red doorways, recovery halls, mercy kitchens"; strategicValue = "absorbs suffering without letting the country spiritually rot" }
                [pscustomobject][ordered]@{ name = "Saint's Crossing"; population = "27,000"; type = "road and rescue town"; purpose = "caravan protection, road wardens, scouts, messengers, rescue patrols"; identity = "stables, road shrines, watch inns, signal posts, training fields, map houses"; strategicValue = "keeps roads open and prevents isolation" }
                [pscustomobject][ordered]@{ name = "Fisherward"; population = "24,000"; type = "coastal or lake city"; purpose = "fish, salt, boats, trade, naval patrols, food diversity"; identity = "red sails, white docks, salt houses, boat chapels, net markets, harbor walls"; strategicValue = "food security and coastal defense" }
                [pscustomobject][ordered]@{ name = "Stoneacre"; population = "19,000"; type = "quarry and craft town"; purpose = "stone, ironwork, wall repair, siege defense materials, road paving"; identity = "quarries, smith rows, stone yards, ox roads, mason guilds"; strategicValue = "maintains the walls and roads" }
                [pscustomobject][ordered]@{ name = "Mercyfield"; population = "16,000"; type = "protected farming and family province center"; purpose = "child formation, farms, orchards, family courts, seasonal musters"; identity = "wide fields, white fences, red roof tiles, training greens, family shrines, school houses"; strategicValue = "cultural heartland" }
                [pscustomobject][ordered]@{ name = "Ashgate March"; population = "13,000"; type = "border march town"; purpose = "hostile border defense, early warning, monster interception, hard road patrols"; identity = "black watchtowers, red signal flags, burnt fields reclaimed, outer wall camps, rough defenders"; strategicValue = "first shield against outer pressure" }
            )
        }
        [pscustomobject][ordered]@{
            title = "Settlement Categories"
            items = @(
                Fact "Capital city" "1"
                Fact "Major cities" "6 to 8"
                Fact "Fortress towns" "5 to 7"
                Fact "Market towns" "20 to 30"
                Fact "Walled villages" "90 to 120"
                Fact "Open farming villages" "250 to 400"
                Fact "Border keeps" "40 to 70"
                Fact "Watch posts" "150 to 250"
                Fact "Outlier settlements" "80 to 150"
                Fact "Remote farms and family holdings" "several thousand"
            )
        }
        [pscustomobject][ordered]@{
            title = "Land and Geography"
            body = "Recommended land area is 32,000 square miles, flexible between 25,000 and 45,000 square miles. This is large enough for multiple provinces and self-feeding depth, small enough to remain a remnant state, and defensible through terrain."
            list = @("mountain rim", "fortified valleys", "fertile central basin", "river network", "coastal or lake access", "deep forests", "high passes", "border marches", "stone ridges", "protected farmland")
        }
        [pscustomobject][ordered]@{
            title = "Provinces"
            entries = @(
                [pscustomobject][ordered]@{ name = "Crownhold Province"; population = "155,000"; includes = "The Last Hold and surrounding defensive belt"; function = "rule, archives, high defense" }
                [pscustomobject][ordered]@{ name = "Hearthmere Province"; population = "135,000"; function = "primary farming province; food and family formation" }
                [pscustomobject][ordered]@{ name = "Redwall Province"; population = "92,000"; function = "river crossings, bridge forts, ferry towns, trade roads" }
                [pscustomobject][ordered]@{ name = "Highmere Province"; population = "78,000"; function = "mountain villages, ridge keeps, quarry towns, pass defense" }
                [pscustomobject][ordered]@{ name = "Fisherward Province"; population = "74,000"; function = "fishing villages, salt houses, boatyards, water patrols" }
                [pscustomobject][ordered]@{ name = "Lantern Vale"; population = "88,000"; function = "healing houses, refugee settlements, widows farms, recovery towns" }
                [pscustomobject][ordered]@{ name = "Saint's Road"; population = "83,000"; function = "road towns, messenger routes, caravan defense, scout stations" }
                [pscustomobject][ordered]@{ name = "Ashgate March"; population = "65,000"; function = "most dangerous border province; outer threat shield" }
                [pscustomobject][ordered]@{ name = "Outer Hearths"; population = "80,000"; function = "outlier farms, converted refugee settlements, old allied villages, scattered holds" }
            )
        }
        [pscustomobject][ordered]@{
            title = "Military and Defense"
            body = "Primary doctrine: hold, shield, rescue, purge, endure. The Ward does not worship force and does not deny force; it orders force toward protection."
            items = @(Fact "Total defense capable population" "50,000"; Fact "Full time defenders" "18,000"; Fact "Elite and specialist orders" "12,000"; Fact "Militia and reserves" "20,000")
            entries = @(
                [pscustomobject][ordered]@{ name = "Full Time Forces"; list = @("Wallwardens: 7,000", "Roadwardens: 3,500", "Gate Guard: 2,000", "River and harbor patrol: 1,500", "Mounted messengers and scouts: 1,200", "Regular infantry: 2,800") }
                [pscustomobject][ordered]@{ name = "Elite and Specialist Orders"; list = @("Grayknights: 2,400", "Paladins: 1,200", "Saints: 1,500", "Lantern field protectors: 1,000", "Breach hunters: 1,800", "Monster scouts: 2,100", "Relic and archive guards: 700", "Crown guard: 1,300") }
                [pscustomobject][ordered]@{ name = "Reserves and Militia"; list = @("Town militias: 8,000", "Village musters: 6,500", "Border reserves: 3,500", "Emergency hearth defenders: 2,000") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Defense Doctrine and Monster Readiness"
            list = @("defend children", "defend households", "defend roads", "defend granaries", "defend wells", "defend gates", "defend passes", "recover the taken", "destroy breach growth early", "never rely on Woundsalt or crystals", "Most common threats near the Ward: T1 common outer leaks, T2 road hunters and field stalkers, T3 settlement level danger, T4 major local emergency, T5 breach expansion emergency", "A T5 is a major alarm because that class begins widening, stabilizing, or preparing breaches for greater entry. Higher classes require wider and more stable openings, and T10 cannot fully emerge without a major wound in reality.")
        }
        [pscustomobject][ordered]@{
            title = "Military Culture"
            list = @("Strength is for protection", "Force is for defense and restraint", "The weak are not proof of superiority", "The strong are not permitted to become predators", "A sword exists to guard the hearth", "A father is not a tyrant", "A mother is not a servant", "Children are entrusted life", "The crown is weight, not glory")
        }
        [pscustomobject][ordered]@{
            title = "Economy"
            body = "Household centered mixed economy under moral law. It is not socialism, communism, pure capitalism, merchant oligarchy, state ownership of everything, or a free appetite market."
            list = @("family farms", "guild craft", "fortress stores", "moral trade law", "defense tithe", "household property", "regulated markets", "inheritance duties", "road tolls", "grain reserves", "fish and salt trade", "iron, stone, timber, wool, leather, medicine")
            entries = @(
                [pscustomobject][ordered]@{ name = "Economic shares"; list = @("Agriculture: 42 percent", "Craft and construction: 16 percent", "Defense and public works: 14 percent", "Fishing and water trade: 8 percent", "Mining and quarrying: 6 percent", "Medicine, care, and refuge: 5 percent", "Education and formation: 4 percent", "Trade and transport: 5 percent") }
                [pscustomobject][ordered]@{ name = "Primary crops"; list = @("wheat", "barley", "rye", "oats", "beans", "peas", "root vegetables", "apples", "pears", "hardy greens", "medicinal herbs") }
                [pscustomobject][ordered]@{ name = "Livestock"; list = @("sheep", "goats", "cattle", "work oxen", "horses", "chickens", "geese") }
                [pscustomobject][ordered]@{ name = "Food reserves"; list = @("capital granary: 18 months", "province granaries: 9 to 14 months", "village stores: 3 to 6 months", "border keep stores: 6 to 12 months") }
                [pscustomobject][ordered]@{ name = "Exports"; list = @("worked stone", "iron tools", "red and white cloth", "wool", "salt fish", "preserved foods", "leather", "horses", "medicine", "fortification craft", "trained wardens for allied missions") }
                [pscustomobject][ordered]@{ name = "Imports"; list = @("rare spices", "paper", "fine glass", "some metals", "certain medicines", "books", "maps", "limited luxury goods", "news from outer roads") }
                [pscustomobject][ordered]@{ name = "Forbidden imports"; list = @("Woundsalt for use", "crystal powder", "crystal weapons", "slave goods", "body altering crystal compounds", "spell instruments powered by corrupt crystal craft") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Religion and Moral Order"
            body = "The Last Ward should feel Orthodox Christian rooted without directly naming Christianity."
            list = @("holy icons", "trinitarian echoes", "prayer", "blessings", "household thresholds", "lantern rites", "fasting seasons", "marriage oaths", "burial prayers", "red and white holy banners", "honor for fathers and mothers", "protection of entrusted life", "Life is received, not owned", "Force must be restrained by truth", "Mercy is not indulgence", "Justice is not cruelty", "Freedom without order becomes appetite", "Peace without truth becomes silence", "A house is worth defending")
        }
        [pscustomobject][ordered]@{
            title = "Social Structure and Education"
            items = @(
                Fact "Household type" "covenant household"
                Fact "Core unit" "family under oath, duty, love, and protection"
                Fact "Marriage meaning" "force covenant, fertility trust, inheritance bond, and household keeping"
                Fact "Fatherhood" "guardianship, final burden, restraint, provision, protection"
                Fact "Motherhood" "life keeping, nurture, formation, mercy, household wisdom"
                Fact "Children" "entrusted life, not property, not trophies, not burdensome calculations"
                Fact "Elders" "memory keepers and counsel"
                Fact "Widows and orphans" "protected by law and household networks"
                Fact "Refugees" "received under probation, care, and formation"
            )
            entries = @(
                [pscustomobject][ordered]@{ name = "Primary education"; list = @("reading", "numbers", "history", "household law", "field craft", "basic defense", "songs of memory", "monster warnings", "truth and oath formation", "care for the young and old", "anti-crystal teaching") }
                [pscustomobject][ordered]@{ name = "Advanced education"; list = @("law", "medicine", "theology", "engineering", "fortification", "scouting", "agriculture", "craft mastery", "military command", "archive work", "breach study") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Social Rites"
            items = @(
                Fact "Child naming rite" "The First Keeping"
                Fact "Coming of age rite" "The Bearing"
                Fact "Marriage rite" "The Hearth Oath"
                Fact "Defender rite" "The Shielding Vow"
                Fact "Public grief rite" "The Lantern Vigil"
                Fact "Crowning rite" "The Proving Crown"
                Fact "Emergency muster" "The Red Bell"
                Fact "Harvest rite" "The White Table"
            )
        }
        [pscustomobject][ordered]@{
            title = "Cultural Colors and Architecture"
            body = "White belongs to mercy, purity, walls, and holy order. Red belongs to sacrifice, courage, blood rightly spent, and defense. Black belongs to restraint, mourning, iron, and sober duty. Beauty is allowed because it is defended."
            list = @("red", "white", "black accents", "fortified beauty", "white stone", "red banners", "black iron", "high roofs", "deep hearths", "arched gates", "thick walls", "terraced gardens", "watch towers", "lantern streets", "chapels or holy halls", "family courtyards", "water channels", "granaries built like fortresses")
        }
        [pscustomobject][ordered]@{
            title = "Laws"
            items = @(
                Fact "Foundational law" "The Law of Right Order"
                Fact "Crystal law" "The Shard Ban"
                Fact "Family law" "The Hearth Covenant"
                Fact "Military law" "The Shield Code"
                Fact "Inheritance law" "The Line and Keeping Statutes"
                Fact "Refugee law" "The Open Gate Burden"
                Fact "Emergency law" "The Red Bell Authority"
                Fact "Anti-corruption law" "The Woundsalt Prohibition"
            )
            list = @("No crystal craft may be used.", "No Woundsalt may be traded for use.", "No innocent life may be intentionally destroyed.", "No father may abandon household burden without judgment.", "No mother may be stripped of household honor by appetite law.", "No ruler may command disorder.", "No oath binds a man to evil.", "No household may refuse lawful defense duty.", "No child may be treated as trophy, property, or inconvenience.", "No medicine may conceal harm while pretending to heal.")
        }
        [pscustomobject][ordered]@{
            title = "Alliances and Hostile Powers"
            entries = @(
                [pscustomobject][ordered]@{ name = "Natural allies"; list = @("small border villages", "old houses that reject crystal use", "some White Pill or restoration aligned people if purified from false hope", "anti-Woundsalt hunters", "families fleeing Ivory Bastion or Hall corruption", "honest traders who accept Ward law") }
                [pscustomobject][ordered]@{ name = "Difficult allies"; list = @("Veymark merchants", "Gold Pill reciprocity courts", "Purple compromise factions", "some Blue Pill refugees", "disillusioned Hall warriors", "scarred men from the Bastion") }
                [pscustomobject][ordered]@{ name = "Enemies or hostile powers"; list = @("Ivory Bastion authorities", "Hall of Kings authorities", "crystal traders", "Woundsalt refiners", "horror worshipers if any emerge", "raiders", "false healers", "vanity lords", "anti-household ideologues") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Technology and Military Equipment"
            body = "Base level is late medieval to early renaissance fantasy. The Ward has better metallurgy, wall engineering, grain storage, water systems, road defense, anti-horror equipment, discipline, training, medical ethics, and logistics."
            entries = @(
                [pscustomobject][ordered]@{ name = "Not allowed"; list = @("crystal powered industry", "Woundsalt weapons", "spell engines", "casual fantasy firearms unless later approved", "modern machinery") }
                [pscustomobject][ordered]@{ name = "Common arms"; list = @("swords", "spears", "bows", "crossbows", "axes", "hammers", "shields", "chainmail", "plate elements", "lamellar or scale in border regions") }
                [pscustomobject][ordered]@{ name = "Ward special arms"; list = @("anti-horror polearms", "sanctified shields", "red-white tower shields", "weighted nets", "hooked rescue spears", "breach stakes", "lantern beacons", "signal horns", "holy icon standards", "saltless cleansing compounds", "fire traps if not silly", "heavy gate bows") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Internal Weaknesses and External Pressures"
            entries = @(
                [pscustomobject][ordered]@{ name = "Internal weaknesses"; list = @("fatigue", "siege pressure", "refugee strain", "limited luxury goods", "internal fear of corruption", "older families becoming proud of being the good realm", "young people tempted by outer glamour", "defenders becoming bitter", "Lanterns overburdened by endless grief", "border towns feeling forgotten", "pressure to use crystals just once", "danger of Ortharchy becoming status pride if virtue decays") }
                [pscustomobject][ordered]@{ name = "External pressures"; list = @("The Ivory Bastion wants to expose it as oppressive.", "The Hall of Kings wants to mock it as weak or outdated.", "Veymark may want access to its roads, purity reputation, or defensive craft.", "Crystal powers want it compromised.", "Horrors press on its borders.", "Refugees strain its food and formation systems.", "The Last Ward must stay generous without becoming naive.") }
            )
        }
        [pscustomobject][ordered]@{
            title = "Story Function"
            body = "The Last Ward is not the place where the story becomes easy. It is the place that proves another order is possible. Its goodness creates pressure because people come for shelter, reputation cleansing, safety, beauty, or real conversion. Some truly change. Some only hide inside its goodness."
            list = @("safer roads", "cleaner homes", "stronger families", "better walls", "more trusted men", "more honored women", "healthier children", "less crystal dependence", "more stable food", "more real beauty", "more moral seriousness")
        }
        [pscustomobject][ordered]@{
            title = "Soft Lock"
            items = @(
                Fact "The Last Ward total population" "850,000"
                Fact "Capital population" "115,000"
                Fact "Government" "Ortharchy"
                Fact "Common crown name" "The Proven Crown"
                Fact "Ruler" "Crown Warden"
                Fact "Land area" "32,000 square miles"
                Fact "Major provinces" "9"
                Fact "Major cities" "8 to 10"
                Fact "Full defense capable population" "50,000"
                Fact "Primary colors" "red, white, black accents"
                Fact "Moral identity" "right order, mercy, burden, family, protected life, and disciplined force"
            )
        }
    )
    aiPrompts = @(
        [pscustomobject][ordered]@{ at = $now; text = "Use The Last Ward as the red-white-black fortified remnant of right order: beautiful because defended, merciful without indulgence, strong without predation, Orthodox-rooted without naming Christianity directly, disciplined under The Proven Crown and the Law of Right Order." }
    )
    importantDetails = @(
        Detail "Soft locked: population 850,000, capital 115,000, government Ortharchy, common crown name The Proven Crown, ruler Crown Warden, land area 32,000 square miles, 9 provinces, 8 to 10 major cities, 50,000 defense capable population, primary colors red/white/black accents."
        Detail "The Last Ward must be a real country with cities, farms, roads, military depth, families, trade, and provinces. It should not feel like a tiny village."
        Detail "The Ward is good but not perfect. Its goodness creates pressure, envy, refugee strain, temptation, fatigue, and the risk that older families become proud of being the good realm."
    )
    crossReferences = $lastWardCrossRefs
    tags = @("last-ward", "realm", "nation", "ortharchy", "proven-crown", "right-order", "soft-locked", "red-white-black", "anti-crystal", "remnant-state")
    createdAt = $now
    updatedAt = $now
}

Upsert-Entry "realms" $lastWard

$cityData = @(
    ,@("the-last-hold", "The Last Hold", "Capital fortress city", "115,000", "crown, law, archives, high defense, central worship, command, and refuge", "The Crown Seat; Wardmoot Hall; Hall of Right Order; Red and White Gate; Mercy Gardens; Great Granaries; Wallward Barracks; Lantern Houses; Grayknight Yard; Archive of Keeping")
    ,@("hearthmere", "Hearthmere", "Agricultural city", "68,000", "breadbasket administration, mills, grain stores, livestock exchange, family courts, harvest festivals", "feeds the capital and inner ring")
    ,@("redwall-ford", "Redwall Ford", "River fortress city", "42,000", "river crossing, trade control, ferry defense, bridge tax, military movement", "controls the main river crossing into the heartland")
    ,@("highmere-watch", "Highmere Watch", "Mountain fortress town", "36,000", "pass defense, monster watch, signal towers, mining, quarrying, cold weather training", "makes northern or mountain invasion miserable")
    ,@("lanterns-rest", "Lantern's Rest", "Healing and refuge city", "31,000", "recovery, widows, orphans, refugees, wounded defenders, spiritual repair", "absorbs suffering without letting the country spiritually rot")
    ,@("saints-crossing", "Saint's Crossing", "Road and rescue town", "27,000", "caravan protection, road wardens, scouts, messengers, rescue patrols", "keeps roads open and prevents isolation")
    ,@("fisherward", "Fisherward", "Coastal or lake city", "24,000", "fish, salt, boats, trade, naval patrols, food diversity", "food security and coastal defense")
    ,@("stoneacre", "Stoneacre", "Quarry and craft town", "19,000", "stone, ironwork, wall repair, siege defense materials, road paving", "maintains the walls and roads")
    ,@("mercyfield", "Mercyfield", "Protected farming and family province center", "16,000", "child formation, farms, orchards, family courts, seasonal musters", "cultural heartland")
    ,@("ashgate-march", "Ashgate March", "Border march town", "13,000", "hostile border defense, early warning, monster interception, hard road patrols", "first shield against outer pressure")
)

foreach ($row in $cityData) {
    Upsert-Entry "cities" ([pscustomobject][ordered]@{
        id = $row[0]
        name = $row[1]
        category = $row[2]
        status = "active"
        image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
        biography = "$($row[1]) is a Last Ward city: $($row[4])."
        properties = [pscustomobject][ordered]@{ realm = "The Last Ward"; population = $row[3]; purpose = $row[4]; strategicValue = $row[5] }
        importantDetails = @(Detail "Last Ward city. Strategic value: $($row[5]).")
        crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Parent realm")
        tags = @("last-ward", "city")
        createdAt = $now
        updatedAt = $now
    })
}

$provinceData = @(
    ,@("crownhold-province", "Crownhold Province", "155,000", "The Last Hold and surrounding defensive belt", "rule, archives, high defense")
    ,@("hearthmere-province", "Hearthmere Province", "135,000", "primary farming province", "food and family formation")
    ,@("redwall-province", "Redwall Province", "92,000", "river crossings, bridge forts, ferry towns, trade roads", "river control and trade")
    ,@("highmere-province", "Highmere Province", "78,000", "mountain villages, ridge keeps, quarry towns, pass defense", "mountains, quarrying, pass defense")
    ,@("fisherward-province", "Fisherward Province", "74,000", "fishing villages, salt houses, boatyards, water patrols", "fish, salt, boats, water defense")
    ,@("lantern-vale", "Lantern Vale", "88,000", "healing houses, refugee settlements, widows farms, recovery towns", "healing and refuge")
    ,@("saints-road", "Saint's Road", "83,000", "road towns, messenger routes, caravan defense, scout stations", "roads, scouts, caravans")
    ,@("ashgate-march-province", "Ashgate March", "65,000", "most dangerous border province", "outer threat shield")
    ,@("outer-hearths", "Outer Hearths", "80,000", "outlier farms, converted refugee settlements, old allied villages, scattered holds", "outlier villages and converted refugee settlements")
)

foreach ($row in $provinceData) {
    Upsert-Entry "places" ([pscustomobject][ordered]@{
        id = $row[0]
        name = $row[1]
        category = "Province"
        status = "active"
        image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
        biography = "$($row[1]) is a province of The Last Ward: $($row[3])."
        properties = [pscustomobject][ordered]@{ realm = "The Last Ward"; population = $row[2]; includes = $row[3]; function = $row[4] }
        importantDetails = @(Detail "Province function: $($row[4]).")
        crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Parent realm")
        tags = @("last-ward", "province")
        createdAt = $now
        updatedAt = $now
    })
}

Upsert-Entry "politics" ([pscustomobject][ordered]@{
    id = "ortharchy"
    name = "Ortharchy"
    category = "Government principle"
    status = "soft locked"
    image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
    biography = "Ortharchy means rule under right order. It is not normal monarchy: monarchy asks who rules, Ortharchy asks what rule is bound to."
    properties = [pscustomobject][ordered]@{ governmentSystem = "Ortharchy"; supremeLaw = "The Law of Right Order"; emergencyRefusalLaw = "No oath binds a man to disorder"; rulingPrinciple = "authority is burden before privilege" }
    importantDetails = @(Detail "The Crown Warden cannot make evil good by decree, cannot use crystals, cannot command innocent death, and cannot dissolve family, duty, protection, or truth for convenience.")
    crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Realm governed by Ortharchy"; Ref "rulers" "crown-warden" "Crown Warden" "Ruler bound by Ortharchy")
    tags = @("last-ward", "ortharchy", "politics", "right-order")
    createdAt = $now
    updatedAt = $now
})

Upsert-Entry "politics" ([pscustomobject][ordered]@{
    id = "the-proven-crown"
    name = "The Proven Crown"
    category = "Crown system"
    status = "soft locked"
    image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
    biography = "The Proven Crown is the common government name and crown system of The Last Ward. The ruler is chosen from the proven through the Wardmoot and The Proving, then bound by The Burden Oath."
    properties = [pscustomobject][ordered]@{ selectionMethod = "chosen from the proven"; selectionBody = "The Wardmoot"; selectionRite = "The Proving"; crowningOath = "The Burden Oath"; headOfState = "Crown Warden" }
    importantDetails = @(Detail "The crown is weight, not glory.")
    crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Realm using The Proven Crown"; Ref "factions" "the-wardmoot" "The Wardmoot" "Selection and recognition body"; Ref "rulers" "crown-warden" "Crown Warden" "Bearer of the crown")
    tags = @("last-ward", "proven-crown", "crown-system")
    createdAt = $now
    updatedAt = $now
})

Upsert-Entry "rulers" ([pscustomobject][ordered]@{
    id = "crown-warden"
    name = "Crown Warden"
    category = "Ruler title"
    status = "soft locked"
    image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
    biography = "The Crown Warden is the head of state and final executive burden of The Last Ward. He commands in war, judges in great crisis, guards the Mercies if known or entrusted, protects the Ward from invasion and breach, and cannot rule against right order."
    properties = [pscustomobject][ordered]@{ realm = "The Last Ward"; crownSystem = "The Proven Crown"; oath = "The Burden Oath"; restraint = "right order, oath, office, tradition, lawful refusal, and the Wardmoot" }
    importantDetails = @(Detail "The Crown Warden bears final responsibility but does not own the order.")
    crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Realm served by this office"; Ref "politics" "ortharchy" "Ortharchy" "Government principle"; Ref "politics" "the-proven-crown" "The Proven Crown" "Crown system")
    tags = @("last-ward", "crown-warden", "ruler", "proven-crown")
    createdAt = $now
    updatedAt = $now
})

$factionRows = @(
    ,@("the-wardmoot", "The Wardmoot", "Choosing and recognition body", "Recognizes fitness, rejects unproven claimants, and can refuse disordered commands.")
    ,@("the-lawkeepers", "The Lawkeepers", "Courts and oath law", "Handles courts, disputes, contracts, inheritance, family law, crimes, and oath matters.")
    ,@("the-wallwardens", "The Wallwardens", "Defense order", "Defends walls, roads, passes, gates, and border keeps.")
    ,@("the-hearthwardens", "The Hearthwardens", "Household order", "Guards households, food security, children, marriage order, inheritance, and domestic stability.")
    ,@("the-lantern-orders", "The Lantern Orders", "Mercy and healing order", "Handles care, medicine, refuge, recovery, mercy, and grief tending.")
    ,@("the-grayknights", "The Grayknights", "Heavy defense order", "Handles high risk combat, breach response, and major monster pressure.")
    ,@("saints", "Saints", "Elite defenders", "Speed, discipline, precision, difficult terrain, and rescue.")
    ,@("paladins", "Paladins", "Elite defenders", "Strength, armor, direct confrontation, breach holding, and last stands.")
)

foreach ($row in $factionRows) {
    Upsert-Entry "factions" ([pscustomobject][ordered]@{
        id = $row[0]
        name = $row[1]
        category = $row[2]
        status = "active"
        image = [pscustomobject][ordered]@{ src = ""; prompt = "" }
        biography = $row[3]
        properties = [pscustomobject][ordered]@{ realm = "The Last Ward"; function = $row[3] }
        importantDetails = @(Detail $row[3])
        crossReferences = @(Ref "realms" "the-last-ward" "The Last Ward" "Realm served by this body")
        tags = @("last-ward", "order", "institution")
        createdAt = $now
        updatedAt = $now
    })
}

$fool = @($bible.characters) | Where-Object { $_.id -eq "the-fool" } | Select-Object -First 1
if ($null -ne $fool) {
    Ensure-Prop $fool "image" ([pscustomobject][ordered]@{ src = ""; prompt = "" })
    $fool.image.src = "/assets/characters/the-fool-portrait.png"
    Ensure-Prop $fool "crossReferences" @()
    if ($fool.crossReferences -isnot [array]) { $fool.crossReferences = @($fool.crossReferences) }
    if (-not (@($fool.crossReferences) | Where-Object { $_.collection -eq "realms" -and $_.id -eq "the-last-ward" })) {
        $fool.crossReferences = @($fool.crossReferences + (Ref "realms" "the-last-ward" "The Last Ward" "Origin, formation, and moral homeland reference."))
    }
    Ensure-Prop $fool "importantDetails" @()
    if ($fool.importantDetails -isnot [array]) { $fool.importantDetails = @($fool.importantDetails) }
    if (-not (@($fool.importantDetails) | Where-Object { $_.text -like "*portrait crop*" })) {
        $fool.importantDetails = @($fool.importantDetails + (Detail "Portrait crop added from the initial concept sheet so the character page can show a single-character portrait first, with the full concept sheet below as reference art."))
    }
    $fool.updatedAt = $now
}

$bible.updatedAt = $now
$bible | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $StoryBiblePath -Encoding UTF8
Write-Output "Last Ward repository entries added to $StoryBiblePath"
