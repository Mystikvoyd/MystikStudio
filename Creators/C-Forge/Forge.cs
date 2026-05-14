using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;

public class ForgeForm : Form {
    private TabControl tabs;
    private TabPage tabMain, tabModel, tabCN, tabExtras;
    private TextBox txtPrompt, txtNegative, txtOutfit, logBox;
    private ComboBox comboProfile, comboPreset, comboLora1, comboLora2, comboLora3, comboSampler, comboScheduler, comboWorkflow;
    private ComboBox comboCheckpointStyle, comboCheckpoint, comboDiffuser, comboCNModel, comboCNImage, comboCNFilter;
    private ComboBox comboOutCat, comboOutItem, comboOutColor, comboOutMat, comboOutPreset, comboOutfitPlacement;
    private NumericUpDown numLora1Str, numLora2Str, numLora3Str, numSeed, numSteps, numCfg, numWidth, numHeight, numCNStrength, numCNStart, numCNEnd;
    private CheckBox chkLora1, chkLora2, chkLora3, chkRandomSeed, chkCN, chkIncludePrompts, chkEnableOutfit, chkRealism, chkCapture;
    private Button btnGenerate, btnRefresh, btnOutput, btnSession, btnOpenReport;
    private PictureBox previewBox;
    private DataGridView gridOutputs;
    private Panel previewPanel;
    private bool sessionActive = false;
    private string configPath, prefsPath;

    public ForgeForm() {
        string forgeRoot = Path.GetDirectoryName(Application.ExecutablePath);
        configPath = Path.Combine(forgeRoot, "Forge.config.json");
        prefsPath = Path.Combine(forgeRoot, "Forge.prefs.json");

        this.Text = "Character Forge";
        this.Size = new Size(1400, 960);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Forge.ico";
        if (File.Exists(iconPath)) this.Icon = new Icon(iconPath);

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(8), ColumnCount = 1, RowCount = 2 };
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 68));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 32));
        this.Controls.Add(right);

        var left = new Panel { Dock = DockStyle.Left, Width = 620, Padding = new Padding(6) };
        this.Controls.Add(left);

        tabs = new TabControl { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 8.5f) };
        left.Controls.Add(tabs);

        var actionBar = new Panel { Dock = DockStyle.Bottom, Height = 48, BackColor = Color.FromArgb(45, 45, 52) };
        left.Controls.Add(actionBar);
        btnGenerate = MakeButton("Generate", 4, 8, 90, 32, Color.FromArgb(40, 120, 60));
        btnRefresh = MakeButton("Refresh Models", 98, 8, 90, 32, Color.FromArgb(50, 50, 60));
        btnOutput = MakeButton("Open Output", 192, 8, 80, 32, Color.FromArgb(50, 50, 60));
        btnOutput.Click += (o, e) => { string p = @"C:\Users\Michael\Documents\ComfyUI\output"; if (Directory.Exists(p)) System.Diagnostics.Process.Start(p); };
        actionBar.Controls.Add(btnGenerate); actionBar.Controls.Add(btnRefresh); actionBar.Controls.Add(btnOutput);

        tabMain = new TabPage("Composition") { Padding = new Padding(6), AutoScroll = true };
        tabModel = new TabPage("Models") { Padding = new Padding(6) };
        tabCN = new TabPage("ControlNet") { Padding = new Padding(6) };
        tabExtras = new TabPage("Extras") { Padding = new Padding(6) };
        tabs.TabPages.Add(tabMain); tabs.TabPages.Add(tabModel); tabs.TabPages.Add(tabCN); tabs.TabPages.Add(tabExtras);

        BuildCompositionTab();
        BuildModelsTab();
        BuildControlNetTab();
        BuildExtrasTab();

        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterWidth = 4 };
        right.Controls.Add(split);
        this.Load += (o, e) => { try { split.SplitterDistance = 560; } catch { } };

        previewPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(18, 18, 24) };
        split.Panel2.Controls.Add(previewPanel);
        previewBox = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom };
        previewPanel.Controls.Add(previewBox);

        gridOutputs = new DataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = false, ReadOnly = true, RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(200, 200, 210), BorderStyle = BorderStyle.None };
        gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA1", "LoRA1"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path"); gridOutputs.Columns[4].Visible = false;
        gridOutputs.CellClick += (o, ev) => { if (ev.RowIndex >= 0 && gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value != null) SetPreview(gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value.ToString()); };
        split.Panel2.Controls.Add(gridOutputs);
    }

    private Button MakeButton(string t, int x, int y, int w, int h, Color bg) { return new Button { Text = t, Left = x, Top = y, Width = w, Height = h, BackColor = bg, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 } }; }

    private void BuildCompositionTab() {
        int gy = 4;
        tabMain.Controls.Add(MakeLabel("Prompt", 8, gy));
        txtPrompt = new TextBox { Left = 8, Top = gy + 18, Width = 420, Height = 55, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabMain.Controls.Add(txtPrompt); gy += 80;
        tabMain.Controls.Add(MakeLabel("Negative prompt", 8, gy));
        txtNegative = new TextBox { Left = 8, Top = gy + 18, Width = 420, Height = 45, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabMain.Controls.Add(txtNegative); gy += 70;

        // Triple LoRA
        int lx = 8; gy += 4;
        comboLora1 = MakeCombo(lx, gy, 200); chkLora1 = new CheckBox { Text = "Use", Left = lx + 204, Top = gy + 2, Width = 40, Checked = true };
        numLora1Str = new NumericUpDown { Left = lx + 248, Top = gy, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.8m };
        tabMain.Controls.Add(MakeLabel("LoRA 1", lx, gy - 18)); tabMain.Controls.Add(comboLora1); tabMain.Controls.Add(chkLora1); tabMain.Controls.Add(numLora1Str); gy += 24;
        comboLora2 = MakeCombo(lx, gy, 200); chkLora2 = new CheckBox { Text = "Use", Left = lx + 204, Top = gy + 2, Width = 40, Checked = true };
        numLora2Str = new NumericUpDown { Left = lx + 248, Top = gy, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.8m };
        tabMain.Controls.Add(MakeLabel("LoRA 2", lx, gy - 18)); tabMain.Controls.Add(comboLora2); tabMain.Controls.Add(chkLora2); tabMain.Controls.Add(numLora2Str); gy += 24;
        comboLora3 = MakeCombo(lx, gy, 200); chkLora3 = new CheckBox { Text = "Use", Left = lx + 204, Top = gy + 2, Width = 40, Checked = true };
        numLora3Str = new NumericUpDown { Left = lx + 248, Top = gy, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.8m };
        tabMain.Controls.Add(MakeLabel("LoRA 3", lx, gy - 18)); tabMain.Controls.Add(comboLora3); tabMain.Controls.Add(chkLora3); tabMain.Controls.Add(numLora3Str); gy += 30;

        tabMain.Controls.Add(MakeLabel("Seed", 8, gy)); tabMain.Controls.Add(MakeLabel("Steps", 100, gy)); tabMain.Controls.Add(MakeLabel("CFG", 180, gy)); tabMain.Controls.Add(MakeLabel("Width", 250, gy)); tabMain.Controls.Add(MakeLabel("Height", 330, gy)); gy += 18;
        chkRandomSeed = new CheckBox { Text = "Rnd", Left = 8, Top = gy, Width = 40, Height = 18, Checked = true };
        numSeed = new NumericUpDown { Left = 46, Top = gy, Width = 50, Maximum = int.MaxValue, Minimum = 1, Value = new Random().Next(1, int.MaxValue), Enabled = false };
        chkRandomSeed.CheckedChanged += (o, e) => numSeed.Enabled = !chkRandomSeed.Checked;
        numSteps = new NumericUpDown { Left = 100, Top = gy, Width = 60, Minimum = 1, Maximum = 150, Value = 30 };
        numCfg = new NumericUpDown { Left = 170, Top = gy, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 7 };
        numWidth = new NumericUpDown { Left = 240, Top = gy, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        var lblX = new Label { Text = "x", Left = 312, Top = gy + 2, Width = 12 };
        numHeight = new NumericUpDown { Left = 324, Top = gy, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabMain.Controls.Add(chkRandomSeed); tabMain.Controls.Add(numSeed); tabMain.Controls.Add(numSteps); tabMain.Controls.Add(numCfg); tabMain.Controls.Add(numWidth); tabMain.Controls.Add(lblX); tabMain.Controls.Add(numHeight); gy += 24;

        tabMain.Controls.Add(MakeLabel("Sampler", 8, gy, 190)); tabMain.Controls.Add(MakeLabel("Scheduler", 212, gy, 180)); gy += 18;
        comboSampler = MakeCombo(8, gy + 18, 192); comboSampler.Items.AddRange(new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }); comboSampler.SelectedIndex = 0;
        comboScheduler = MakeCombo(212, gy + 18, 180); comboScheduler.Items.AddRange(new[] { "karras", "exponential", "simple", "normal" }); comboScheduler.SelectedIndex = 0;
        tabMain.Controls.Add(comboSampler); tabMain.Controls.Add(comboScheduler); gy += 44;
    }

    private void BuildModelsTab() {
        int y = 4;
        tabModel.Controls.Add(MakeLabel("Checkpoint Style", 8, y));
        comboCheckpointStyle = MakeCombo(8, y + 18, 200); comboCheckpointStyle.Items.Add("All"); comboCheckpointStyle.SelectedIndex = 0;
        tabModel.Controls.Add(comboCheckpointStyle); y += 46;
        tabModel.Controls.Add(MakeLabel("Checkpoint", 8, y));
        comboCheckpoint = MakeCombo(8, y + 18, 380); tabModel.Controls.Add(comboCheckpoint); y += 46;
        tabModel.Controls.Add(MakeLabel("Diffuser / Refiner", 8, y));
        comboDiffuser = MakeCombo(8, y + 18, 200); tabModel.Controls.Add(comboDiffuser); y += 46;
        tabModel.Controls.Add(MakeLabel("Workflow Preset", 8, y));
        comboWorkflow = MakeCombo(8, y + 18, 300); comboWorkflow.Items.Add("Standard Forge"); comboWorkflow.SelectedIndex = 0;
        tabModel.Controls.Add(comboWorkflow); y += 46;
        chkRealism = new CheckBox { Text = "Realism Boost", Left = 8, Top = y, Width = 120, Height = 22 };
        tabModel.Controls.Add(chkRealism);
    }

    private void BuildControlNetTab() {
        int y = 4;
        chkCN = new CheckBox { Text = "Enable ControlNet", Left = 8, Top = y, Width = 140, Height = 22 };
        tabCN.Controls.Add(chkCN); y += 28;
        tabCN.Controls.Add(MakeLabel("Model", 8, y));
        comboCNModel = MakeCombo(8, y + 18, 250); comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNModel); y += 46;
        tabCN.Controls.Add(MakeLabel("Input Image", 8, y));
        comboCNImage = MakeCombo(8, y + 18, 300); comboCNImage.Items.Add("None"); comboCNImage.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNImage); y += 46;
        tabCN.Controls.Add(MakeLabel("Preprocessor", 8, y));
        comboCNFilter = MakeCombo(8, y + 18, 200); comboCNFilter.Items.Add("None"); comboCNFilter.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNFilter); y += 46;
        tabCN.Controls.Add(MakeLabel("Strength", 8, y));
        numCNStrength = new NumericUpDown { Left = 8, Top = y + 18, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNStrength); y += 46;
        tabCN.Controls.Add(MakeLabel("Start / End", 8, y));
        numCNStart = new NumericUpDown { Left = 8, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m };
        tabCN.Controls.Add(numCNStart);
        tabCN.Controls.Add(new Label { Text = "to", Left = 70, Top = y + 20, Width = 20 });
        numCNEnd = new NumericUpDown { Left = 90, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNEnd);
    }

    private void BuildExtrasTab() {
        chkCapture = new CheckBox { Text = "Capture prompt variations", Left = 8, Top = 4, Width = 200, Height = 22 };
        tabExtras.Controls.Add(chkCapture);
    }

    private ComboBox MakeCombo(int x, int y, int w) { return new ComboBox { Left = x, Top = y, Width = w, DropDownStyle = ComboBoxStyle.DropDownList }; }
    private Label MakeLabel(string t, int x, int y, int w = 100, int h = 18) { return new Label { Text = t, Left = x, Top = y, Width = w, Height = h }; }

    private void SetPreview(string path) {
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;
        try { if (previewBox.Image != null) previewBox.Image.Dispose(); previewBox.Image = Image.FromFile(path); } catch { }
    }
}

class Program {
    [STAThread]
    static void Main() {
        Application.EnableVisualStyles();
        Application.Run(new ForgeForm());
    }
}
