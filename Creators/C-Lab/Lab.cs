using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public class LabForm : Form {
    private TabControl tabs;
    private TabPage tabMain, tabModel, tabCN, tabExtras;
    private TextBox txtPrompt, txtNegative, txtOutfit, txtVarNotes, logBox;
    private ComboBox comboProfile, comboPreset, comboLora, comboSampler, comboScheduler, comboWorkflow;
    private ComboBox comboCkptStyle, comboCkpt, comboDiffuser, comboCNModel, comboCNImage, comboCNFilter;
    private ComboBox comboOutCat, comboOutItem, comboOutColor, comboOutMat, comboOutPreset, comboOutfitPlacement;
    private ComboBox comboCheckpointStyle, comboCheckpoint, comboModelSource;
    private NumericUpDown numLora, numSteps, numCfg, numWidth, numHeight, numCNStrength, numCNStart, numCNEnd;
    private TextBox txtSeed;
    private CheckBox chkLora, chkRandomSeed, chkCN, chkIncludePrompts, chkEnableOutfit, chkRealism, chkCapture;
    private Button btnGenerate, btnRefresh, btnOutput, btnSession, btnOpenReport;
    private PictureBox previewBox;
    private PictureBox cnPreviewBox;
    private DataGridView gridOutputs;
    private Panel previewPanel;
    private bool sessionActive = false;
    private List<Dictionary<string, object>> sessionEntries = new List<Dictionary<string, object>>();
    private string configPath, prefsPath, runLogPath, reportsFolder, defaultConfigPath;
    private Label lblGpuStatus;
    private Timer gpuTimer;
    private System.Diagnostics.Process labWorkerProcess;
    private System.ComponentModel.BackgroundWorker statusWorker;
    private List<string> cachedCheckpoints;
    private List<string> cachedDiffusionModels;
    private List<string> cachedLoras;
    private List<string> cachedControlNets;
    private List<string> cachedCheckpointSubfolders;
    private List<string> cachedDiffusionSubfolders;
    private Dictionary<string, List<string>> cachedCheckpointsByFolder;
    private Dictionary<string, List<string>> cachedDiffusionByFolder;
    private ProgressBar progressBar;
    private Label lblProgressStatus;
    private string cnImagePath = "";
    private string detectedModelRoot = "";
    private List<string> outfitCategories = new List<string>();
    private Dictionary<string, List<string>> outfitItemsByCat = new Dictionary<string, List<string>>();
    private List<string> outfitColors = new List<string>();
    private List<string> outfitMaterials = new List<string>();
    private List<string> outfitPresets = new List<string>();
    private JavaScriptSerializer json = new JavaScriptSerializer();

    public LabForm() {
        string labRoot = Path.GetDirectoryName(Application.ExecutablePath);
        string projectRoot = Path.GetFullPath(Path.Combine(labRoot, ".."));
        configPath = Path.Combine(labRoot, "Lab.config.json");
        prefsPath = Path.Combine(labRoot, "Lab.prefs.json");
        runLogPath = Path.Combine(labRoot, "Lab.runlog.json");
        defaultConfigPath = Path.Combine(labRoot, "Lab.default.json");
        reportsFolder = @"C:\Users\Michael\Documents\ComfyUI\Reports";
        Directory.CreateDirectory(reportsFolder);

        this.WindowState = FormWindowState.Maximized;
        this.Text = "Mystikvoyd Studios - Lab";

        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Lab.ico";
        if (File.Exists(iconPath)) this.Icon = new Icon(iconPath);

        // Root 3-column layout: left (tabs+cmd) | middle (preview+output) | right (models+controlnet)
        var rootGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 1 };
        rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 580));
        rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 420));
        this.Controls.Add(rootGrid);

        var left = new Panel { Dock = DockStyle.Fill, Padding = new Padding(6) };
        rootGrid.Controls.Add(left, 0, 0);

        tabs = new TabControl { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 8.5f) };
        left.Controls.Add(tabs);

        // Fusion-style 3x2 command panel
        var cmdPanel = new Panel { Dock = DockStyle.Bottom, Height = 230, BackColor = Color.FromArgb(32, 32, 40) };
        left.Controls.Add(cmdPanel);
        var cmdGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 2, Padding = new Padding(2) };
        cmdGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33f));
        cmdGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33f));
        cmdGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33f));
        cmdGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
        cmdGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
        cmdPanel.Controls.Add(cmdGrid);

        var gbRun = CmdCell(cmdGrid, 0, 0, "Run");
        progressBar = new ProgressBar { Left = 4, Top = 0, Width = gbRun.Width - 8, Height = 10, Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top, Style = ProgressBarStyle.Continuous, Minimum = 0, Maximum = 100, Value = 0 };
        if (gbRun.Width < 50) progressBar.Width = 120;
        gbRun.Controls.Add(progressBar);
        lblProgressStatus = new Label { Left = 4, Top = 10, Width = gbRun.Width - 8, Height = 14, Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top, ForeColor = Color.FromArgb(180, 200, 180), Font = new Font("Segoe UI", 6.5f), Text = "" };
        if (gbRun.Width < 50) lblProgressStatus.Width = 120;
        gbRun.Controls.Add(lblProgressStatus);
        btnGenerate = CmdBtn(gbRun, "GENERATE", 14, Color.FromArgb(40, 120, 60), FontStyle.Bold);
        // Move progress bar below Generate
        progressBar.Top = 44; lblProgressStatus.Top = 56;
        btnGenerate.Click += (o, e) => OnGenerate();

        var gbSess = CmdCell(cmdGrid, 1, 0, "Session");
        btnSession = CmdBtn(gbSess, "Start Session", 14, null, FontStyle.Regular);
        btnSession.Click += (o, e) => ToggleSession();
        chkCapture = new CheckBox { Text = "Collect Prompt", Left = 4, Top = 52, Width = cmdGrid.Width / 3 - 8, Height = 20, ForeColor = Color.FromArgb(200, 200, 210), Font = new Font("Segoe UI", 7) };
        if (cmdGrid.Width < 150) chkCapture.Width = 120;
        gbSess.Controls.Add(chkCapture);

        var gbFiles = CmdCell(cmdGrid, 2, 0, "Files");
        btnOutput = CmdBtn(gbFiles, "Output", 14, null, FontStyle.Regular);
        btnOutput.Click += (o, e) => OpenOutput();

        var gbConfig = CmdCell(cmdGrid, 0, 1, "Config");
        var btnSaveCfg = CmdBtn(gbConfig, "Save Config", 14, null, FontStyle.Regular);
        btnSaveCfg.Click += (o, e) => SaveConfigDialog();
        var btnLoadCfg = CmdBtn(gbConfig, "Load Config", 44, null, FontStyle.Regular);
        btnLoadCfg.Click += (o, e) => LoadConfigDialog();
        var btnSaveClose = CmdBtn(gbConfig, "Save && Close", 74, Color.FromArgb(40, 80, 40), FontStyle.Regular);
        btnSaveClose.Click += (o, e) => { SaveDefaultConfig(); Application.Exit(); };
        var gbReports = CmdCell(cmdGrid, 1, 1, "Reports");
        btnOpenReport = CmdBtn(gbReports, "Reports", 14, null, FontStyle.Regular);
        btnOpenReport.Click += (o, e) => { if (Directory.Exists(reportsFolder)) System.Diagnostics.Process.Start(reportsFolder); };

        var gbTools = CmdCell(cmdGrid, 2, 1, "Tools");
        btnRefresh = CmdBtn(gbTools, "Refresh", 14, null, FontStyle.Regular);
        btnRefresh.Click += (o, e) => LoadLoraItems();

        tabMain = new TabPage("Generation") { Padding = new Padding(6), AutoScroll = true };
        tabExtras = new TabPage("Info") { Padding = new Padding(6) };
        var tabResources = new TabPage("Resources") { Padding = new Padding(6), AutoScroll = true };
        tabs.TabPages.Add(tabMain);
        tabs.TabPages.Add(tabExtras);
        tabs.TabPages.Add(tabResources);
        BuildResourcesTab(tabResources);

        BuildGenerationTab();
        LoadOutfitData();
        WireOutfitEvents();
        BuildExtrasTab();

        // Middle column: preview fills above, output history anchored at bottom
        var middleGrid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
        middleGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        middleGrid.RowStyles.Add(new RowStyle(SizeType.Absolute, 200));
        rootGrid.Controls.Add(middleGrid, 1, 0);

        previewPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(18, 18, 24) };
        previewBox = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom };
        previewPanel.Controls.Add(previewBox);
        middleGrid.Controls.Add(previewPanel, 0, 0);

        var bottomPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(22, 22, 30) };
        middleGrid.Controls.Add(bottomPanel, 0, 1);
        gridOutputs = new DataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = false, ReadOnly = true, RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(200, 200, 210), BorderStyle = BorderStyle.None };
        gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA", "LoRA"); gridOutputs.Columns.Add("LoraStr", "LoRA Str"); gridOutputs.Columns.Add("Steps", "Steps"); gridOutputs.Columns.Add("CFG", "CFG"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path"); gridOutputs.Columns[7].Visible = false;
        gridOutputs.Columns["Seed"].DefaultCellStyle.ForeColor = Color.FromArgb(100, 180, 255);
        gridOutputs.Columns["Seed"].DefaultCellStyle.Font = new Font("Segoe UI", 8, FontStyle.Underline);
        gridOutputs.Columns["Seed"].ToolTipText = "Click to copy seed to clipboard";
        gridOutputs.CellClick += (o, e) => {
            if (e.RowIndex >= 0) {
                var row = gridOutputs.Rows[e.RowIndex];
                string colName = gridOutputs.Columns[e.ColumnIndex].Name;
                if (colName == "Seed" && row.Cells["Seed"].Value != null) {
                    try { Clipboard.SetText(row.Cells["Seed"].Value.ToString()); Log("Seed copied from history: " + row.Cells["Seed"].Value); } catch { }
                }
                // Load row image into preview if available
                if (row.Cells["Path"].Value != null) {
                    string imgPath = row.Cells["Path"].Value.ToString();
                    if (File.Exists(imgPath)) {
                        SetPreview(imgPath);
                        // Restore metadata from this row
                        if (row.Cells["Seed"].Value != null) txtSeed.Text = row.Cells["Seed"].Value.ToString();
                        if (row.Cells["Steps"].Value != null) { int sv; if (int.TryParse(row.Cells["Steps"].Value.ToString(), out sv)) numSteps.Value = sv; }
                        if (row.Cells["CFG"].Value != null) { decimal cv; if (decimal.TryParse(row.Cells["CFG"].Value.ToString(), out cv)) numCfg.Value = cv; }
                        Log("Loaded history: " + Path.GetFileName(imgPath));
                    } else {
                        Log("Image file not found: " + imgPath);
                    }
                }
            }
        };
        bottomPanel.Controls.Add(gridOutputs);

        // Right column: stacked tool panels
        var rp = new Panel { Dock = DockStyle.Fill, AutoScroll = true, BackColor = Color.FromArgb(28, 28, 38) };
        rootGrid.Controls.Add(rp, 2, 0);
        int ry = 6; int rw = 408;
        var mdBox = new GroupBox { Text = "Models", Left = 4, Top = ry, Width = rw, Height = 106, Font = new Font("Segoe UI", 8, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        rp.Controls.Add(mdBox);
        mdBox.Controls.Add(new Label { Text = "Model Source", Left = 6, Top = 14, Width = 80, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        comboModelSource = new ComboBox { Left = 6, Top = 30, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList };
        comboModelSource.Items.Add("Checkpoints"); comboModelSource.Items.Add("Diffusion Models"); comboModelSource.SelectedIndex = 0;
        comboModelSource.SelectedIndexChanged += (o, e) => { FilterLabCheckpoints(); PopulateLabTypeStyle(); };
        mdBox.Controls.Add(comboModelSource);
        mdBox.Controls.Add(new Label { Text = "Type / Style", Left = 194, Top = 14, Width = 80, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        comboCheckpointStyle = new ComboBox { Left = 194, Top = 30, Width = 206, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCheckpointStyle.Items.Add("All"); comboCheckpointStyle.SelectedIndex = 0;
        comboCheckpointStyle.SelectedIndexChanged += (o, e) => FilterLabCheckpoints();
        mdBox.Controls.Add(comboCheckpointStyle);
        mdBox.Controls.Add(new Label { Text = "Checkpoint / Model", Left = 6, Top = 56, Width = 110, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        comboCheckpoint = new ComboBox { Left = 6, Top = 74, Width = 394, DropDownStyle = ComboBoxStyle.DropDownList };
        comboCheckpoint.Items.Add("None"); comboCheckpoint.SelectedIndex = 0;
        mdBox.Controls.Add(comboCheckpoint);
        ry += 112;

        var cnBox = new GroupBox { Text = "ControlNet", Left = 4, Top = ry, Width = rw, Height = 240, Font = new Font("Segoe UI", 8, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        rp.Controls.Add(cnBox); int cny = 20;
        chkCN = new CheckBox { Text = "Enable", Left = 6, Top = cny, Width = 80, Height = 20, ForeColor = Color.FromArgb(200, 200, 210) };
        cnBox.Controls.Add(chkCN); cny += 24;
        cnBox.Controls.Add(new Label { Text = "Model", Left = 6, Top = cny, Width = 60, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        comboCNModel = new ComboBox { Left = 6, Top = cny + 16, Width = 392, DropDownStyle = ComboBoxStyle.DropDownList }; comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        cnBox.Controls.Add(comboCNModel); cny += 40;
        cnBox.Controls.Add(new Label { Text = "Image", Left = 6, Top = cny, Width = 60, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        var btnBrowseCN = new Button { Text = "Browse...", Left = 6, Top = cny + 16, Width = 72, Height = 22, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        var btnClearCN = new Button { Text = "Clear", Left = 82, Top = cny + 16, Width = 50, Height = 22, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(60, 30, 30), ForeColor = Color.FromArgb(200, 150, 150) };
        var lblCNPath = new Label { Left = 138, Top = cny + 18, Width = 260, Height = 18, ForeColor = Color.FromArgb(180, 190, 200), AutoEllipsis = true };
        cnBox.Controls.Add(btnBrowseCN); cnBox.Controls.Add(btnClearCN); cnBox.Controls.Add(lblCNPath);
        btnBrowseCN.Click += (o, ev) => {
            using (var ofd = new OpenFileDialog { Title = "Select ControlNet input image", Filter = "Image files|*.png;*.jpg;*.jpeg;*.bmp;*.webp|All files|*.*" }) {
                if (ofd.ShowDialog() == DialogResult.OK) {
                    cnImagePath = ofd.FileName; lblCNPath.Text = ofd.FileName;
                    try { if (cnPreviewBox.Image != null) cnPreviewBox.Image.Dispose(); cnPreviewBox.Image = Image.FromFile(ofd.FileName); } catch { }
                }
            }
        };
        btnClearCN.Click += (o, ev) => {
            if (!string.IsNullOrEmpty(cnImagePath)) { cnImagePath = ""; lblCNPath.Text = ""; try { if (cnPreviewBox.Image != null) cnPreviewBox.Image.Dispose(); cnPreviewBox.Image = null; } catch { } }
        };
        cny += 40;
        cnBox.Controls.Add(new Label { Text = "Filter", Left = 6, Top = cny, Width = 60, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        comboCNFilter = new ComboBox { Left = 6, Top = cny + 16, Width = 392, DropDownStyle = ComboBoxStyle.DropDownList }; comboCNFilter.Items.AddRange(new[] { "None", "Canny", "Depth", "OpenPose" }); comboCNFilter.SelectedIndex = 0;
        cnBox.Controls.Add(comboCNFilter); cny += 40;
        cnBox.Controls.Add(new Label { Text = "Strength", Left = 6, Top = cny, Width = 52, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        numCNStrength = new NumericUpDown { Left = 6, Top = cny + 16, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1, BackColor = Color.FromArgb(40, 40, 50), ForeColor = Color.FromArgb(200, 200, 210) };
        cnBox.Controls.Add(numCNStrength);
        cnBox.Controls.Add(new Label { Text = "Start/End", Left = 96, Top = cny, Width = 62, Height = 16, ForeColor = Color.FromArgb(180, 190, 200) });
        numCNStart = new NumericUpDown { Left = 96, Top = cny + 16, Width = 65, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, BackColor = Color.FromArgb(40, 40, 50), ForeColor = Color.FromArgb(200, 200, 210) };
        cnBox.Controls.Add(numCNStart);
        numCNEnd = new NumericUpDown { Left = 166, Top = cny + 16, Width = 65, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1, BackColor = Color.FromArgb(40, 40, 50), ForeColor = Color.FromArgb(200, 200, 210) };
        cnBox.Controls.Add(numCNEnd);
        ry += 246;

        var cnPrevBox = new GroupBox { Text = "CN Preview", Left = 4, Top = ry, Width = rw, Height = 200, Font = new Font("Segoe UI", 8, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        rp.Controls.Add(cnPrevBox);
        cnPreviewBox = new PictureBox { Left = 6, Top = 20, Width = 396, Height = 172, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.FromArgb(18, 18, 24) };
        cnPrevBox.Controls.Add(cnPreviewBox);

        // GPU status bar
        lblGpuStatus = new Label { Dock = DockStyle.Bottom, Height = 24, BackColor = Color.FromArgb(40, 50, 40), ForeColor = Color.FromArgb(150, 200, 150), Font = new Font("Segoe UI", 7.5f), Padding = new Padding(8, 3, 0, 0), BorderStyle = BorderStyle.FixedSingle };
        this.Controls.Add(lblGpuStatus);
        lblGpuStatus.Text = "GPU: Loading... | VRAM: ... | ComfyUI: ... | LabWorker: starting...";
        statusWorker = new System.ComponentModel.BackgroundWorker();
        statusWorker.DoWork += (o, args) => {
            try {
                var req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:5011/status");
                req.Timeout = 1000; req.Method = "GET";
                using (var resp = (HttpWebResponse)req.GetResponse())
                using (var reader = new StreamReader(resp.GetResponseStream())) {
                    args.Result = reader.ReadToEnd();
                }
            } catch { args.Result = null; }
        };
        statusWorker.RunWorkerCompleted += (o, args) => {
            if (args.Error != null || args.Result == null || lblGpuStatus == null || lblGpuStatus.IsDisposed) {
                if (lblGpuStatus != null && !lblGpuStatus.IsDisposed)
                    lblGpuStatus.Text = "GPU: ? | VRAM: ? / ? | ComfyUI: Offline | LabWorker: Offline";
                return;
            }
            try {
                var jss = new JavaScriptSerializer();
                var d = jss.Deserialize<Dictionary<string, object>>((string)args.Result);
                if (d != null) {
                    string gpu = d.ContainsKey("gpu_name") ? d["gpu_name"].ToString() : "?";
                    string vu = d.ContainsKey("vram_used_gb") ? d["vram_used_gb"].ToString() : "?";
                    string vt = d.ContainsKey("vram_total_gb") ? d["vram_total_gb"].ToString() : "?";
                    bool cu = d.ContainsKey("comfyui_online") && Convert.ToBoolean(d["comfyui_online"]);
                    string wrk = d.ContainsKey("worker") ? d["worker"].ToString() : "Offline";
                    lblGpuStatus.Text = "GPU: " + gpu + "  |  VRAM: " + vu + " / " + vt + " GB  |  ComfyUI: " + (cu ? "Online" : "Offline") + "  |  LabWorker: " + wrk;
                    lblGpuStatus.ForeColor = (cu || wrk == "online") ? Color.FromArgb(150, 200, 150) : Color.FromArgb(200, 150, 150);
                }
            } catch { }
        };
        gpuTimer = new Timer { Interval = 5000 };
        gpuTimer.Tick += (o, e) => { if (!statusWorker.IsBusy) statusWorker.RunWorkerAsync(); };
        gpuTimer.Start();

        // Start LabWorker silently
        string workerPath = Path.Combine(labRoot, "LabWorker", "LabWorker.exe");
        if (File.Exists(workerPath)) {
            try {
                var psi = new System.Diagnostics.ProcessStartInfo(workerPath) {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden
                };
                labWorkerProcess = System.Diagnostics.Process.Start(psi);
            } catch { }
        }

        LoadPrefs();
        LoadLoraItems();
    }


    private Button CreateButton(string text, int x, int y, int w, int h, Color bg, Color fg, Font font) {
        return new Button { Text = text, Left = x, Top = y, Width = w, Height = h, BackColor = bg, ForeColor = fg, Font = font, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 } };
    }

    private Label MakeLabel(string text, int x, int y, int w = 200, int h = 18) {
        return new Label { Text = text, Left = x, Top = y, Width = w, Height = h };
    }
    private GroupBox CmdCell(TableLayoutPanel grid, int col, int row, string title) {
        var gb = new GroupBox { Text = title, Dock = DockStyle.Fill, Font = new Font("Segoe UI", 7, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        grid.Controls.Add(gb, col, row); return gb;
    }
    private Button CmdBtn(GroupBox parent, string text, int y, Color? back, FontStyle fs) {
        var btn = new Button { Text = text, Width = parent.Width - 8, Height = 26, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 }, Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top };
        if (parent.Width < 50) btn.Width = 120;
        btn.Top = y; btn.Left = 4; btn.Font = new Font("Segoe UI", 7, fs);
        if (back.HasValue) { btn.BackColor = back.Value; btn.ForeColor = Color.White; } else { btn.BackColor = Color.FromArgb(50, 50, 60); btn.ForeColor = Color.White; }
        parent.Controls.Add(btn); return btn;
    }
    private void BuildResourcesTab(TabPage tab) {
        int y = 4; int lw = 120; int dw = 320;
        List<string> cachedCheckpoints = null; List<string> cachedLoras = null;
        Action refreshLocal = () => {
            string mr = !string.IsNullOrEmpty(detectedModelRoot) ? detectedModelRoot : @"C:\Users\Michael\Documents\ComfyUI\models";
            string ckptRoot = Path.Combine(mr, "checkpoints");
            if (Directory.Exists(ckptRoot)) cachedCheckpoints = new List<string>(Directory.GetFiles(ckptRoot, "*.safetensors", SearchOption.AllDirectories).Concat(Directory.GetFiles(ckptRoot, "*.ckpt", SearchOption.AllDirectories)).Concat(Directory.GetFiles(ckptRoot, "*.pt", SearchOption.AllDirectories)).Select(f => f.Substring(ckptRoot.Length).TrimStart('\\')).OrderBy(x => x));
            else cachedCheckpoints = new List<string>();
            string loraRoot = Path.Combine(mr, "loras");
            if (Directory.Exists(loraRoot)) cachedLoras = new List<string>(Directory.GetFiles(loraRoot, "*.safetensors", SearchOption.AllDirectories).Concat(Directory.GetFiles(loraRoot, "*.ckpt", SearchOption.AllDirectories)).Concat(Directory.GetFiles(loraRoot, "*.pt", SearchOption.AllDirectories)).Select(f => f.Substring(loraRoot.Length).TrimStart('\\')).OrderBy(x => x));
            else cachedLoras = new List<string>();
        };
        refreshLocal();
        tab.Controls.Add(new Label { Text = "Resource Type", Left = 8, Top = y, Width = lw, Height = 18, ForeColor = Color.FromArgb(200, 200, 210) });
        var comboType = new ComboBox { Left = 8, Top = y + 20, Width = dw, DropDownStyle = ComboBoxStyle.DropDownList };
        comboType.Items.AddRange(new[] { "Checkpoint", "LoRA" }); comboType.SelectedIndex = 0;
        tab.Controls.Add(comboType); y += 46;
        tab.Controls.Add(new Label { Text = "Source", Left = 8, Top = y, Width = lw, Height = 18, ForeColor = Color.FromArgb(200, 200, 210) }); y += 20;
        var comboSource = new ComboBox { Left = 8, Top = y, Width = dw, DropDownStyle = ComboBoxStyle.DropDownList };
        comboSource.Items.AddRange(new[] { "Hugging Face", "Civitai", "GitHub", "Other URL" }); comboSource.SelectedIndex = 0;
        tab.Controls.Add(comboSource); y += 46;
        tab.Controls.Add(new Label { Text = "URL", Left = 8, Top = y, Width = lw, Height = 18, ForeColor = Color.FromArgb(200, 200, 210) }); y += 20;
        var txtUrl = new TextBox { Left = 8, Top = y, Width = 420, Height = 24 }; tab.Controls.Add(txtUrl); y += 30;
        comboSource.SelectedIndexChanged += (o, e) => {
            switch (comboSource.SelectedIndex) { case 0: txtUrl.Text = "https://huggingface.co/models"; break; case 1: txtUrl.Text = "https://civitai.com/models"; break; case 2: txtUrl.Text = "https://github.com"; break; default: txtUrl.Text = ""; break; }
        };
        comboSource.SelectedIndex = 0;
        var btnOpenSrc = new Button { Text = "Open Source Site", Left = 8, Top = y, Width = 100, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnOpenSrc.Click += (o, ev) => { string[] u = { "https://huggingface.co/models", "https://civitai.com/models", "https://github.com", "" }; int idx = comboSource.SelectedIndex >= 0 && comboSource.SelectedIndex < u.Length ? comboSource.SelectedIndex : 3; if (!string.IsNullOrEmpty(u[idx])) try { System.Diagnostics.Process.Start(u[idx]); } catch { } };
        tab.Controls.Add(btnOpenSrc);
        var btnOpenUrl = new Button { Text = "Open URL", Left = 112, Top = y, Width = 80, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnOpenUrl.Click += (o, ev) => { if (!string.IsNullOrEmpty(txtUrl.Text)) try { System.Diagnostics.Process.Start(txtUrl.Text); } catch { } };
        tab.Controls.Add(btnOpenUrl);
        var btnCopyUrl = new Button { Text = "Copy URL", Left = 196, Top = y, Width = 70, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnCopyUrl.Click += (o, ev) => { if (!string.IsNullOrEmpty(txtUrl.Text)) { Clipboard.SetText(txtUrl.Text); } };
        tab.Controls.Add(btnCopyUrl);
        var btnRefresh = new Button { Text = "Refresh Local", Left = 270, Top = y, Width = 80, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnRefresh.Click += (o, ev) => { refreshLocal(); };
        tab.Controls.Add(btnRefresh);
        y += 34;
        var detBox = new GroupBox { Text = "Details", Left = 8, Top = y, Width = 580, Height = 220, Font = new Font("Segoe UI", 8, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        tab.Controls.Add(detBox);
        var lblInfo = new Label { Left = 8, Top = 22, Width = 560, Height = 190, ForeColor = Color.FromArgb(180, 220, 180), Font = new Font("Consolas", 8.5f) };
        detBox.Controls.Add(lblInfo);
        Action updateDetails = () => {
            string type = comboType.SelectedIndex == 0 ? "Checkpoint" : "LoRA";
            string source = comboSource.SelectedItem != null ? comboSource.SelectedItem.ToString() : "?";
            string mr2 = !string.IsNullOrEmpty(detectedModelRoot) ? detectedModelRoot : @"C:\Users\Michael\Documents\ComfyUI\models";
            string targetFolder = comboType.SelectedIndex == 0 ? Path.Combine(mr2, "checkpoints") : Path.Combine(mr2, "loras");
            var localFiles = comboType.SelectedIndex == 0 ? cachedCheckpoints : cachedLoras;
            string fileCount = localFiles != null ? localFiles.Count.ToString() : "?";
            lblInfo.Text = "Type:              " + type + "\r\nSource:            " + source + "\r\nTarget Folder:     " + targetFolder + "\r\nLocal Files:       " + fileCount + "\r\nURL:               " + txtUrl.Text + "\r\n\r\nDownload Later:    Click Download Later to add a download link.\r\n                  No automatic download will start.";
        };
        comboType.SelectedIndexChanged += (o, ev) => updateDetails();
        comboSource.SelectedIndexChanged += (o, ev) => updateDetails();
        updateDetails();
        y = 260;
        var btnCopyFolder = new Button { Text = "Copy Target Folder", Left = 8, Top = y, Width = 120, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnCopyFolder.Click += (o, ev) => { string mr2 = !string.IsNullOrEmpty(detectedModelRoot) ? detectedModelRoot : @"C:\Users\Michael\Documents\ComfyUI\models"; Clipboard.SetText(comboType.SelectedIndex == 0 ? Path.Combine(mr2, "checkpoints") : Path.Combine(mr2, "loras")); };
        tab.Controls.Add(btnCopyFolder);
        var btnOpenFolder = new Button { Text = "Open Target Folder", Left = 132, Top = y, Width = 120, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(50, 50, 60), ForeColor = Color.White };
        btnOpenFolder.Click += (o, ev) => { string mr2 = !string.IsNullOrEmpty(detectedModelRoot) ? detectedModelRoot : @"C:\Users\Michael\Documents\ComfyUI\models"; try { System.Diagnostics.Process.Start(comboType.SelectedIndex == 0 ? Path.Combine(mr2, "checkpoints") : Path.Combine(mr2, "loras")); } catch { } };
        tab.Controls.Add(btnOpenFolder);
        var btnDownloadLater = new Button { Text = "Download Later", Left = 256, Top = y, Width = 100, Height = 28, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(60, 30, 30), ForeColor = Color.FromArgb(180, 120, 120), Enabled = false };
        tab.Controls.Add(btnDownloadLater);
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
        tabMain.Controls.Add(numLora); gy += 60;

        // Row 1: Seed label (w=40), Seed TextBox, Random checkbox
        tabMain.Controls.Add(MakeLabel("Seed", 8, gy, 40, 18));
        txtSeed = new TextBox { Left = 50, Top = gy, Width = 160, Text = new Random().Next(1, int.MaxValue).ToString(), BackColor = Color.White, ForeColor = Color.Black, BorderStyle = BorderStyle.FixedSingle, MaxLength = 10, Font = new Font("Segoe UI", 9) };
        txtSeed.BringToFront();
        txtSeed.KeyPress += (o, e) => { if (!char.IsDigit(e.KeyChar) && !char.IsControl(e.KeyChar)) e.Handled = true; };
        tabMain.Controls.Add(txtSeed);
        chkRandomSeed = new CheckBox { Text = "Random", Left = 258, Top = gy + 1, Width = 70, Height = 18, Checked = true, Font = new Font("Segoe UI", 8) };
        tabMain.Controls.Add(chkRandomSeed); gy += 60;

        // Row 2: Width label (w=60), Width numeric, x, Height numeric, Height label (w=60)
        tabMain.Controls.Add(MakeLabel("Width", 8, gy, 60, 18).WithColor(Color.Black));
        numWidth = new NumericUpDown { Left = 8, Top = gy + 18, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numWidth);
        var lblX = new Label { Text = "x", Left = 80, Top = gy + 20, Width = 12, Height = 16 };
        tabMain.Controls.Add(lblX);
        numHeight = new NumericUpDown { Left = 92, Top = gy + 18, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numHeight);
        tabMain.Controls.Add(MakeLabel("Height", 92, gy, 60, 18).WithColor(Color.Black));
        gy += 44;

        // Row 3: Steps label (w=60), Steps numeric, CFG label (w=40), CFG numeric
        tabMain.Controls.Add(MakeLabel("Steps", 8, gy, 60, 18).WithColor(Color.Black).WithFont(9));
        numSteps = new NumericUpDown { Left = 8, Top = gy + 18, Width = 60, Minimum = 1, Maximum = 150, Value = 30, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numSteps);
        tabMain.Controls.Add(MakeLabel("CFG", 80, gy, 40, 18).WithColor(Color.Black).WithFont(9));
        numCfg = new NumericUpDown { Left = 80, Top = gy + 18, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 7, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numCfg); gy += 44;

        // Row 4: Sampler label (w=80), Sampler dropdown, Scheduler label (w=80), Scheduler dropdown
        tabMain.Controls.Add(MakeLabel("Sampler", 8, gy, 80, 18));
        comboSampler = new ComboBox { Left = 8, Top = gy + 18, Width = 120, DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (var s in new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }) comboSampler.Items.Add(s);
        comboSampler.SelectedIndex = 0; tabMain.Controls.Add(comboSampler);
        tabMain.Controls.Add(MakeLabel("Scheduler", 140, gy, 80, 18));
        comboScheduler = new ComboBox { Left = 140, Top = gy + 18, Width = 120, DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (var s in new[] { "karras", "exponential", "simple", "normal" }) comboScheduler.Items.Add(s);
        comboScheduler.SelectedIndex = 0; tabMain.Controls.Add(comboScheduler); gy += 44;

        // Row 5: Workflow Preset label, Workflow Preset dropdown
        tabMain.Controls.Add(MakeLabel("Workflow Preset", 8, gy));
        comboWorkflow = new ComboBox { Left = 8, Top = gy + 18, Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        comboWorkflow.Items.Add("Standard LoRA Test"); comboWorkflow.SelectedIndex = 0;
        tabMain.Controls.Add(comboWorkflow); gy += 46;

        // Row 6: Profile label (w=60), Profile dropdown, Prompt Preset label (w=100), Prompt Preset dropdown
        tabMain.Controls.Add(MakeLabel("Profile", 8, gy, 60, 18));
        comboProfile = new ComboBox { Left = 8, Top = gy + 18, Width = 140, DropDownStyle = ComboBoxStyle.DropDownList };
        comboProfile.Items.Add("Default"); comboProfile.SelectedIndex = 0;
        tabMain.Controls.Add(comboProfile);
        tabMain.Controls.Add(MakeLabel("Prompt Preset", 160, gy, 100, 18));
        comboPreset = new ComboBox { Left = 160, Top = gy + 18, Width = 110, DropDownStyle = ComboBoxStyle.DropDownList };
        comboPreset.Items.Add("None"); comboPreset.SelectedIndex = 0;
        tabMain.Controls.Add(comboPreset); gy += 46;

        var outfitBox = new GroupBox { Text = "Outfit", Left = 6, Top = gy, Width = 405, Height = 160, Font = new Font("Segoe UI", 8.5f, FontStyle.Bold) };
        tabMain.Controls.Add(outfitBox);
        int oy = 20;
        outfitBox.Controls.Add(MakeLabel("Category", 8, oy, 60, 16).WithFont(7.5f));
        outfitBox.Controls.Add(MakeLabel("Item", 200, oy, 60, 16).WithFont(7.5f)); oy += 16;
        comboOutCat = new ComboBox { Left = 8, Top = oy, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutCat.Items.Add("-- All --"); comboOutCat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutCat);
        comboOutItem = new ComboBox { Left = 200, Top = oy, Width = 190, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8), Enabled = false };
        outfitBox.Controls.Add(comboOutItem); oy += 24;
        outfitBox.Controls.Add(MakeLabel("Color", 8, oy, 60, 16).WithFont(7.5f));
        outfitBox.Controls.Add(MakeLabel("Material", 200, oy, 60, 16).WithFont(7.5f)); oy += 16;
        comboOutColor = new ComboBox { Left = 8, Top = oy, Width = 180, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutColor.Items.Add("-- None --"); comboOutColor.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutColor);
        comboOutMat = new ComboBox { Left = 200, Top = oy, Width = 190, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 8) };
        comboOutMat.Items.Add("-- None --"); comboOutMat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutMat); oy += 24;
        chkEnableOutfit = new CheckBox { Text = "Enable Outfit", Left = 8, Top = oy, Width = 90, Height = 18, Font = new Font("Segoe UI", 7.5f) };
        outfitBox.Controls.Add(chkEnableOutfit);
        comboOutfitPlacement = new ComboBox { Left = 100, Top = oy - 1, Width = 130, DropDownStyle = ComboBoxStyle.DropDownList, Font = new Font("Segoe UI", 7.5f) };
        comboOutfitPlacement.Items.Add("Append"); comboOutfitPlacement.Items.Add("Prepend"); comboOutfitPlacement.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutfitPlacement); oy += 22;
        txtOutfit = new TextBox { Left = 8, Top = oy, Width = 382, Height = 22, Font = new Font("Segoe UI", 8), ReadOnly = true };
        outfitBox.Controls.Add(txtOutfit); oy += 28;

        gy += 166;
        chkRealism = new CheckBox { Text = "Realism Boost", Left = 8, Top = gy, Width = 110, Height = 20 };
        tabMain.Controls.Add(chkRealism);
        DumpSeedDiagnostic();
    }

    private void BuildExtrasTab() {
        logBox = new TextBox { Left = 6, Top = 4, Width = 540, Height = 280, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(180, 220, 180), Font = new Font("Consolas", 8.5f) };
        tabExtras.Controls.Add(logBox);
        var sessGroup = new GroupBox { Text = "Session Controls", Left = 6, Top = 290, Width = 540, Height = 80, Font = new Font("Segoe UI", 8, FontStyle.Bold), ForeColor = Color.FromArgb(200, 200, 210) };
        tabExtras.Controls.Add(sessGroup);
        var sessBtn = new Button { Text = "Start Session", Left = 10, Top = 24, Width = 110, Height = 26, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(34, 120, 64), ForeColor = Color.White };
        sessBtn.Click += (o, e) => ToggleSession();
    }

    private void CaptureMetadata() {
        bool includePrompt = chkCapture.Checked;
        var sb = new System.Text.StringBuilder();
        sb.AppendLine("=== Metadata Capture ===");
        sb.AppendLine("Time: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        if (includePrompt) {
            sb.AppendLine("Prompt: " + txtPrompt.Text);
            sb.AppendLine("Negative: " + txtNegative.Text);
        } else {
            sb.AppendLine("Prompt: [hidden - check Collect Meta to include]");
            sb.AppendLine("Negative: [hidden - check Collect Meta to include]");
        }
        sb.AppendLine("Model Source: " + (comboModelSource != null && comboModelSource.SelectedItem != null ? comboModelSource.SelectedItem.ToString() : "Checkpoints"));
        sb.AppendLine("Type / Style: " + (comboCheckpointStyle != null && comboCheckpointStyle.SelectedItem != null ? comboCheckpointStyle.SelectedItem.ToString() : "All"));
        sb.AppendLine("Selected Model: " + (comboCheckpoint.SelectedItem != null ? comboCheckpoint.SelectedItem.ToString() : "None"));
        sb.AppendLine("LoRA: " + (comboLora.SelectedItem != null ? comboLora.SelectedItem.ToString() : "None") + " | Weight: " + numLora.Value);
        sb.AppendLine("Seed: " + (chkRandomSeed.Checked ? "Random" : txtSeed.Text));
        sb.AppendLine("Random Seed: " + chkRandomSeed.Checked);
        sb.AppendLine("Steps: " + numSteps.Value + " | CFG: " + numCfg.Value + " | Width: " + numWidth.Value + " | Height: " + numHeight.Value);
        sb.AppendLine("Sampler: " + (comboSampler.SelectedItem != null ? comboSampler.SelectedItem.ToString() : "") + " | Scheduler: " + (comboScheduler.SelectedItem != null ? comboScheduler.SelectedItem.ToString() : ""));
        sb.AppendLine("Workflow Preset: " + (comboWorkflow.SelectedItem != null ? comboWorkflow.SelectedItem.ToString() : ""));
        sb.AppendLine("Prompt Preset: " + (comboPreset.SelectedItem != null ? comboPreset.SelectedItem.ToString() : "None"));
        if (chkEnableOutfit.Checked) {
            sb.AppendLine("Outfit Enabled: True | Category: " + (comboOutCat.SelectedItem != null ? comboOutCat.SelectedItem.ToString() : "") +
                " | Item: " + (comboOutItem.SelectedItem != null ? comboOutItem.SelectedItem.ToString() : "") +
                " | Color: " + (comboOutColor.SelectedItem != null ? comboOutColor.SelectedItem.ToString() : "") +
                " | Material: " + (comboOutMat.SelectedItem != null ? comboOutMat.SelectedItem.ToString() : "") +
                " | Text: " + txtOutfit.Text);
        } else {
            sb.AppendLine("Outfit Enabled: False");
        }
        sb.AppendLine("ControlNet Enabled: " + chkCN.Checked + " | Model: " + (comboCNModel.SelectedItem != null ? comboCNModel.SelectedItem.ToString() : "None") +
            " | Image: " + (string.IsNullOrEmpty(cnImagePath) ? "None" : cnImagePath) +
            " | Filter: " + (comboCNFilter.SelectedItem != null ? comboCNFilter.SelectedItem.ToString() : "None"));
        sb.AppendLine("CN Strength: " + numCNStrength.Value + " | Start: " + numCNStart.Value + " | End: " + numCNEnd.Value);
        sb.AppendLine("App: Mystikvoyd Studios - Lab | Version: " + AppVersion.Value);
        string meta = sb.ToString();
        logBox.AppendText(meta + "\r\n");
        if (includePrompt) {
            string metaPath = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "metadata_capture.txt");
            try { File.AppendAllText(metaPath, meta + "\r\n"); } catch { }
            Log("Metadata saved to " + metaPath);
        }
    }

    private Dictionary<string, object> CollectUiState() {
        var d = new Dictionary<string, object>();
        d["ModelSource"] = comboModelSource != null ? comboModelSource.SelectedIndex : 0;
        d["TypeStyle"] = comboCheckpointStyle != null && comboCheckpointStyle.SelectedItem != null ? comboCheckpointStyle.SelectedItem.ToString() : "All";
        d["Checkpoint"] = comboCheckpoint != null && comboCheckpoint.SelectedItem != null ? comboCheckpoint.SelectedItem.ToString() : "None";
        d["LoRA"] = comboLora != null && comboLora.SelectedItem != null ? comboLora.SelectedItem.ToString() : "None";
        d["LoRAStrength"] = (double)numLora.Value;
        d["LoRAUse"] = chkLora.Checked;
        int seedVal; d["Seed"] = chkRandomSeed.Checked ? -1 : (int.TryParse(txtSeed.Text, out seedVal) ? seedVal : -1);
        d["RandomSeed"] = chkRandomSeed.Checked;
        d["Steps"] = (int)numSteps.Value;
        d["CFG"] = (double)numCfg.Value;
        d["Width"] = (int)numWidth.Value;
        d["Height"] = (int)numHeight.Value;
        d["Sampler"] = comboSampler != null && comboSampler.SelectedItem != null ? comboSampler.SelectedItem.ToString() : "";
        d["Scheduler"] = comboScheduler != null && comboScheduler.SelectedItem != null ? comboScheduler.SelectedItem.ToString() : "";
        d["Workflow"] = comboWorkflow != null && comboWorkflow.SelectedItem != null ? comboWorkflow.SelectedItem.ToString() : "";
        d["Profile"] = comboProfile != null && comboProfile.SelectedItem != null ? comboProfile.SelectedItem.ToString() : "";
        d["PromptPreset"] = comboPreset != null && comboPreset.SelectedItem != null ? comboPreset.SelectedItem.ToString() : "";
        d["CNEnabled"] = chkCN.Checked;
        d["CNModel"] = comboCNModel != null && comboCNModel.SelectedItem != null ? comboCNModel.SelectedItem.ToString() : "None";
        d["CNFilter"] = comboCNFilter != null && comboCNFilter.SelectedItem != null ? comboCNFilter.SelectedItem.ToString() : "None";
        d["CNStrength"] = (double)numCNStrength.Value;
        d["CNStart"] = (double)numCNStart.Value;
        d["CNEnd"] = (double)numCNEnd.Value;
        d["CNImagePath"] = cnImagePath ?? "";
        d["Prompt"] = txtPrompt != null ? txtPrompt.Text : "";
        d["Negative"] = txtNegative != null ? txtNegative.Text : "";
        d["EnableOutfit"] = chkEnableOutfit.Checked;
        d["OutfitPlacement"] = comboOutfitPlacement != null && comboOutfitPlacement.SelectedItem != null ? comboOutfitPlacement.SelectedIndex : 0;
        d["OutfitCategory"] = comboOutCat != null && comboOutCat.SelectedItem != null ? comboOutCat.SelectedItem.ToString() : "";
        d["OutfitItem"] = comboOutItem != null && comboOutItem.SelectedItem != null ? comboOutItem.SelectedItem.ToString() : "";
        d["OutfitColor"] = comboOutColor != null && comboOutColor.SelectedItem != null ? comboOutColor.SelectedItem.ToString() : "";
        d["OutfitMaterial"] = comboOutMat != null && comboOutMat.SelectedItem != null ? comboOutMat.SelectedItem.ToString() : "";
        d["RealismBoost"] = chkRealism != null ? chkRealism.Checked : false;
        return d;
    }

    private void ApplyUiState(Dictionary<string, object> d) {
        if (d == null) return;
        if (d.ContainsKey("ModelSource") && comboModelSource != null) { int idx = Convert.ToInt32(d["ModelSource"]); if (idx >= 0 && idx < comboModelSource.Items.Count) comboModelSource.SelectedIndex = idx; }
        if (d.ContainsKey("Checkpoint") && comboCheckpoint != null) { string v = d["Checkpoint"].ToString(); int i = comboCheckpoint.Items.IndexOf(v); if (i >= 0) comboCheckpoint.SelectedIndex = i; }
        if (d.ContainsKey("LoRA") && comboLora != null) { string v = d["LoRA"].ToString(); int i = comboLora.Items.IndexOf(v); if (i >= 0) comboLora.SelectedIndex = i; }
        if (d.ContainsKey("LoRAStrength")) numLora.Value = Math.Min((decimal)(double)d["LoRAStrength"], numLora.Maximum);
        if (d.ContainsKey("LoRAUse")) chkLora.Checked = (bool)d["LoRAUse"];
        if (d.ContainsKey("RandomSeed") && (bool)d["RandomSeed"]) { chkRandomSeed.Checked = true; } else { chkRandomSeed.Checked = false; }
        if (d.ContainsKey("Seed") && !chkRandomSeed.Checked) { int s = Convert.ToInt32(d["Seed"]); if (s > 0) txtSeed.Text = s.ToString(); }
        if (d.ContainsKey("Steps")) numSteps.Value = Convert.ToInt32(d["Steps"]);
        if (d.ContainsKey("CFG")) numCfg.Value = Math.Min((decimal)(double)d["CFG"], numCfg.Maximum);
        if (d.ContainsKey("Width")) numWidth.Value = Convert.ToInt32(d["Width"]);
        if (d.ContainsKey("Height")) numHeight.Value = Convert.ToInt32(d["Height"]);
        if (d.ContainsKey("Sampler") && comboSampler != null) { string v = d["Sampler"].ToString(); int i = comboSampler.Items.IndexOf(v); if (i >= 0) comboSampler.SelectedIndex = i; }
        if (d.ContainsKey("Scheduler") && comboScheduler != null) { string v = d["Scheduler"].ToString(); int i = comboScheduler.Items.IndexOf(v); if (i >= 0) comboScheduler.SelectedIndex = i; }
        if (d.ContainsKey("Workflow") && comboWorkflow != null) { string v = d["Workflow"].ToString(); int i = comboWorkflow.Items.IndexOf(v); if (i >= 0) comboWorkflow.SelectedIndex = i; }
        if (d.ContainsKey("Profile") && comboProfile != null) { string v = d["Profile"].ToString(); int i = comboProfile.Items.IndexOf(v); if (i >= 0) comboProfile.SelectedIndex = i; }
        if (d.ContainsKey("PromptPreset") && comboPreset != null) { string v = d["PromptPreset"].ToString(); int i = comboPreset.Items.IndexOf(v); if (i >= 0) comboPreset.SelectedIndex = i; }
        if (d.ContainsKey("CNEnabled")) chkCN.Checked = (bool)d["CNEnabled"];
        if (d.ContainsKey("CNModel") && comboCNModel != null) { string v = d["CNModel"].ToString(); int i = comboCNModel.Items.IndexOf(v); if (i >= 0) comboCNModel.SelectedIndex = i; }
        if (d.ContainsKey("CNFilter") && comboCNFilter != null) { string v = d["CNFilter"].ToString(); int i = comboCNFilter.Items.IndexOf(v); if (i >= 0) comboCNFilter.SelectedIndex = i; }
        if (d.ContainsKey("CNStrength")) numCNStrength.Value = Math.Min((decimal)(double)d["CNStrength"], numCNStrength.Maximum);
        if (d.ContainsKey("CNStart")) numCNStart.Value = Math.Min((decimal)(double)d["CNStart"], numCNStart.Maximum);
        if (d.ContainsKey("CNEnd")) numCNEnd.Value = Math.Min((decimal)(double)d["CNEnd"], numCNEnd.Maximum);
        if (d.ContainsKey("CNImagePath")) cnImagePath = d["CNImagePath"].ToString();
        if (d.ContainsKey("Prompt") && txtPrompt != null) txtPrompt.Text = d["Prompt"].ToString();
        if (d.ContainsKey("Negative") && txtNegative != null) txtNegative.Text = d["Negative"].ToString();
        if (d.ContainsKey("EnableOutfit")) chkEnableOutfit.Checked = (bool)d["EnableOutfit"];
        if (d.ContainsKey("OutfitPlacement") && comboOutfitPlacement != null) { int idx = Convert.ToInt32(d["OutfitPlacement"]); if (idx >= 0 && idx < comboOutfitPlacement.Items.Count) comboOutfitPlacement.SelectedIndex = idx; }
        if (d.ContainsKey("OutfitCategory") && comboOutCat != null) { string v = d["OutfitCategory"].ToString(); int i = comboOutCat.Items.IndexOf(v); if (i >= 0) comboOutCat.SelectedIndex = i; }
        if (d.ContainsKey("OutfitColor") && comboOutColor != null) { string v = d["OutfitColor"].ToString(); int i = comboOutColor.Items.IndexOf(v); if (i >= 0) comboOutColor.SelectedIndex = i; }
        if (d.ContainsKey("OutfitMaterial") && comboOutMat != null) { string v = d["OutfitMaterial"].ToString(); int i = comboOutMat.Items.IndexOf(v); if (i >= 0) comboOutMat.SelectedIndex = i; }
    }

    private void SaveDefaultConfig() {
        try { File.WriteAllText(defaultConfigPath, json.Serialize(CollectUiState())); } catch { }
    }

    private void LoadDefaultConfig() {
        if (!File.Exists(defaultConfigPath)) return;
        try { ApplyUiState(json.Deserialize<Dictionary<string, object>>(File.ReadAllText(defaultConfigPath))); } catch { }
    }

    private void SaveConfigDialog() {
        string cfgDir = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "configs");
        Directory.CreateDirectory(cfgDir);
        var sfd = new SaveFileDialog { Title = "Save Config", InitialDirectory = cfgDir, Filter = "JSON files|*.json|All files|*.*", FileName = "config.json" };
        if (sfd.ShowDialog() == DialogResult.OK) {
            try { File.WriteAllText(sfd.FileName, json.Serialize(CollectUiState())); Log("Config saved: " + sfd.FileName); } catch (Exception ex) { Log("Error saving config: " + ex.Message); }
        }
    }

    private void LoadConfigDialog() {
        string cfgDir = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "configs");
        Directory.CreateDirectory(cfgDir);
        var ofd = new OpenFileDialog { Title = "Load Config", InitialDirectory = cfgDir, Filter = "JSON files|*.json|All files|*.*" };
        if (ofd.ShowDialog() == DialogResult.OK) {
            try { ApplyUiState(json.Deserialize<Dictionary<string, object>>(File.ReadAllText(ofd.FileName))); Log("Config loaded: " + ofd.FileName); } catch (Exception ex) { Log("Error loading config: " + ex.Message); }
        }
    }

    private void OpenOutput() {
        string outputPath = @"C:\Users\Michael\Documents\ComfyUI\output";
        if (Directory.Exists(outputPath)) System.Diagnostics.Process.Start(outputPath);
    }

    private void SetPreview(string path) {
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;
        try { if (previewBox.Image != null) previewBox.Image.Dispose(); previewBox.Image = Image.FromFile(path); } catch { }
    }

    private void LoadOutfitData() {
        string dataDir = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "..", "data");
        if (!Directory.Exists(dataDir)) { dataDir = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "data"); }
        if (!Directory.Exists(dataDir)) return;
        LoadListFile(Path.Combine(dataDir, "clothing_categories.txt"), outfitCategories);
        LoadItemFile(Path.Combine(dataDir, "clothing_items.txt"), outfitItemsByCat);
        LoadListFile(Path.Combine(dataDir, "colors.txt"), outfitColors);
        LoadListFile(Path.Combine(dataDir, "materials.txt"), outfitMaterials);
        LoadListFile(Path.Combine(dataDir, "outfit_presets.txt"), outfitPresets);
        comboOutCat.Items.Clear(); comboOutCat.Items.Add("-- All --");
        foreach (var c in outfitCategories) comboOutCat.Items.Add(c);
        comboOutCat.SelectedIndex = 0;
        comboOutColor.Items.Clear(); comboOutColor.Items.Add("-- None --");
        foreach (var c in outfitColors) comboOutColor.Items.Add(c);
        comboOutColor.SelectedIndex = 0;
        comboOutMat.Items.Clear(); comboOutMat.Items.Add("-- None --");
        foreach (var m in outfitMaterials) comboOutMat.Items.Add(m);
        comboOutMat.SelectedIndex = 0;
    }

    private void LoadListFile(string path, List<string> target) {
        if (!File.Exists(path)) return;
        foreach (var line in File.ReadAllLines(path)) {
            string t = line.Trim();
            if (t.Length > 0 && !t.StartsWith("#")) target.Add(t);
        }
    }

    private void LoadItemFile(string path, Dictionary<string, List<string>> target) {
        if (!File.Exists(path)) return;
        foreach (var line in File.ReadAllLines(path)) {
            string t = line.Trim();
            if (t.Length == 0 || t.StartsWith("#")) continue;
            int sep = t.IndexOf('|');
            if (sep > 0) {
                string cat = t.Substring(0, sep).Trim();
                string item = t.Substring(sep + 1).Trim();
                if (!target.ContainsKey(cat)) target[cat] = new List<string>();
                target[cat].Add(item);
            }
        }
    }

    private void WireOutfitEvents() {
        comboOutCat.SelectedIndexChanged += (o, e) => {
            string sel = comboOutCat.SelectedItem != null ? comboOutCat.SelectedItem.ToString() : "";
            comboOutItem.Items.Clear(); comboOutItem.Items.Add("-- All --");
            if (sel != "-- All --" && outfitItemsByCat.ContainsKey(sel)) {
                foreach (var item in outfitItemsByCat[sel]) comboOutItem.Items.Add(item);
                comboOutItem.Enabled = true;
            } else { comboOutItem.Items.Add(""); comboOutItem.Enabled = false; }
            comboOutItem.SelectedIndex = 0;
            UpdateOutfitText();
        };
        comboOutItem.SelectedIndexChanged += (o, e) => UpdateOutfitText();
        comboOutColor.SelectedIndexChanged += (o, e) => UpdateOutfitText();
        comboOutMat.SelectedIndexChanged += (o, e) => UpdateOutfitText();
        chkEnableOutfit.CheckedChanged += (o, e) => UpdateOutfitText();
        comboOutfitPlacement.SelectedIndexChanged += (o, e) => UpdateOutfitText();
    }

    private void UpdateOutfitText() {
        if (!chkEnableOutfit.Checked) { txtOutfit.Text = ""; return; }
        string color = comboOutColor.SelectedItem != null && comboOutColor.SelectedItem.ToString() != "-- None --" ? comboOutColor.SelectedItem.ToString() : "";
        string mat = comboOutMat.SelectedItem != null && comboOutMat.SelectedItem.ToString() != "-- None --" ? comboOutMat.SelectedItem.ToString() : "";
        string item = comboOutItem.SelectedItem != null && comboOutItem.SelectedItem.ToString() != "-- All --" && !string.IsNullOrEmpty(comboOutItem.SelectedItem.ToString()) ? comboOutItem.SelectedItem.ToString() : "";
        var parts = new List<string>();
        if (!string.IsNullOrEmpty(color)) parts.Add(color);
        if (!string.IsNullOrEmpty(mat)) parts.Add(mat);
        if (!string.IsNullOrEmpty(item)) parts.Add(item);
        txtOutfit.Text = parts.Count > 0 ? string.Join(" ", parts) : "";
    }

    private string DetectModelRoot() {
        string[] searchRoots = {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "ComfyUI", "models"),
            @"C:\Users\Michael\Documents\ComfyUI\models",
            @"C:\Users\Michael\AppData\Local\Programs\ComfyUI\resources\ComfyUI\models"
        };
        string[] verificationFiles = { "sd_xl_base_1.0.safetensors", "Juggernaut-XL*", "dreamshaperXL*" };
        string[] validExts = { "*.safetensors", "*.ckpt", "*.pt", "*.pth", "*.bin" };
        foreach (var root in searchRoots) {
            if (!Directory.Exists(root)) continue;
            string ckptDir = Path.Combine(root, "checkpoints");
            if (!Directory.Exists(ckptDir)) continue;
            bool hasRealFiles = false;
            foreach (var ext in validExts) {
                var files = Directory.GetFiles(ckptDir, ext, SearchOption.AllDirectories);
                foreach (var f in files) {
                    string name = Path.GetFileName(f).ToLowerInvariant();
                    if (name != "put_checkpoints_here" && new FileInfo(f).Length > 1000) {
                        hasRealFiles = true; break;
                    }
                }
                if (hasRealFiles) break;
            }
            if (hasRealFiles) {
                Log("Model root detected: " + root);
                return root;
            }
        }
        Log("WARNING: No real model root found, falling back to Documents path");
        return searchRoots[0];
    }

    private void LoadLoraItems() {
        detectedModelRoot = DetectModelRoot();
        System.Threading.ThreadPool.QueueUserWorkItem(_ => {
            ScanFiles();
            try { this.Invoke((Action)(() => { PopulateCombos(); LoadDefaultConfig(); })); } catch { }
        });
    }

    private void ScanFiles() {
        string mr = detectedModelRoot;
        if (string.IsNullOrEmpty(mr)) { mr = DetectModelRoot(); detectedModelRoot = mr; }
        Log("Scanning models from: " + mr);
        Func<string, string[]> scan = (dir) => {
            if (!Directory.Exists(dir)) { Log("Folder not found: " + dir); return new string[0]; }
            return Directory.GetFiles(dir, "*.safetensors", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(dir, "*.ckpt", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(dir, "*.pt", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(dir, "*.pth", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(dir, "*.bin", SearchOption.AllDirectories))
                .OrderBy(x => x).ToArray();
        };
        // Checkpoints
        string ckptRoot = Path.Combine(mr, "checkpoints");
        cachedCheckpoints = new List<string>();
        cachedCheckpointSubfolders = new List<string>();
        cachedCheckpointsByFolder = new Dictionary<string, List<string>>();
        if (Directory.Exists(ckptRoot)) {
            foreach (var dir in Directory.GetDirectories(ckptRoot)) {
                string fn = Path.GetFileName(dir);
                cachedCheckpointSubfolders.Add(fn);
                var files = scan(dir).Select(f => f.Substring(ckptRoot.Length).TrimStart('\\')).ToList();
                cachedCheckpointsByFolder[fn] = files;
                cachedCheckpoints.AddRange(files);
            }
            foreach (var f in scan(ckptRoot)) {
                string rel = f.Substring(ckptRoot.Length).TrimStart('\\');
                if (!rel.Contains('\\')) { cachedCheckpoints.Add(rel); if (!cachedCheckpointsByFolder.ContainsKey("(root)")) cachedCheckpointsByFolder["(root)"] = new List<string>(); cachedCheckpointsByFolder["(root)"].Add(rel); }
            }
        }
        Log("Checkpoints found: " + cachedCheckpoints.Count);
        if (cachedCheckpoints.Count > 0) { Log("First 5: " + string.Join(", ", cachedCheckpoints.Take(5))); }
        // Diffusion models
        string diffRoot = Path.Combine(mr, "diffusion_models");
        cachedDiffusionModels = new List<string>();
        cachedDiffusionSubfolders = new List<string>();
        cachedDiffusionByFolder = new Dictionary<string, List<string>>();
        if (Directory.Exists(diffRoot)) {
            foreach (var dir in Directory.GetDirectories(diffRoot)) {
                string fn = Path.GetFileName(dir);
                cachedDiffusionSubfolders.Add(fn);
                var files = scan(dir).Select(f => f.Substring(diffRoot.Length).TrimStart('\\')).ToList();
                cachedDiffusionByFolder[fn] = files;
                cachedDiffusionModels.AddRange(files);
            }
            foreach (var f in scan(diffRoot)) {
                string rel = f.Substring(diffRoot.Length).TrimStart('\\');
                if (!rel.Contains('\\')) { cachedDiffusionModels.Add(rel); if (!cachedDiffusionByFolder.ContainsKey("(root)")) cachedDiffusionByFolder["(root)"] = new List<string>(); cachedDiffusionByFolder["(root)"].Add(rel); }
            }
        }
        Log("Diffusion models found: " + cachedDiffusionModels.Count);
        // LoRAs
        string loraRoot = Path.Combine(mr, "loras");
        cachedLoras = new List<string>();
        if (Directory.Exists(loraRoot)) {
            cachedLoras.AddRange(scan(loraRoot).Select(f => f.Substring(loraRoot.Length).TrimStart('\\')).OrderBy(x => x));
        }
        Log("LoRAs found: " + cachedLoras.Count);
        // ControlNet
        string cnRoot = Path.Combine(mr, "controlnet");
        cachedControlNets = new List<string>();
        if (Directory.Exists(cnRoot)) {
            cachedControlNets.AddRange(scan(cnRoot).Select(f => f.Substring(cnRoot.Length).TrimStart('\\')).OrderBy(x => x));
        }
        Log("ControlNet models found: " + cachedControlNets.Count);
        Log("Model scan complete.");
    }

    private void PopulateCombos() {
        PopulateLabTypeStyle();
        FilterLabCheckpoints();
        if (comboLora != null) {
            comboLora.Items.Clear(); comboLora.Items.Add("None");
            if (cachedLoras != null) {
                foreach (var f in cachedLoras) comboLora.Items.Add(f);
            }
            comboLora.SelectedIndex = 0;
        }
        if (comboCNModel != null) {
            comboCNModel.Items.Clear(); comboCNModel.Items.Add("None");
            if (cachedControlNets != null) {
                foreach (var f in cachedControlNets) comboCNModel.Items.Add(f);
            }
            if (comboCNModel.Items.Count > 0) comboCNModel.SelectedIndex = 0;
        }
    }

    private void PopulateLabTypeStyle() {
        if (comboCheckpointStyle == null) return;
        bool isCkpt = comboModelSource == null || comboModelSource.SelectedIndex == 0;
        comboCheckpointStyle.Items.Clear();
        comboCheckpointStyle.Items.Add("All");
        var subs = isCkpt ? cachedCheckpointSubfolders : cachedDiffusionSubfolders;
        if (subs != null) { foreach (var f in subs) comboCheckpointStyle.Items.Add(f); }
        if (comboCheckpointStyle.Items.Count > 0) comboCheckpointStyle.SelectedIndex = 0;
    }

    private void FilterLabCheckpoints() {
        if (comboCheckpoint == null) return;
        bool isCkpt = comboModelSource == null || comboModelSource.SelectedIndex == 0;
        var allFiles = isCkpt ? cachedCheckpoints : cachedDiffusionModels;
        var byFolder = isCkpt ? cachedCheckpointsByFolder : cachedDiffusionByFolder;
        string sel = comboCheckpointStyle.SelectedItem != null ? comboCheckpointStyle.SelectedItem.ToString() : "All";
        comboCheckpoint.Items.Clear(); comboCheckpoint.Items.Add("None");
        if (sel == "All") {
            if (allFiles != null) { foreach (var f in allFiles) comboCheckpoint.Items.Add(f); }
        } else if (byFolder != null && byFolder.ContainsKey(sel)) {
            foreach (var f in byFolder[sel]) comboCheckpoint.Items.Add(f);
        }
        if (comboCheckpoint.Items.Count > 1) comboCheckpoint.SelectedIndex = 1;
        else if (comboCheckpoint.Items.Count > 0) comboCheckpoint.SelectedIndex = 0;
    }

    private void LoadPrefs() { }
    private void SavePrefs() {
        SaveDefaultConfig();
    }
    private void ToggleSession() {
        sessionActive = !sessionActive;
        btnSession.Text = sessionActive ? "[ STOP SESSION ]" : "[ START SESSION ]";
        btnSession.BackColor = sessionActive ? Color.FromArgb(180, 40, 40) : Color.FromArgb(34, 120, 64);
        if (sessionActive) {
            CaptureMetadata();
            Log("Session started.");
        } else {
            Log("Session stopped. " + sessionEntries.Count + " entries captured.");
        }
    }
    private void SetProgressLab(int pct, string text) {
        if (progressBar != null && !progressBar.IsDisposed) { progressBar.Value = pct; }
        if (lblProgressStatus != null && !lblProgressStatus.IsDisposed) { lblProgressStatus.Text = text; }
    }

    private void OnGenerate() {
        try {
            SetProgressLab(0, "Starting...");
            Log("Starting generation..."); btnGenerate.Enabled = false;
            string prompt = txtPrompt.Text;
            if (string.IsNullOrWhiteSpace(prompt)) { Log("ERROR: Prompt is empty."); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            int seed; int.TryParse(txtSeed.Text, out seed);
            if (chkRandomSeed.Checked) { seed = new Random().Next(1, int.MaxValue); txtSeed.Text = seed.ToString(); }
            string cUrl = @"http://127.0.0.1:8000";
            SetProgressLab(5, "Connecting to ComfyUI...");
            try { var req = (HttpWebRequest)WebRequest.Create(cUrl + "/system_stats"); req.Timeout = 1000; using (var sysResp = (HttpWebResponse)req.GetResponse()) { } Log("ComfyUI connected at " + cUrl); }
            catch { Log("ERROR: ComfyUI not reachable at " + cUrl); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            string labRoot = Path.GetDirectoryName(Application.ExecutablePath);
            string projectRoot = Path.GetFullPath(Path.Combine(labRoot, ".."));
            SetProgressLab(10, "Loading workflow...");
            string wfPath = Path.Combine(projectRoot, "comfyui", "workflows", "sdxl-basic-book-image.api.json");
            if (!File.Exists(wfPath)) { Log("ERROR: Workflow not found at " + wfPath); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            string wfJson = File.ReadAllText(wfPath);
            var wf = json.Deserialize<Dictionary<string, object>>(wfJson);
            if (wf == null) { Log("ERROR: Could not parse workflow JSON"); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            SetWfNode(wf, "4", "text", txtPrompt.Text);
            SetWfNode(wf, "5", "text", txtNegative.Text);
            SetWfNode(wf, "6", "width", (int)numWidth.Value);
            SetWfNode(wf, "6", "height", (int)numHeight.Value);
            SetWfNode(wf, "7", "seed", seed);
            SetWfNode(wf, "7", "steps", (int)numSteps.Value);
            SetWfNode(wf, "7", "cfg", (double)numCfg.Value);
            SetWfNode(wf, "7", "sampler_name", comboSampler.SelectedItem != null ? comboSampler.SelectedItem.ToString() : "euler");
            SetWfNode(wf, "7", "scheduler", comboScheduler.SelectedItem != null ? comboScheduler.SelectedItem.ToString() : "normal");
            // Wire selected checkpoint into node 3
            string ckptValue = comboCheckpoint.SelectedItem != null && comboCheckpoint.SelectedItem.ToString() != "None" ? comboCheckpoint.SelectedItem.ToString() : "";
            if (!string.IsNullOrEmpty(ckptValue)) {
                SetWfNode(wf, "3", "ckpt_name", ckptValue);
                Log("Checkpoint: " + ckptValue);
            }
            // Wire selected LoRA if enabled and not None
            string loraValue = comboLora.SelectedItem != null ? comboLora.SelectedItem.ToString() : "";
            bool useLora = chkLora.Checked && loraValue != "" && loraValue != "None";
            if (useLora) {
                // Dynamically add LoraLoader node between checkpoint and KSampler/CLIPTextEncode
                string loraNodeId = "10";
                double loraStrength = (double)numLora.Value;
                var loraNode = new Dictionary<string, object>();
                loraNode["class_type"] = "LoraLoader";
                var loraInputs = new Dictionary<string, object>();
                loraInputs["model"] = new ArrayList { "3", 0 };
                loraInputs["clip"] = new ArrayList { "3", 1 };
                loraInputs["lora_name"] = loraValue;
                loraInputs["strength_model"] = loraStrength;
                loraInputs["strength_clip"] = loraStrength;
                loraNode["inputs"] = loraInputs;
                wf[loraNodeId] = loraNode;
                // Rewire KSampler model input to LoRA node output
                SetWfLink(wf, "7", "model", loraNodeId, 0);
                // Rewire CLIPTextEncode clip inputs to LoRA node output
                SetWfLink(wf, "4", "clip", loraNodeId, 1);
                SetWfLink(wf, "5", "clip", loraNodeId, 1);
                Log("LoRA: " + loraValue + " @ " + loraStrength.ToString("0.00"));
            }
            SetProgressLab(15, "Sending to ComfyUI...");
            var payload = new Dictionary<string, object>(); payload["prompt"] = wf;
            string payloadJson = json.Serialize(payload);
            // Diagnostic: save outgoing payload after all UI mappings and LoRA injection
            try { File.WriteAllText(@"C:\Users\Michael\Documents\Leonardo Prompts\Lab_Last_ComfyUI_Payload.json", payloadJson); } catch { }
            Log("Sending to ComfyUI...");
            var client = new WebClient(); client.Headers.Add("Content-Type", "application/json"); client.Encoding = Encoding.UTF8;
            string resp;
            try { resp = client.UploadString(cUrl + "/prompt", payloadJson); }
            catch (Exception ex) { Log("HTTP error: " + ex.Message); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            var respObj = json.Deserialize<Dictionary<string, object>>(resp);
            string promptId = respObj != null && respObj.ContainsKey("prompt_id") ? Convert.ToString(respObj["prompt_id"]) : "";
            if (string.IsNullOrEmpty(promptId)) { Log("No prompt_id in response"); btnGenerate.Enabled = true; SetProgressLab(0, ""); return; }
            Log("Queued. Prompt ID: " + promptId);
            SetProgressLab(20, "Execution started");
            string outputPath = @"C:\Users\Michael\Documents\ComfyUI\output";
            string imagePath = "";
            int totalWaitSec = 180;
            DateTime startTime = DateTime.Now;
            for (int i = 0; i < totalWaitSec; i++) {
                System.Threading.Thread.Sleep(1000);
                double elapsedRatio = (double)(i + 1) / totalWaitSec;
                int pct = 20 + (int)(elapsedRatio * 75);
                if (pct > 95) pct = 95;
                SetProgressLab(pct, "Processing " + pct + "%");
                Application.DoEvents();
                try {
                    var hc = new WebClient(); hc.Encoding = Encoding.UTF8;
                    string historyJson = hc.DownloadString(cUrl + "/history/" + promptId);
                    var history = json.Deserialize<Dictionary<string, object>>(historyJson);
                    if (history != null && history.ContainsKey(promptId)) {
                        var entry = history[promptId] as Dictionary<string, object>;
                        if (entry != null && entry.ContainsKey("outputs")) {
                            var outputs = entry["outputs"] as Dictionary<string, object>;
                            if (outputs != null) {
                                foreach (var kv5 in outputs) {
                                    var kv2 = kv5.Value as Dictionary<string, object>;
                                    if (kv2 != null && kv2.ContainsKey("images") && kv2["images"] is ArrayList) {
                                        var images = (ArrayList)kv2["images"];
                                        if (images.Count > 0) {
                                            var img = images[0] as Dictionary<string, object>;
                                            if (img != null && img.ContainsKey("filename")) {
                                                imagePath = Path.Combine(outputPath, Convert.ToString(img["filename"]));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (!string.IsNullOrEmpty(imagePath)) break;
                    }
                } catch { }
            }
            if (!string.IsNullOrEmpty(imagePath) && File.Exists(imagePath)) {
                Log("Generated: " + imagePath);
                SetPreview(imagePath);
                Application.DoEvents();
                SetProgressLab(100, "Complete");
                gridOutputs.Rows.Insert(0, DateTime.Now.ToString("HH:mm:ss"), Path.GetFileName(imagePath),
                    (comboLora.SelectedItem != null ? comboLora.SelectedItem.ToString() : ""),
                    numLora.Value.ToString("0.00"), numSteps.Value.ToString(), numCfg.Value.ToString("0.0"),
                    seed.ToString(), imagePath);
            } else { Log("Generation completed but output image not found in " + outputPath); SetProgressLab(0, ""); }
        } catch (Exception ex) { Log("Generation error: " + ex.Message); }
        finally { btnGenerate.Enabled = true; }
    }
    private void SetWfNode(Dictionary<string, object> wf, string nodeId, string key, object value) {
        if (!wf.ContainsKey(nodeId)) return;
        var node = wf[nodeId] as Dictionary<string, object>;
        if (node == null) return;
        if (!node.ContainsKey("inputs")) { node["inputs"] = new Dictionary<string, object>(); }
        var nodeInputs = node["inputs"] as Dictionary<string, object>;
        if (nodeInputs == null) return;
        nodeInputs[key] = value;
    }
    private void SetWfLink(Dictionary<string, object> wf, string nodeId, string key, string sourceNodeId, int sourceSlot) {
        if (!wf.ContainsKey(nodeId)) return;
        var node = wf[nodeId] as Dictionary<string, object>;
        if (node == null) return;
        if (!node.ContainsKey("inputs")) { node["inputs"] = new Dictionary<string, object>(); }
        var nodeInputs = node["inputs"] as Dictionary<string, object>;
        if (nodeInputs == null) return;
        nodeInputs[key] = new ArrayList { sourceNodeId, sourceSlot };
    }
    protected override void OnFormClosing(FormClosingEventArgs e) {
        SaveDefaultConfig();
        if (labWorkerProcess != null && !labWorkerProcess.HasExited) {
            try { labWorkerProcess.Kill(); labWorkerProcess.WaitForExit(2000); } catch { }
        }
        SavePrefs();
        base.OnFormClosing(e);
    }
    private void Log(string msg) { if (logBox != null && !logBox.IsDisposed) { logBox.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + "\r\n"); logBox.SelectionStart = logBox.TextLength; logBox.ScrollToCaret(); } }
    private void DumpSeedDiagnostic() {
        try {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("=== Seed Overlay Diagnostic ===");
            sb.AppendLine("Date: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            sb.AppendLine();
            sb.AppendLine("Seed txtSeed:");
            sb.AppendLine("  Type: " + txtSeed.GetType().Name);
            sb.AppendLine("  Bounds: " + txtSeed.Bounds.ToString());
            sb.AppendLine("  Text: '" + txtSeed.Text + "'");
            sb.AppendLine("  BackColor: " + txtSeed.BackColor);
            sb.AppendLine("  ForeColor: " + txtSeed.ForeColor);
            sb.AppendLine("  Visible: " + txtSeed.Visible);
            sb.AppendLine("  Enabled: " + txtSeed.Enabled);
            sb.AppendLine("  Parent: " + (txtSeed.Parent != null ? txtSeed.Parent.GetType().Name : "null"));
            sb.AppendLine();
            sb.AppendLine("All controls in tabMain (Generation tab):");
            sb.AppendLine("Index | Name | Type | Bounds | Text | BackColor | ForeColor | Visible | Enabled");
            for (int i = 0; i < tabMain.Controls.Count; i++) {
                var c = tabMain.Controls[i];
                string cname = "";
                try { cname = c.Name; } catch { }
                string ctext = "";
                try { ctext = c.Text; } catch { }
                string ctype = c.GetType().Name;
                string canme = "";
                foreach (var f in this.GetType().GetFields(System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)) {
                    if (f.FieldType == c.GetType() && object.ReferenceEquals(f.GetValue(this), c)) { canme = f.Name; break; }
                }
                sb.AppendLine(string.Format("{0} | {1} | {2} | {3} | '{4}' | {5} | {6} | {7} | {8}",
                    i, canme.PadRight(20), ctype.PadRight(15), c.Bounds.ToString().PadRight(30),
                    (ctext.Length > 40 ? ctext.Substring(0, 40) : ctext),
                    c.BackColor, c.ForeColor, c.Visible, c.Enabled));
            }
            sb.AppendLine();
            // Check all controls for overlap with txtSeed
            var seedRect = txtSeed.Bounds;
            sb.AppendLine("Controls overlapping txtSeed (Bounds.IntersectsWith):");
            bool anyOverlap = false;
            for (int i = 0; i < tabMain.Controls.Count; i++) {
                var c = tabMain.Controls[i];
                if (c == txtSeed) continue;
                if (c.Bounds.IntersectsWith(seedRect)) {
                    anyOverlap = true;
                    sb.AppendLine(string.Format("  {0} ({1}) bounds={2} overlaps txtSeed", c.GetType().Name, c.Text, c.Bounds));
                }
            }
            if (!anyOverlap) sb.AppendLine("  None — no controls intersect txtSeed bounds");
            sb.AppendLine();
            sb.AppendLine("Controls within 10px of txtSeed:");
            var expandedRect = new System.Drawing.Rectangle(seedRect.X - 10, seedRect.Y - 10, seedRect.Width + 20, seedRect.Height + 20);
            for (int i = 0; i < tabMain.Controls.Count; i++) {
                var c = tabMain.Controls[i];
                if (c == txtSeed) continue;
                if (c.Bounds.IntersectsWith(expandedRect)) {
                    sb.AppendLine(string.Format("  {0} ({1}) bounds={2}", c.GetType().Name, c.Text, c.Bounds));
                }
            }
            sb.AppendLine();
            sb.AppendLine("=== End Diagnostic ===");
            string diagPath = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "seed_diagnostic.txt");
            File.WriteAllText(diagPath, sb.ToString());
            Log("Seed diagnostic written to " + diagPath);
        } catch (Exception ex) { Log("Diagnostic error: " + ex.Message); }
    }
}

static class LabelExtensions {
    public static Label WithFont(this Label lbl, float size) { lbl.Font = new Font("Segoe UI", size); return lbl; }
    public static Label WithColor(this Label lbl, Color color) { lbl.ForeColor = color; return lbl; }
}

class Program {
    [STAThread]
    static void Main() {
        Application.EnableVisualStyles();
        Application.Run(new LabForm());
    }
}

