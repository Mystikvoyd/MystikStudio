using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Windows.Forms;

public class LabForm : Form {
    private TabControl tabs;
    private TabPage tabMain, tabModel, tabCN, tabExtras;
    private TextBox txtPrompt, txtNegative, txtOutfit, txtVarNotes, logBox;
    private ComboBox comboProfile, comboPreset, comboLora, comboSampler, comboScheduler, comboWorkflow;
    private ComboBox comboCkptStyle, comboCkpt, comboDiffuser, comboCNModel, comboCNImage, comboCNFilter;
    private ComboBox comboOutCat, comboOutItem, comboOutColor, comboOutMat, comboOutPreset, comboOutfitPlacement;
    private ComboBox comboCheckpointStyle, comboCheckpoint;
    private NumericUpDown numLora, numSeed, numSteps, numCfg, numWidth, numHeight, numCNStrength, numCNStart, numCNEnd;
    private CheckBox chkLora, chkRandomSeed, chkCN, chkIncludePrompts, chkEnableOutfit, chkRealism, chkCapture;
    private Button btnGenerate, btnRefresh, btnOutput, btnSession, btnOpenReport;
    private PictureBox previewBox;
    private DataGridView gridOutputs;
    private Panel previewPanel;
    private bool sessionActive = false;
    private List<Dictionary<string, object>> sessionEntries = new List<Dictionary<string, object>>();
    private string configPath, prefsPath, runLogPath, reportsFolder;
    private Label lblGpuStatus;
    private Timer gpuTimer;

    public LabForm() {
        string labRoot = Path.GetDirectoryName(Application.ExecutablePath);
        string projectRoot = Path.GetFullPath(Path.Combine(labRoot, ".."));
        configPath = Path.Combine(labRoot, "Lab.config.json");
        prefsPath = Path.Combine(labRoot, "Lab.prefs.json");
        runLogPath = Path.Combine(labRoot, "Lab.runlog.json");
        reportsFolder = @"C:\Users\Michael\Documents\ComfyUI\Reports";
        Directory.CreateDirectory(reportsFolder);

        this.Text = "LoRA Lab";
        this.Size = new Size(1320, 920);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Lab.ico";
        if (File.Exists(iconPath)) this.Icon = new Icon(iconPath);

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(8), ColumnCount = 1, RowCount = 2 };
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 68));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 32));
        this.Controls.Add(right);

        var left = new Panel { Dock = DockStyle.Left, Width = 580, Padding = new Padding(6) };
        this.Controls.Add(left);

        tabs = new TabControl { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 8.5f) };
        left.Controls.Add(tabs);

        var actionBar = new Panel { Dock = DockStyle.Bottom, Height = 48, BackColor = Color.FromArgb(45, 45, 52) };
        left.Controls.Add(actionBar);

        btnGenerate = CreateButton("Generate", 4, 8, 90, 32, Color.FromArgb(40, 120, 60), Color.White, new Font("Segoe UI", 9, FontStyle.Bold));
        btnGenerate.Click += (o, e) => OnGenerate();
        actionBar.Controls.Add(btnGenerate);

        btnRefresh = CreateButton("Refresh LoRAs", 98, 8, 90, 32, Color.FromArgb(50, 50, 60), Color.White, new Font("Segoe UI", 7.5f));
        btnRefresh.Click += (o, e) => LoadLoraItems();
        actionBar.Controls.Add(btnRefresh);

        btnOutput = CreateButton("Open Output", 192, 8, 80, 32, Color.FromArgb(50, 50, 60), Color.White, new Font("Segoe UI", 7.5f));
        btnOutput.Click += (o, e) => OpenOutput();
        actionBar.Controls.Add(btnOutput);

        btnSession = CreateButton("[ START SESSION ]", 276, 8, 86, 32, Color.FromArgb(34, 120, 64), Color.White, new Font("Segoe UI", 8, FontStyle.Bold));
        btnSession.Click += (o, e) => ToggleSession();
        actionBar.Controls.Add(btnSession);

        btnOpenReport = CreateButton("Reports", 366, 8, 56, 32, Color.FromArgb(50, 50, 60), Color.FromArgb(200, 200, 210), new Font("Segoe UI", 8));
        btnOpenReport.FlatStyle = FlatStyle.Flat;
        actionBar.Controls.Add(btnOpenReport);

        chkIncludePrompts = new CheckBox { Text = "Include prompts in session report", Left = 426, Top = 10, Width = 150, Height = 22, ForeColor = Color.FromArgb(200, 200, 210), Font = new Font("Segoe UI", 7.5f) };
        actionBar.Controls.Add(chkIncludePrompts);

        tabMain = new TabPage("Generation") { Padding = new Padding(6), AutoScroll = true };
        tabModel = new TabPage("Models") { Padding = new Padding(6) };
        tabCN = new TabPage("ControlNet") { Padding = new Padding(6) };
        tabExtras = new TabPage("Extras") { Padding = new Padding(6) };
        tabs.TabPages.Add(tabMain);
        tabs.TabPages.Add(tabModel);
        tabs.TabPages.Add(tabCN);
        tabs.TabPages.Add(tabExtras);

        BuildGenerationTab();
        BuildModelsTab();
        BuildControlNetTab();
        BuildExtrasTab();

        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterWidth = 4 };
        right.Controls.Add(split);

        previewPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(18, 18, 24) };
        split.Panel2.Controls.Add(previewPanel);

        previewBox = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom };
        previewPanel.Controls.Add(previewBox);

        var bottomPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(22, 22, 30) };
        split.Panel2.Controls.Add(bottomPanel);

        gridOutputs = new DataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = false, ReadOnly = true, RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(200, 200, 210), BorderStyle = BorderStyle.None };
        gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA", "LoRA"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path"); gridOutputs.Columns[4].Visible = false;
        gridOutputs.CellClick += (o, e) => { if (e.RowIndex >= 0 && gridOutputs.Rows[e.RowIndex].Cells["Path"].Value != null) SetPreview(gridOutputs.Rows[e.RowIndex].Cells["Path"].Value.ToString()); };
        this.Load += (o, e) => { try { split.Panel1MinSize = 300; split.Panel2MinSize = 200; split.SplitterDistance = 520; } catch { } };
        bottomPanel.Controls.Add(gridOutputs);

        // GPU status bar
        lblGpuStatus = new Label { Dock = DockStyle.Bottom, Height = 22, BackColor = Color.FromArgb(28, 28, 38), ForeColor = Color.FromArgb(150, 200, 150), Font = new Font("Segoe UI", 7.5f), Padding = new Padding(8, 3, 0, 0) };
        this.Controls.Add(lblGpuStatus);
        lblGpuStatus.BringToFront();
        string logsDir = Path.Combine(labRoot, "logs"); Directory.CreateDirectory(logsDir);
        GpuStatusProvider.SetLogDir(logsDir);
        UpdateGpuBar();
        gpuTimer = new Timer { Interval = 5000 }; gpuTimer.Tick += (o, e) => UpdateGpuBar(); gpuTimer.Start();

        LoadPrefs();
        LoadLoraItems();
    }

    private void UpdateGpuBar() {
        try {
            var info = GpuStatusProvider.Refresh();
            if (lblGpuStatus != null && !lblGpuStatus.IsDisposed) {
                string comfyStr = info.ComfyUiOnline ? "Online" : "Offline";
                lblGpuStatus.Text = "GPU: " + info.Name + "  |  VRAM: " + (info.DedicatedUsed > 0 ? (info.DedicatedUsed / (1024.0 * 1024.0 * 1024.0)).ToString("0.0") + " / " : "? / ") + (info.DedicatedTotal > 0 ? (info.DedicatedTotal / (1024.0 * 1024.0 * 1024.0)).ToString("0.0") + " GB" : "?") + "  |  ComfyUI: " + comfyStr;
                lblGpuStatus.ForeColor = info.ComfyUiOnline ? Color.FromArgb(150, 200, 150) : Color.FromArgb(200, 150, 150);
            }
        } catch { }
    }

    private Button CreateButton(string text, int x, int y, int w, int h, Color bg, Color fg, Font font) {
        return new Button { Text = text, Left = x, Top = y, Width = w, Height = h, BackColor = bg, ForeColor = fg, Font = font, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 } };
    }

    private Label MakeLabel(string text, int x, int y, int w = 200, int h = 18) {
        return new Label { Text = text, Left = x, Top = y, Width = w, Height = h };
    }

    private void BuildGenerationTab() {
        int gy = 4;
        tabMain.Controls.Add(MakeLabel("Prompt", 8, gy));
        txtPrompt = new TextBox { Left = 8, Top = gy + 18, Width = 392, Height = 55, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = "" };
        tabMain.Controls.Add(txtPrompt); gy += 80;

        tabMain.Controls.Add(MakeLabel("Negative prompt", 8, gy));
        txtNegative = new TextBox { Left = 8, Top = gy + 18, Width = 392, Height = 45, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = "" };
        tabMain.Controls.Add(txtNegative); gy += 70;

        tabMain.Controls.Add(MakeLabel("LoRA", 8, gy));
        comboLora = new ComboBox { Left = 8, Top = gy + 18, Width = 220, DropDownStyle = ComboBoxStyle.DropDownList };
        comboLora.Items.Add("None"); comboLora.SelectedIndex = 0;
        tabMain.Controls.Add(comboLora);
        chkLora = new CheckBox { Text = "Use", Left = 236, Top = gy + 20, Width = 50, Checked = true };
        tabMain.Controls.Add(chkLora);
        numLora = new NumericUpDown { Left = 286, Top = gy + 18, Width = 76, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.8m };
        tabMain.Controls.Add(numLora); gy += 46;

        var labels = new[] { "Seed", "Steps", "CFG", "Width", "Height" };
        int[] lxs = { 8, 100, 180, 250, 330 };
        for (int i = 0; i < labels.Length; i++) tabMain.Controls.Add(MakeLabel(labels[i], lxs[i], gy, 60)); gy += 18;

        chkRandomSeed = new CheckBox { Text = "Rnd", Left = 8, Top = gy, Width = 40, Height = 18, Checked = true };
        tabMain.Controls.Add(chkRandomSeed);
        numSeed = new NumericUpDown { Left = 46, Top = gy, Width = 50, Maximum = int.MaxValue, Minimum = 1, Value = new Random().Next(1, int.MaxValue), Enabled = false };
        chkRandomSeed.CheckedChanged += (o, e) => numSeed.Enabled = !chkRandomSeed.Checked;
        tabMain.Controls.Add(numSeed);
        numSteps = new NumericUpDown { Left = 100, Top = gy, Width = 60, Minimum = 1, Maximum = 150, Value = 30 };
        tabMain.Controls.Add(numSteps);
        numCfg = new NumericUpDown { Left = 170, Top = gy, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 7 };
        tabMain.Controls.Add(numCfg);
        numWidth = new NumericUpDown { Left = 240, Top = gy, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabMain.Controls.Add(numWidth);
        var lblX = new Label { Text = "x", Left = 312, Top = gy + 2, Width = 12 };
        tabMain.Controls.Add(lblX);
        numHeight = new NumericUpDown { Left = 324, Top = gy, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabMain.Controls.Add(numHeight); gy += 24;

        tabMain.Controls.Add(MakeLabel("Sampler", 8, gy, 190));
        tabMain.Controls.Add(MakeLabel("Scheduler", 212, gy, 180)); gy += 18;
        comboSampler = new ComboBox { Left = 8, Top = gy + 18, Width = 192, DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (var s in new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }) comboSampler.Items.Add(s);
        comboSampler.SelectedIndex = 0; tabMain.Controls.Add(comboSampler);
        comboScheduler = new ComboBox { Left = 212, Top = gy + 18, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (var s in new[] { "karras", "exponential", "simple", "normal" }) comboScheduler.Items.Add(s);
        comboScheduler.SelectedIndex = 0; tabMain.Controls.Add(comboScheduler); gy += 44;

        tabMain.Controls.Add(MakeLabel("Profile", 8, gy, 50));
        tabMain.Controls.Add(MakeLabel("Prompt Preset", 220, gy, 100)); gy += 18;
        comboProfile = new ComboBox { Left = 8, Top = gy, Width = 140, DropDownStyle = ComboBoxStyle.DropDownList };
        comboProfile.Items.Add("Default"); comboProfile.SelectedIndex = 0;
        tabMain.Controls.Add(comboProfile);
        comboPreset = new ComboBox { Left = 216, Top = gy, Width = 110, DropDownStyle = ComboBoxStyle.DropDownList };
        comboPreset.Items.Add("None"); comboPreset.SelectedIndex = 0;
        tabMain.Controls.Add(comboPreset); gy += 46;

        var outfitBox = new GroupBox { Text = "Outfit", Left = 6, Top = gy, Width = 405, Height = 160, Font = new Font("Segoe UI", 8.5f, FontStyle.Bold) };
        tabMain.Controls.Add(outfitBox);
        gy = 20;
        outfitBox.Controls.Add(MakeLabel("Category", 8, gy, 60, 16).WithFont(7.5f));
        outfitBox.Controls.Add(MakeLabel("Item", 200, gy, 60, 16).WithFont(7.5f)); gy += 16;
        comboOutCat = new ComboBox { Left = 8, Top = gy, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutCat.Items.Add("-- All --"); comboOutCat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutCat);
        comboOutItem = new ComboBox { Left = 200, Top = gy, Width = 190, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8), Enabled = false };
        outfitBox.Controls.Add(comboOutItem); gy += 24;
        outfitBox.Controls.Add(MakeLabel("Color", 8, gy, 60, 16).WithFont(7.5f));
        outfitBox.Controls.Add(MakeLabel("Material", 200, gy, 60, 16).WithFont(7.5f)); gy += 16;
        comboOutColor = new ComboBox { Left = 8, Top = gy, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutColor.Items.Add("-- None --"); comboOutColor.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutColor);
        comboOutMat = new ComboBox { Left = 200, Top = gy, Width = 190, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutMat.Items.Add("-- None --"); comboOutMat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutMat); gy += 24;
        chkEnableOutfit = new CheckBox { Text = "Enable Outfit", Left = 8, Top = gy, Width = 90, Height = 18, Font = new Font("Segoe UI", 7.5f) };
        outfitBox.Controls.Add(chkEnableOutfit);
        comboOutfitPlacement = new ComboBox { Left = 100, Top = gy - 1, Width = 130, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 7.5f) };
        comboOutfitPlacement.Items.Add("Append"); comboOutfitPlacement.Items.Add("Prepend"); comboOutfitPlacement.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutfitPlacement); gy += 22;
        txtOutfit = new TextBox { Left = 8, Top = gy, Width = 382, Height = 22, Font = new Font("Segoe UI", 8), ReadOnly = true };
        outfitBox.Controls.Add(txtOutfit);
    }

    private void BuildModelsTab() {
        int y = 4;
        tabModel.Controls.Add(MakeLabel("Checkpoint Style", 8, y));
        comboCheckpointStyle = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCheckpointStyle.Items.Add("All"); comboCheckpointStyle.SelectedIndex = 0;
        tabModel.Controls.Add(comboCheckpointStyle);
        y += 46;
        tabModel.Controls.Add(MakeLabel("Checkpoint", 8, y));
        comboCheckpoint = new ComboBox { Left = 8, Top = y + 18, Width = 380, DropDownStyle = ComboBoxStyle.DropDownList };
        tabModel.Controls.Add(comboCheckpoint);
        y += 46;
        tabModel.Controls.Add(MakeLabel("Diffuser / Refiner", 8, y));
        comboDiffuser = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        tabModel.Controls.Add(comboDiffuser);
        y += 46;
        tabModel.Controls.Add(MakeLabel("Workflow Preset", 8, y));
        comboWorkflow = new ComboBox { Left = 8, Top = y + 18, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboWorkflow.Items.Add("Standard LoRA Test"); comboWorkflow.SelectedIndex = 0;
        tabModel.Controls.Add(comboWorkflow);
        y += 46;
        chkRealism = new CheckBox { Text = "Realism Boost", Left = 8, Top = y, Width = 120, Height = 22 };
        tabModel.Controls.Add(chkRealism);
    }

    private void BuildControlNetTab() {
        int y = 4;
        chkCN = new CheckBox { Text = "Enable ControlNet", Left = 8, Top = y, Width = 140, Height = 22 };
        tabCN.Controls.Add(chkCN); y += 28;
        tabCN.Controls.Add(MakeLabel("Model", 8, y));
        comboCNModel = new ComboBox { Left = 8, Top = y + 18, Width = 250, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNModel); y += 46;
        tabCN.Controls.Add(MakeLabel("Input Image", 8, y));
        comboCNImage = new ComboBox { Left = 8, Top = y + 18, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNImage.Items.Add("None"); comboCNImage.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNImage); y += 46;
        tabCN.Controls.Add(MakeLabel("Preprocessor / Filter", 8, y));
        comboCNFilter = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNFilter.Items.Add("None"); comboCNFilter.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNFilter); y += 46;
        tabCN.Controls.Add(MakeLabel("Strength", 8, y));
        numCNStrength = new NumericUpDown { Left = 8, Top = y + 18, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNStrength); y += 46;
        tabCN.Controls.Add(MakeLabel("Start / End", 8, y));
        numCNStart = new NumericUpDown { Left = 8, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 0 };
        tabCN.Controls.Add(numCNStart);
        var lblTo = new Label { Text = "to", Left = 70, Top = y + 20, Width = 20 };
        tabCN.Controls.Add(lblTo);
        numCNEnd = new NumericUpDown { Left = 90, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNEnd);
    }

    private void BuildExtrasTab() {
        int y = 4;
        chkCapture = new CheckBox { Text = "Capture prompt variations", Left = 8, Top = y, Width = 200, Height = 22 };
        tabExtras.Controls.Add(chkCapture); y += 28;
        tabExtras.Controls.Add(MakeLabel("Variation notes", 8, y));
        txtVarNotes = new TextBox { Left = 8, Top = y + 18, Width = 380, Height = 60, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabExtras.Controls.Add(txtVarNotes);
        y += 90;
        comboWorkflow = new ComboBox { Left = 8, Top = y, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboWorkflow.Items.Add("Standard LoRA Test"); comboWorkflow.SelectedIndex = 0;
        tabExtras.Controls.Add(MakeLabel("Workflow Preset", 8, y - 20));
        tabExtras.Controls.Add(comboWorkflow);
    }

    private void OpenOutput() {
        string outputPath = @"C:\Users\Michael\Documents\ComfyUI\output";
        if (Directory.Exists(outputPath)) System.Diagnostics.Process.Start(outputPath);
    }

    private void SetPreview(string path) {
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;
        try { if (previewBox.Image != null) previewBox.Image.Dispose(); previewBox.Image = Image.FromFile(path); } catch { }
    }

    private void LoadLoraItems() {
        string loraRoot = @"C:\Users\Michael\Documents\ComfyUI\models\loras";
        comboLora.Items.Clear(); comboLora.Items.Add("None");
        if (Directory.Exists(loraRoot)) {
            foreach (var f in Directory.GetFiles(loraRoot, "*.safetensors", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(loraRoot, "*.ckpt", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(loraRoot, "*.pt", SearchOption.AllDirectories))
                .OrderBy(f => f)) {
                string root = loraRoot.EndsWith("\\") ? loraRoot : loraRoot + "\\";
                comboLora.Items.Add(f.Substring(root.Length));
            }
        }
        comboLora.SelectedIndex = 0;
    }

    private void LoadPrefs() { }
    private void SavePrefs() { }
    private void ToggleSession() {
        sessionActive = !sessionActive;
        btnSession.Text = sessionActive ? "[ STOP SESSION ]" : "[ START SESSION ]";
        btnSession.BackColor = sessionActive ? Color.FromArgb(180, 40, 40) : Color.FromArgb(34, 120, 64);
    }
    private void OnGenerate() { }
}

static class LabelExtensions {
    public static Label WithFont(this Label lbl, float size) { lbl.Font = new Font("Segoe UI", size); return lbl; }
}

class Program {
    [STAThread]
    static void Main() {
        Application.EnableVisualStyles();
        Application.Run(new LabForm());
    }
}
