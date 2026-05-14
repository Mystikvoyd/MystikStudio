using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

public class StudioForm : Form {
    private TabControl tabs;
    private TabPage tabChar, tabPose, tabGen, tabCN, tabExtras;
    private TextBox txtPrompt, txtNegative, txtIdentity, txtPose, txtNotes;
    private ComboBox comboProfile, comboPreset, comboLora, comboSampler, comboScheduler, comboWorkflow;
    private ComboBox comboCheckpoint, comboDiffuser, comboCNModel, comboCNImage, comboCNFilter;
    private NumericUpDown numLoraStr, numSeed, numSteps, numCfg, numWidth, numHeight, numCNStrength, numCNStart, numCNEnd;
    private CheckBox chkLora, chkRandomSeed, chkCN, chkRealism;
    private Button btnGenerate, btnRefresh, btnOutput;
    private PictureBox previewBox;
    private DataGridView gridOutputs;
    private Panel previewPanel;

    public StudioForm() {
        this.Text = "Character Studio";
        this.Size = new Size(1400, 960);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Studio.ico";
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
        btnGenerate = NewButton("Generate", 4, 8, 90, 32, Color.FromArgb(220, 60, 30));
        btnRefresh = NewButton("Refresh Models", 98, 8, 90, 32, Color.FromArgb(50, 50, 60));
        btnOutput = NewButton("Open Output", 192, 8, 80, 32, Color.FromArgb(50, 50, 60));
        btnOutput.Click += (o, e) => { string p = @"C:\Users\Michael\Documents\ComfyUI\output"; if (Directory.Exists(p)) System.Diagnostics.Process.Start(p); };
        actionBar.Controls.Add(btnGenerate); actionBar.Controls.Add(btnRefresh); actionBar.Controls.Add(btnOutput);

        tabChar = new TabPage("Character") { Padding = new Padding(6), AutoScroll = true };
        tabPose = new TabPage("Pose & Identity") { Padding = new Padding(6) };
        tabGen = new TabPage("Generation") { Padding = new Padding(6) };
        tabCN = new TabPage("ControlNet") { Padding = new Padding(6) };
        tabExtras = new TabPage("Extras") { Padding = new Padding(6) };
        tabs.TabPages.Add(tabChar); tabs.TabPages.Add(tabPose); tabs.TabPages.Add(tabGen); tabs.TabPages.Add(tabCN); tabs.TabPages.Add(tabExtras);

        BuildCharTab();
        BuildPoseTab();
        BuildGenTab();
        BuildCNTab();
        BuildExtrasTab();

        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterWidth = 4 };
        right.Controls.Add(split);
        this.Load += (o, e) => { try { split.SplitterDistance = 560; } catch { } };

        previewPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(18, 18, 24) };
        split.Panel2.Controls.Add(previewPanel);
        previewBox = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom };
        previewPanel.Controls.Add(previewBox);

        gridOutputs = new DataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = false, ReadOnly = true, RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(200, 200, 210), BorderStyle = BorderStyle.None };
        gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path"); gridOutputs.Columns[3].Visible = false;
        gridOutputs.CellClick += (o, ev) => { if (ev.RowIndex >= 0 && gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value != null) SetPreview(gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value.ToString()); };
        split.Panel2.Controls.Add(gridOutputs);
    }

    private Button NewButton(string t, int x, int y, int w, int h, Color bg) { return new Button { Text = t, Left = x, Top = y, Width = w, Height = h, BackColor = bg, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 } }; }
    private Label Lbl(string t, int x, int y, int w = 100, int h = 18) { return new Label { Text = t, Left = x, Top = y, Width = w, Height = h }; }
    private void SetPreview(string path) { if (string.IsNullOrEmpty(path) || !File.Exists(path)) return; try { if (previewBox.Image != null) previewBox.Image.Dispose(); previewBox.Image = Image.FromFile(path); } catch { } }

    private void BuildCharTab() {
        int y = 4;
        tabChar.Controls.Add(Lbl("Character Name / Identity", 8, y));
        txtIdentity = new TextBox { Left = 8, Top = y + 18, Width = 300, Height = 24 };
        tabChar.Controls.Add(txtIdentity); y += 50;
        tabChar.Controls.Add(Lbl("Generation Prompt", 8, y));
        txtPrompt = new TextBox { Left = 8, Top = y + 18, Width = 420, Height = 60, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabChar.Controls.Add(txtPrompt); y += 90;
        tabChar.Controls.Add(Lbl("Negative Prompt", 8, y));
        txtNegative = new TextBox { Left = 8, Top = y + 18, Width = 420, Height = 50, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabChar.Controls.Add(txtNegative); y += 80;
        tabChar.Controls.Add(Lbl("LoRA", 8, y));
        comboLora = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        comboLora.Items.Add("None"); comboLora.SelectedIndex = 0;
        tabChar.Controls.Add(comboLora);
        chkLora = new CheckBox { Text = "Use", Left = 212, Top = y + 20, Width = 40, Checked = true };
        tabChar.Controls.Add(chkLora);
        numLoraStr = new NumericUpDown { Left = 260, Top = y + 18, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.8m };
        tabChar.Controls.Add(numLoraStr);
    }

    private void BuildPoseTab() {
        int y = 4;
        tabPose.Controls.Add(Lbl("Pose Description", 8, y));
        txtPose = new TextBox { Left = 8, Top = y + 18, Width = 420, Height = 60, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabPose.Controls.Add(txtPose); y += 90;
        tabPose.Controls.Add(Lbl("Identity Locking Notes", 8, y));
        txtNotes = new TextBox { Left = 8, Top = y + 18, Width = 420, Height = 60, Multiline = true, ScrollBars = ScrollBars.Vertical };
        tabPose.Controls.Add(txtNotes);
    }

    private void BuildGenTab() {
        int y = 4;
        tabGen.Controls.Add(Lbl("Seed", 8, y)); tabGen.Controls.Add(Lbl("Steps", 100, y)); tabGen.Controls.Add(Lbl("CFG", 180, y));
        tabGen.Controls.Add(Lbl("Width", 250, y)); tabGen.Controls.Add(Lbl("Height", 330, y)); y += 18;
        chkRandomSeed = new CheckBox { Text = "Rnd", Left = 8, Top = y, Width = 40, Height = 18, Checked = true };
        numSeed = new NumericUpDown { Left = 46, Top = y, Width = 50, Maximum = int.MaxValue, Minimum = 1, Value = new Random().Next(1, int.MaxValue), Enabled = false };
        chkRandomSeed.CheckedChanged += (o, e) => numSeed.Enabled = !chkRandomSeed.Checked;
        numSteps = new NumericUpDown { Left = 100, Top = y, Width = 60, Minimum = 1, Maximum = 150, Value = 30 };
        numCfg = new NumericUpDown { Left = 170, Top = y, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 7 };
        numWidth = new NumericUpDown { Left = 240, Top = y, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabGen.Controls.Add(new Label { Text = "x", Left = 312, Top = y + 2, Width = 12 });
        numHeight = new NumericUpDown { Left = 324, Top = y, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabGen.Controls.Add(chkRandomSeed); tabGen.Controls.Add(numSeed); tabGen.Controls.Add(numSteps); tabGen.Controls.Add(numCfg); tabGen.Controls.Add(numWidth); tabGen.Controls.Add(numHeight); y += 24;

        tabGen.Controls.Add(Lbl("Sampler", 8, y, 190)); tabGen.Controls.Add(Lbl("Scheduler", 212, y, 180)); y += 18;
        comboSampler = new ComboBox { Left = 8, Top = y + 18, Width = 192, DropDownStyle = ComboBoxStyle.DropDownList };
        comboSampler.Items.AddRange(new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }); comboSampler.SelectedIndex = 0;
        tabGen.Controls.Add(comboSampler);
        comboScheduler = new ComboBox { Left = 212, Top = y + 18, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList };
        comboScheduler.Items.AddRange(new[] { "karras", "exponential", "simple", "normal" }); comboScheduler.SelectedIndex = 0;
        tabGen.Controls.Add(comboScheduler); y += 44;

        tabGen.Controls.Add(Lbl("Checkpoint", 8, y));
        comboCheckpoint = new ComboBox { Left = 8, Top = y + 18, Width = 380, DropDownStyle = ComboBoxStyle.DropDownList };
        tabGen.Controls.Add(comboCheckpoint); y += 46;
        tabGen.Controls.Add(Lbl("Diffuser / Refiner", 8, y));
        comboDiffuser = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        tabGen.Controls.Add(comboDiffuser); y += 46;
        tabGen.Controls.Add(Lbl("Workflow Preset", 8, y));
        comboWorkflow = new ComboBox { Left = 8, Top = y + 18, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboWorkflow.Items.Add("Standard Studio"); comboWorkflow.SelectedIndex = 0;
        tabGen.Controls.Add(comboWorkflow); y += 46;
        chkRealism = new CheckBox { Text = "Realism Boost", Left = 8, Top = y, Width = 120, Height = 22 };
        tabGen.Controls.Add(chkRealism);
    }

    private void BuildCNTab() {
        int y = 4;
        chkCN = new CheckBox { Text = "Enable ControlNet", Left = 8, Top = y, Width = 140, Height = 22 };
        tabCN.Controls.Add(chkCN); y += 28;
        tabCN.Controls.Add(Lbl("Model", 8, y));
        comboCNModel = new ComboBox { Left = 8, Top = y + 18, Width = 250, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNModel); y += 46;
        tabCN.Controls.Add(Lbl("Input Image", 8, y));
        comboCNImage = new ComboBox { Left = 8, Top = y + 18, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNImage.Items.Add("None"); comboCNImage.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNImage); y += 46;
        tabCN.Controls.Add(Lbl("Preprocessor", 8, y));
        comboCNFilter = new ComboBox { Left = 8, Top = y + 18, Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCNFilter.Items.Add("None"); comboCNFilter.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNFilter); y += 46;
        tabCN.Controls.Add(Lbl("Strength", 8, y));
        numCNStrength = new NumericUpDown { Left = 8, Top = y + 18, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNStrength); y += 46;
        tabCN.Controls.Add(Lbl("Start / End", 8, y));
        numCNStart = new NumericUpDown { Left = 8, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m };
        tabCN.Controls.Add(numCNStart);
        tabCN.Controls.Add(new Label { Text = "to", Left = 70, Top = y + 20, Width = 20 });
        numCNEnd = new NumericUpDown { Left = 90, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNEnd);
    }

    private void BuildExtrasTab() { }
}

class Program {
    [STAThread]
    static void Main() {
        Application.EnableVisualStyles();
        Application.Run(new StudioForm());
    }
}
