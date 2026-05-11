# Dashboard Specification Template

> A generic guide for building a modular launcher dashboard in PowerShell WinForms.
> Replace bracketed `[like this]` with your own content.

---

## 1. Concept

A single-window **launcher hub** that auto-discovers tools/folders and
presents them in a dark-themed, multi-column panel layout. The user
should be able to launch tools, open folders, and browse the project
structure without leaving the dashboard.

---

## 2. Layout Architecture

```
┌─ LEFT (folder tree) ─┬─ RIGHT (3 columns of panel groups) ──────────────┐
│                       │  [icon]  [Brand A]  [Brand B]  [Brand C]  [D]   │
│  ROOT                 │                                                   │
│  ├─ Category 1        │  ┌─Panel 1──┐ ┌─Panel 2──┐ ┌─Panel 3──┐        │
│  │  ├─ Subfolder      │  │ Button 1 │ │ Button 1 │ │ Button 1 │        │
│  │  └─ Subfolder      │  │ Button 2 │ │ Button 2 │ │ Button 2 │        │
│  ├─ Category 2        │  └──────────┘ └──────────┘ └──────────┘        │
│  └─ Category 3        │  ┌─Panel 4──┐ ┌─Panel 5──┐ ┌─Panel 6──┐        │
│                       │  │ Button 1 │ │ Button 1 │ │ Button 1 │        │
│                       │  └──────────┘ └──────────┘ └──────────┘        │
│                       │  ┌─Panel 7──┐ ┌─Panel 8──┐ ┌─Panel 9──┐        │
│                       │  │ Button 1 │ │ Button 1 │ │ Button 1 │        │
│                       │  └──────────┘ └──────────┘ └──────────┘        │
│                       │  ┌─Panel10──┐ ┌─Panel11──┐ ┌─Panel12──┐        │
│                       │  │ Button 1 │ │ Button 1 │ │ Button 1 │        │
│                       │  └──────────┘ └──────────┘ └──────────┘        │
├───────────────────────┴────────────────────────────────────────────────┤
│  Status bar: [Project Name]  |  [N] tools                               │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Layout Rules

| Element | Rule |
|---------|------|
| Window | Dark background `#181820`, size ~1000×760, centered |
| Splitter | Left pane (folder tree) ~240px, right pane (panels) fills rest |
| Tree | Dark theme, node colors, double-click opens folder |
| Header | Centered brand items with distinct colors, icon on left |
| Columns | 3 equal columns of GroupBox panels, ~8px gaps |
| Panels | GroupBox with titled border, stacked full-width buttons |
| Buttons | Left-aligned text, flat style, color-coded, tooltips |
| Status bar | 24px docked bar at window bottom, full width |
| Scroll | Right panel scrolls if content exceeds window height |

---

## 3. Implementation Technology

- **Language**: PowerShell 5.1+ (no external dependencies)
- **UI Framework**: Windows Forms (`System.Windows.Forms`, `System.Drawing`)
- **Form**: `Add-Type -AssemblyName` to load assemblies
- **Start**: VBScript launcher that calls `powershell.exe -WindowStyle Hidden`

### Architecture Pattern

```powershell
# 1. Discovery: Scan folders for configuration files
# 2. Build: Create form → splitter → tree + panel area
# 3. Populate: Create GroupBox panels with buttons
# 4. Show: form.ShowDialog()
```

---

## 4. Core Components

### 4.1 Auto-Discovery (if applicable)

Scan subdirectories for a config file (e.g. `tool.json`) to
dynamically build the button list. Each tool should define:

```json
{
    "name": "Display Name",
    "description": "What this tool does",
    "color": "#HEXCOLOR",
    "launcher": "path-to-launcher.vbs",    // for executable tools
    "folder": "relative-path"              // for folder shortcuts
}
```

### 4.2 Folder Tree

A `System.Windows.Forms.TreeView` on the left panel:

- Root node for the project
- Category sub-nodes
- Double-click opens the folder in Explorer
- Dark theme (dark bg, light text, subtle line colors)

### 4.3 Header / Hub

Centered branding area with 4-6 named items in a specific order.
Each item has its own color. Items auto-center on window resize.

### 4.4 Panel Groups

`System.Windows.Forms.GroupBox` controls containing buttons:

```powershell
function Add-PanelBox {
    param(
        [System.Windows.Forms.Panel]$Parent,
        [string]$Title,
        [object[]]$Buttons
    )
    # Creates a GroupBox with titled border
    # Stacks buttons vertically (full-width)
    # Each button: flat, left-aligned text, tooltip
    # Supports: file/folder launcher, URL, cmd with arguments
}
```

### 4.5 Button Actions

Each button supports one of these modes:

| Mode | Action |
|------|--------|
| `(none)` | `Start-Process -FilePath $Target` — open file/folder |
| `url` | `Start-Process $Target` — open URL in browser |
| `Arguments` | `Start-Process -FilePath $Target -ArgumentList $Args` |

### 4.6 Status Bar

A 24px panel docked to the bottom of the form, spanning full width.
Shows: project name, tool count, or other metadata.

---

## 5. Visual Design System

### Color Palette

```
Background (form):     #181820
Background (panels):   #1C1C26
Panel borders:         GroupBox default dark
Headers (sections):    #AAB0C8 (muted blue-gray)
Button text:           White
```

### Brand Item Colors (example)

```
Brand A    Crimson Red    #DC143C
Brand B    Pink           #FF69B4
Brand C    Purple         #8B00FF
Brand D    Blue           #4169E1
```

### Component Sizes

```
Form:          1000 x 760 pixels
Splitter:      4px wide, dark accent
Tree width:    240px default, user-draggable
GroupBox:      Auto-height based on buttons
Buttons:       30px height, full-width inside panel
Status bar:    24px height
Header:        60px height
```

---

## 6. Panel Distribution Template

**12 panels (3 columns × 4 panels per column):**

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Panel 1 | Panel 5 | Panel 9 |
| Panel 2 | Panel 6 | Panel 10 |
| Panel 3 | Panel 7 | Panel 11 |
| Panel 4 | Panel 8 | Panel 12 |

Each panel has a title and 1-4 buttons stacked vertically.

---

## 7. Helper Functions Required

| Function | Purpose |
|----------|---------|
| `ColorFromHex` | Parse `#RRGGBB` strings to `System.Drawing.Color` |
| `Add-PanelBox` | Create a titled GroupBox with button list |
| `Find-Tools` | Scan directories for config files (if used) |
| `Center-HubItems` | Recenter header brand items on resize |

---

## 8. Implementation Checklist

- [ ] Set up form with dark theme
- [ ] Add split container
- [ ] Build left panel (folder tree with autodiscovery)
- [ ] Build right panel (3-column scrollable area)
- [ ] Add header with centered brand items
- [ ] Create Add-PanelBox function
- [ ] Populate panels with buttons
- [ ] Add status bar
- [ ] Add form icon
- [ ] Wire up all button actions
- [ ] Create VBS launcher

---

## 9. Sample Button Definitions

```powershell
# File/folder button
@{Text="Open Folder"; Color="#463728"; Desc="Browse files"; Target="C:\path\to\folder"}

# URL button
@{Text="Open Web"; Color="#325032"; Desc="Launch web UI"; Target="http://localhost:8000"; Mode="url"}

# App with arguments
@{Text="Open Editor"; Color="#2C2C32"; Desc="Open in VS Code"; Target="code"; Arguments="C:\path\to\project"}

# Disabled button (no target)
@{Text="Coming Soon"; Color="#444"; Desc="Not yet available"; Target=$null}
```

---

## 10. File Structure

```
project-root/
├── dashboard-launcher.vbs    ← double-click to start
├── Start-Dashboard.ps1       ← main PowerShell script
├── shared/                   ← shared modules (optional)
│   └── SessionModule.ps1
├── icons/                    ← .ico files for branding
│   └── app-icon.ico
└── modules/                  ← auto-discovered tools
    ├── tool-alpha/tool.json
    ├── tool-beta/tool.json
    └── ...
```

---

*Generated from MystikStudio Dashboard — use as a template for any
project that needs a modular WinForms launcher hub.*
