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

public class ForgeForm : Form {
    private TabControl tabs;
    private TabPage tabMain, tabModel, tabCN, tabSession;
    private TextBox txtPrompt, txtNegative, txtOutfit, txtLog;
    private ComboBox comboLora1, comboLora2, comboLora3, comboSampler, comboScheduler;
    private ComboBox comboCheckpoint, comboCNModel, comboCNImage, comboCNFilter, comboWorkflow;
    private ComboBox comboOutCat, comboOutItem, comboOutColor, comboOutMat, comboOutPreset, comboOutfitPlacement;
    private NumericUpDown numLora1Str, numLora2Str, numLora3Str, numSeed, numSteps, numCfg, numWidth, numHeight;
    private NumericUpDown numCNStrength, numCNStart, numCNEnd;
    private CheckBox chkLora1, chkLora2, chkLora3, chkRandomSeed, chkCN, chkIncludePrompts, chkEnableOutfit;
    private Button btnGenerate, btnRefresh, btnOutput, btnSession, btnOpenReport, btnRefreshLists;
    private PictureBox previewBox;
    private DataGridView gridOutputs;
    private Panel previewPanel;
    private Label lblGpuStatus;
    private Timer gpuTimer;
    private bool sessionActive = false;
    private List<Dictionary<string, object>> sessionEntries = new List<Dictionary<string, object>>();
    private string forgeRoot, configPath, prefsPath, runLogPath, reportsFolder;
    private Dictionary<string, object> config;
    private JavaScriptSerializer json = new JavaScriptSerializer();
    private string comfyUrl = "http://127.0.0.1:8000";
    private string comfyOutputPath = @"C:\Users\Michael\Documents\ComfyUI\output";

    public ForgeForm() {
        forgeRoot = Path.GetDirectoryName(Application.ExecutablePath);
        configPath = Path.Combine(forgeRoot, "Forge.config.json");
        prefsPath = Path.Combine(forgeRoot, "Forge.prefs.json");
        runLogPath = Path.Combine(forgeRoot, "Forge.runlog.json");
        reportsFolder = @"C:\Users\Michael\Documents\ComfyUI\Reports";
        Directory.CreateDirectory(reportsFolder);
        LoadConfig();

        this.Text = "Character Forge";
        this.WindowState = FormWindowState.Maximized;
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Forge.ico";
        if (File.Exists(iconPath)) { try { this.Icon = new Icon(iconPath); } catch { } }

        var right = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(8), ColumnCount = 1, RowCount = 2 };
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 65));
        right.RowStyles.Add(new RowStyle(SizeType.Percent, 35));
        this.Controls.Add(right);
        var left = new Panel { Dock = DockStyle.Left, Width = 640, Padding = new Padding(6) };
        this.Controls.Add(left);
        tabs = new TabControl { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 8.5f) };
        left.Controls.Add(tabs);
        var actionBar = new Panel { Dock = DockStyle.Bottom, Height = 48, BackColor = Color.FromArgb(45, 45, 52) };
        left.Controls.Add(actionBar);

        btnGenerate = MakeButton("Generate", 4, 8, 90, 32, Color.FromArgb(40, 120, 60));
        txtLog = new TextBox { Left = 6, Top = 4, Width = 620, Height = 130, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(180, 220, 180), Font = new Font("Consolas", 8.5f) };
        bgWorker = new System.ComponentModel.BackgroundWorker();
        bgWorker.DoWork += BgWorker_DoWork;
        btnGenerate.Click += (o, e) => { if (!bgWorker.IsBusy) bgWorker.RunWorkerAsync(); else Log("Already generating."); };
        actionBar.Controls.Add(btnGenerate);

        btnRefresh = MakeButton("Refresh Models", 98, 8, 90, 32, Color.FromArgb(50, 50, 60));
        btnRefresh.Click += (o, e) => LoadModels();
        actionBar.Controls.Add(btnRefresh);

        btnOutput = MakeButton("Open Output", 192, 8, 80, 32, Color.FromArgb(50, 50, 60));
        btnOutput.Click += (o, e) => { if (Directory.Exists(comfyOutputPath)) System.Diagnostics.Process.Start(comfyOutputPath); };
        actionBar.Controls.Add(btnOutput);

        btnSession = MakeButton("[ START SESSION ]", 276, 8, 86, 32, Color.FromArgb(34, 120, 64));
        btnSession.Font = new Font("Segoe UI", 8, FontStyle.Bold);
        btnSession.Click += (o, e) => ToggleSession();
        actionBar.Controls.Add(btnSession);

        btnOpenReport = MakeButton("Reports", 366, 8, 56, 32, Color.FromArgb(50, 50, 60));
        btnOpenReport.Click += (o, e) => { if (Directory.Exists(reportsFolder)) System.Diagnostics.Process.Start(reportsFolder); };
        actionBar.Controls.Add(btnOpenReport);

        chkIncludePrompts = new CheckBox { Text = "Include prompts", Left = 426, Top = 10, Width = 120, Height = 22, ForeColor = Color.FromArgb(200, 200, 210), Font = new Font("Segoe UI", 7.5f) };
        actionBar.Controls.Add(chkIncludePrompts);

        tabMain = new TabPage("Composition") { Padding = new Padding(6), AutoScroll = true };
        tabSession = new TabPage("Session") { Padding = new Padding(6) };
        tabs.TabPages.Add(tabMain); tabs.TabPages.Add(tabSession);

        BuildCompTab(); BuildSessionTab();
        previewPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(18, 18, 24) };
        right.Controls.Add(previewPanel);
        previewBox = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom };
        previewPanel.Controls.Add(previewBox);
        gridOutputs = new DataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = false, ReadOnly = true, RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.FromArgb(16, 16, 22), ForeColor = Color.FromArgb(200, 200, 210), BorderStyle = BorderStyle.None };
        gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA1", "LoRA1"); gridOutputs.Columns.Add("LoRA2", "LoRA2"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path");
        gridOutputs.Columns[5].Visible = false;
        gridOutputs.CellClick += (o, ev) => { if (ev.RowIndex >= 0 && gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value != null) SetPreview(gridOutputs.Rows[ev.RowIndex].Cells["Path"].Value.ToString()); };
        right.Controls.Add(gridOutputs);

        // GPU status bar
        lblGpuStatus = new Label { Dock = DockStyle.Bottom, Height = 22, BackColor = Color.FromArgb(28, 28, 38), ForeColor = Color.FromArgb(150, 200, 150), Font = new Font("Segoe UI", 7.5f), Padding = new Padding(8, 3, 0, 0) };
        this.Controls.Add(lblGpuStatus);
        lblGpuStatus.BringToFront();
        string logsDir = Path.Combine(forgeRoot, "logs"); Directory.CreateDirectory(logsDir);
        GpuStatusProvider.SetLogDir(logsDir);
        GpuStatusProvider.SetComfyUrl("http://127.0.0.1:8000");
        UpdateGpuBar();
        gpuTimer = new Timer { Interval = 5000 }; gpuTimer.Tick += (o, e) => UpdateGpuBar(); gpuTimer.Start();

        LoadModels(); LoadPrefs(); Log("Character Forge ready.");
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

    private System.ComponentModel.BackgroundWorker bgWorker;
    private void BgWorker_DoWork(object sender, System.ComponentModel.DoWorkEventArgs e) {
        try {
            Invoke((Action)(() => { Log("Starting generation..."); btnGenerate.Enabled = false; }));
            string prompt = txtPrompt.Text;
            if (string.IsNullOrWhiteSpace(prompt)) { Invoke((Action)(() => Log("ERROR: Prompt is empty."))); return; }
            // Resolve seed
            int seed = (int)numSeed.Value;
            if (chkRandomSeed.Checked) { seed = new Random().Next(1, int.MaxValue); Invoke((Action)(() => numSeed.Value = seed)); }
            // Load config comfyUrl if available
            string cUrl = comfyUrl;
            if (config != null && config.ContainsKey("comfyUrl")) { cUrl = Convert.ToString(config["comfyUrl"]); }
            // Check ComfyUI
            try { var wc = new WebClient(); wc.Headers.Add("User-Agent", "Forge/1.0"); wc.DownloadString(cUrl + "/system_stats"); Invoke((Action)(() => Log("ComfyUI connected at " + cUrl))); }
            catch { Invoke((Action)(() => { Log("ERROR: ComfyUI not reachable at " + cUrl); })); return; }
            // Load workflow
            string forgeRoot = Path.GetDirectoryName(Application.ExecutablePath);
            string projectRoot = Path.GetFullPath(Path.Combine(forgeRoot, ".."));
            string wfPath = Path.Combine(projectRoot, "comfyui", "workflows", "sdxl-basic-book-image.api.json");
            if (config != null && config.ContainsKey("workflowPath")) { string wp = Convert.ToString(config["workflowPath"]); if (Path.IsPathRooted(wp)) wfPath = wp; else wfPath = Path.Combine(projectRoot, wp); }
            if (!File.Exists(wfPath)) { Invoke((Action)(() => Log("ERROR: Workflow not found at " + wfPath))); return; }
            string wfJson = File.ReadAllText(wfPath);
            var wf = json.Deserialize<Dictionary<string, object>>(wfJson);
            if (wf == null) { Invoke((Action)(() => Log("ERROR: Could not parse workflow JSON"))); return; }
            // Modify workflow nodes (matching PowerShell invoke script pattern)
            SetWfNode(wf, "4", "text", txtPrompt.Text);
            SetWfNode(wf, "5", "text", txtNegative.Text);
            SetWfNode(wf, "6", "width", (int)numWidth.Value);
            SetWfNode(wf, "6", "height", (int)numHeight.Value);
            SetWfNode(wf, "7", "seed", seed);
            SetWfNode(wf, "7", "steps", (int)numSteps.Value);
            SetWfNode(wf, "7", "cfg", (double)numCfg.Value);
            SetWfNode(wf, "7", "sampler_name", comboSampler.SelectedItem != null ? comboSampler.SelectedItem.ToString() : "euler");
            SetWfNode(wf, "7", "scheduler", comboScheduler.SelectedItem != null ? comboScheduler.SelectedItem.ToString() : "normal");
            // Send to ComfyUI
            var payload = new Dictionary<string, object>(); payload["prompt"] = wf;
            string payloadJson = json.Serialize(payload);
            Invoke((Action)(() => Log("Sending to ComfyUI...")));
            var client = new WebClient(); client.Headers.Add("Content-Type", "application/json"); client.Encoding = Encoding.UTF8;
            string resp;
            try { resp = client.UploadString(cUrl + "/prompt", payloadJson); } catch (Exception ex) { Invoke((Action)(() => Log("HTTP error: " + ex.Message))); return; }
            var respObj = json.Deserialize<Dictionary<string, object>>(resp);
            string promptId = respObj != null && respObj.ContainsKey("prompt_id") ? Convert.ToString(respObj["prompt_id"]) : "";
            if (string.IsNullOrEmpty(promptId)) { Invoke((Action)(() => Log("No prompt_id in response: " + (resp.Length > 200 ? resp.Substring(0, 200) : resp)))); return; }
            Invoke((Action)(() => Log("Queued. Prompt ID: " + promptId)));
            // Poll for completion
            string outputPath = comfyOutputPath;
            string imagePath = "";
            for (int i = 0; i < 180; i++) {
                System.Threading.Thread.Sleep(1000);
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
                                        if (images != null && images.Count > 0) {
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
                string finalPath = imagePath;
                Invoke((Action)(() => { Log("Generated: " + finalPath); SetPreview(finalPath); gridOutputs.Rows.Insert(0, DateTime.Now.ToString("HH:mm:ss"), Path.GetFileName(finalPath), (comboLora1.SelectedItem != null ? comboLora1.SelectedItem.ToString() : ""), seed.ToString(), finalPath); }));
            } else { Invoke((Action)(() => Log("Generation completed but output image not found in " + outputPath))); }
        } catch (Exception ex) { Invoke((Action)(() => Log("Generation error: " + ex.Message))); }
        finally { Invoke((Action)(() => { btnGenerate.Enabled = true; })); }
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

    private Button MakeButton(string t, int x, int y, int w, int h, Color bg) { return new Button { Text = t, Left = x, Top = y, Width = w, Height = h, BackColor = bg, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, FlatAppearance = { BorderSize = 0 } }; }
    private Label Lbl(string t, int x, int y, int w = 100, int h = 18) { return new Label { Text = t, Left = x, Top = y, Width = w, Height = h }; }
    private void Log(string msg) { string ts = DateTime.Now.ToString("HH:mm:ss"); txtLog.AppendText("[" + ts + "] " + msg + "\r\n"); txtLog.SelectionStart = txtLog.TextLength; txtLog.ScrollToCaret(); }
    private void SetPreview(string path) { if (string.IsNullOrEmpty(path) || !File.Exists(path)) return; try { if (previewBox.Image != null) previewBox.Image.Dispose(); previewBox.Image = Image.FromFile(path); } catch { } }
    private string Cfg(string key) { if (config != null && config.ContainsKey(key)) return Convert.ToString(config[key]); return ""; }

    private void LoadConfig() {
        if (!File.Exists(configPath)) return;
        try { config = json.Deserialize<Dictionary<string, object>>(File.ReadAllText(configPath)); } catch { config = null; }
    }

    private void BuildCompTab() {
        int y = 4;
        int cw = 450; // control width
        tabMain.Controls.Add(Lbl("Prompt", 8, y));
        txtPrompt = new TextBox { Left = 8, Top = y + 18, Width = cw, Height = 55, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = Cfg("prompt") };
        tabMain.Controls.Add(txtPrompt); y += 80;
        tabMain.Controls.Add(Lbl("Negative prompt", 8, y));
        txtNegative = new TextBox { Left = 8, Top = y + 18, Width = cw, Height = 45, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = Cfg("negativePrompt") };
        tabMain.Controls.Add(txtNegative); y += 70;
        // LoRA 1
        tabMain.Controls.Add(Lbl("LoRA 1", 8, y + 2, 50));
        comboLora1 = MakeCombo(60, y, 220); comboLora1.Items.Add("None");
        chkLora1 = new CheckBox { Text = "Use", Left = 286, Top = y + 2, Width = 40 };
        numLora1Str = new NumericUpDown { Left = 330, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.80m };
        tabMain.Controls.Add(comboLora1); tabMain.Controls.Add(chkLora1); tabMain.Controls.Add(numLora1Str); y += 24;
        // LoRA 2
        tabMain.Controls.Add(Lbl("LoRA 2", 8, y + 2, 50));
        comboLora2 = MakeCombo(60, y, 220); comboLora2.Items.Add("None");
        chkLora2 = new CheckBox { Text = "Use", Left = 286, Top = y + 2, Width = 40 };
        numLora2Str = new NumericUpDown { Left = 330, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.65m };
        tabMain.Controls.Add(comboLora2); tabMain.Controls.Add(chkLora2); tabMain.Controls.Add(numLora2Str); y += 24;
        // LoRA 3
        tabMain.Controls.Add(Lbl("LoRA 3", 8, y + 2, 50));
        comboLora3 = MakeCombo(60, y, 220); comboLora3.Items.Add("None");
        chkLora3 = new CheckBox { Text = "Use", Left = 286, Top = y + 2, Width = 40 };
        numLora3Str = new NumericUpDown { Left = 330, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.50m };
        tabMain.Controls.Add(comboLora3); tabMain.Controls.Add(chkLora3); tabMain.Controls.Add(numLora3Str); y += 30;
        // Row 1: Seed, Random, Width, Height
        tabMain.Controls.Add(Lbl("Seed", 8, y));
        numSeed = new NumericUpDown { Left = 50, Top = y, Width = 80, Maximum = int.MaxValue, Minimum = 1, Value = new Random().Next(1, int.MaxValue), BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numSeed);
        chkRandomSeed = new CheckBox { Text = "Random", Left = 138, Top = y, Width = 70, Height = 18, Checked = true };
        chkRandomSeed.CheckedChanged += (o, e) => { if (!chkRandomSeed.Checked) { numSeed.ForeColor = Color.Black; numSeed.BackColor = Color.White; } };
        tabMain.Controls.Add(chkRandomSeed);
        tabMain.Controls.Add(Lbl("Width", 220, y));
        numWidth = new NumericUpDown { Left = 220, Top = y + 18, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numWidth);
        tabMain.Controls.Add(new Label { Text = "x", Left = 292, Top = y + 20, Width = 12 });
        numHeight = new NumericUpDown { Left = 304, Top = y + 18, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numHeight);
        tabMain.Controls.Add(Lbl("Height", 376, y));
        y += 44;
        // Row 2: Steps, CFG, Sampler, Scheduler
        tabMain.Controls.Add(Lbl("Steps", 8, y));
        numSteps = new NumericUpDown { Left = 8, Top = y + 18, Width = 60, Minimum = 1, Maximum = 150, Value = 30, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numSteps);
        tabMain.Controls.Add(Lbl("CFG", 80, y));
        numCfg = new NumericUpDown { Left = 80, Top = y + 18, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 6, BackColor = Color.White, ForeColor = Color.Black };
        tabMain.Controls.Add(numCfg);
        tabMain.Controls.Add(Lbl("Sampler", 160, y));
        comboSampler = MakeCombo(160, y + 18, 120); comboSampler.Items.AddRange(new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }); comboSampler.SelectedIndex = 0;
        tabMain.Controls.Add(comboSampler);
        tabMain.Controls.Add(Lbl("Scheduler", 300, y));
        comboScheduler = MakeCombo(300, y + 18, 120); comboScheduler.Items.AddRange(new[] { "karras", "exponential", "simple", "normal" }); comboScheduler.SelectedIndex = 0;
        tabMain.Controls.Add(comboScheduler); y += 44;
        // Workflow Preset
        tabMain.Controls.Add(Lbl("Workflow Preset", 8, y));
        comboWorkflow = MakeCombo(8, y + 18, 300); comboWorkflow.Items.Add("Standard"); comboWorkflow.SelectedIndex = 0;
        tabMain.Controls.Add(comboWorkflow); y += 46;
        // Models group box
        var modelBox = new GroupBox { Text = "Models", Left = 6, Top = y, Width = 460, Height = 80 };
        tabMain.Controls.Add(modelBox); int my = 20;
        modelBox.Controls.Add(Lbl("Checkpoint", 8, my));
        comboCheckpoint = MakeCombo(8, my + 18, 300); comboCheckpoint.Items.Add("None"); comboCheckpoint.SelectedIndex = 0;
        modelBox.Controls.Add(comboCheckpoint); y += 56;
        // ControlNet group box
        y += 4;
        var cnBox = new GroupBox { Text = "ControlNet", Left = 6, Top = y, Width = 460, Height = 170 };
        tabMain.Controls.Add(cnBox); int cy = 20;
        chkCN = new CheckBox { Text = "Enable", Left = 8, Top = cy, Width = 100, Height = 22 };
        cnBox.Controls.Add(chkCN); cy += 26;
        cnBox.Controls.Add(Lbl("Model", 8, cy));
        comboCNModel = MakeCombo(8, cy + 18, 250); comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        cnBox.Controls.Add(comboCNModel); cy += 44;
        cnBox.Controls.Add(Lbl("Input Image", 8, cy));
        comboCNImage = MakeCombo(8, cy + 18, 300); comboCNImage.Items.Add("None"); comboCNImage.SelectedIndex = 0;
        cnBox.Controls.Add(comboCNImage); cy += 44;
        cnBox.Controls.Add(Lbl("Preprocessor", 8, cy));
        comboCNFilter = MakeCombo(8, cy + 18, 200); comboCNFilter.Items.AddRange(new[] { "None", "Canny", "Depth", "OpenPose" }); comboCNFilter.SelectedIndex = 0;
        cnBox.Controls.Add(comboCNFilter); cy += 44;
        cnBox.Controls.Add(Lbl("Strength", 8, cy));
        numCNStrength = new NumericUpDown { Left = 8, Top = cy + 18, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1 };
        cnBox.Controls.Add(numCNStrength);
        cnBox.Controls.Add(Lbl("Start / End", 100, cy));
        numCNStart = new NumericUpDown { Left = 100, Top = cy + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m };
        cnBox.Controls.Add(numCNStart);
        cnBox.Controls.Add(new Label { Text = "to", Left = 164, Top = cy + 20, Width = 20 });
        numCNEnd = new NumericUpDown { Left = 184, Top = cy + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1 };
        cnBox.Controls.Add(numCNEnd);
    }

    private void BuildSessionTab() { tabSession.Controls.Add(txtLog); }

    private string FormatStats(string json) {
        try { var jss = new JavaScriptSerializer(); var d = jss.Deserialize<Dictionary<string, object>>(json); if (d == null) return "GPU: Unknown";
            var sys = d.ContainsKey("system") ? d["system"] as Dictionary<string, object> : null; if (sys == null) return "GPU: Unknown";
            var devs = sys.ContainsKey("devices") ? sys["devices"] as ArrayList : null; if (devs == null || devs.Count == 0) return "GPU: Unknown";
            var dev = devs[0] as Dictionary<string, object>; if (dev == null) return "GPU: Unknown";
            long total = dev.ContainsKey("vram_total") ? Convert.ToInt64(dev["vram_total"]) : 0;
            long free = dev.ContainsKey("vram_free") ? Convert.ToInt64(dev["vram_free"]) : 0;
            return "GPU: " + dev["name"] + "\nVRAM Total: " + Fmt(total) + "\nVRAM Free: " + Fmt(free) + "\nVRAM Used: " + Fmt(total - free);
        } catch { return "GPU: Unknown"; }
    }

    private string Fmt(long b) { return (b / (1024.0 * 1024.0 * 1024.0)).ToString("0.00") + " GB"; }

    private void LoadModels() {
        string mr = @"C:\Users\Michael\Documents\ComfyUI\models";
        Log("Model root: " + mr);
        // Scan checkpoints
        string ckptRoot = Path.Combine(mr, "checkpoints");
        comboCheckpoint.Items.Clear(); comboCheckpoint.Items.Add("None");
        if (Directory.Exists(ckptRoot)) {
            var ckpts = Directory.GetFiles(ckptRoot, "*.safetensors", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(ckptRoot, "*.ckpt", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(ckptRoot, "*.pt", SearchOption.AllDirectories))
                .OrderBy(f => f).ToArray();
            Log("Checkpoints found: " + ckpts.Length);
            foreach (var f in ckpts) {
                string rel = f.Substring(ckptRoot.Length).TrimStart('\\');
                comboCheckpoint.Items.Add(rel);
                Log("  checkpoint: " + rel);
            }
        } else { Log("Checkpoint folder not found: " + ckptRoot); }
        if (comboCheckpoint.Items.Count > 1) comboCheckpoint.SelectedIndex = 1;
        else comboCheckpoint.SelectedIndex = 0;
        Log("Selected checkpoint: " + (comboCheckpoint.SelectedItem != null ? comboCheckpoint.SelectedItem.ToString() : "None"));
        // Scan LoRAs
        string loraRoot = Path.Combine(mr, "loras");
        comboLora1.Items.Clear(); comboLora2.Items.Clear(); comboLora3.Items.Clear();
        comboLora1.Items.Add("None"); comboLora2.Items.Add("None"); comboLora3.Items.Add("None");
        if (Directory.Exists(loraRoot)) {
            var loras = Directory.GetFiles(loraRoot, "*.safetensors", SearchOption.AllDirectories)
                .Concat(Directory.GetFiles(loraRoot, "*.ckpt", SearchOption.AllDirectories))
                .Concat(Directory.GetFiles(loraRoot, "*.pt", SearchOption.AllDirectories))
                .OrderBy(f => f).ToArray();
            Log("LoRAs found: " + loras.Length);
            foreach (var f in loras) {
                string rel = f.Substring(loraRoot.Length).TrimStart('\\');
                comboLora1.Items.Add(rel); comboLora2.Items.Add(rel); comboLora3.Items.Add(rel);
            }
        } else { Log("LoRA folder not found: " + loraRoot); }
        comboLora1.SelectedIndex = comboLora2.SelectedIndex = comboLora3.SelectedIndex = 0;
    }

    private void LoadPrefs() {
        if (!File.Exists(prefsPath)) return;
        try {
            string raw = File.ReadAllText(prefsPath, Encoding.UTF8);
            var d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(raw);
            if (d != null && d.ContainsKey("WindowState")) {
                string ws = d["WindowState"].ToString();
                if (ws == "Maximized") { this.WindowState = FormWindowState.Maximized; return; }
                if (ws == "Normal" && d.ContainsKey("WindowX") && d.ContainsKey("WindowY")) {
                    int wx = Convert.ToInt32(d["WindowX"]), wy = Convert.ToInt32(d["WindowY"]);
                    int ww = d.ContainsKey("WindowW") ? Convert.ToInt32(d["WindowW"]) : 1450;
                    int wh = d.ContainsKey("WindowH") ? Convert.ToInt32(d["WindowH"]) : 980;
                    bool onScreen = false;
                    foreach (var screen in Screen.AllScreens) {
                        var r = screen.Bounds;
                        if (wx >= r.Left && wx + ww <= r.Right && wy >= r.Top && wy + wh <= r.Bottom) { onScreen = true; break; }
                    }
                    if (onScreen) { this.WindowState = FormWindowState.Normal; this.StartPosition = FormStartPosition.Manual; this.Location = new Point(wx, wy); this.Size = new Size(ww, wh); }
                }
            }
        } catch { }
    }
    private void SavePrefs() {
        try {
            var d = new Dictionary<string, object>();
            d["WindowState"] = this.WindowState.ToString();
            if (this.WindowState == FormWindowState.Normal) {
                d["WindowX"] = this.Location.X; d["WindowY"] = this.Location.Y;
                d["WindowW"] = this.Size.Width; d["WindowH"] = this.Size.Height;
            }
            File.WriteAllText(prefsPath, new JavaScriptSerializer().Serialize(d));
        } catch { }
    }

    private void ToggleSession() {
        sessionActive = !sessionActive;
        btnSession.Text = sessionActive ? "[ STOP SESSION ]" : "[ START SESSION ]";
        btnSession.BackColor = sessionActive ? Color.FromArgb(180, 40, 40) : Color.FromArgb(34, 120, 64);
    }

    private ComboBox MakeCombo(int x, int y, int w) { return new ComboBox { Left = x, Top = y, Width = w, DropDownStyle = ComboBoxStyle.DropDownList }; }
    protected override void OnFormClosing(FormClosingEventArgs e) { SavePrefs(); base.OnFormClosing(e); }
}

class Program {
    [STAThread]
    static void Main() { Application.EnableVisualStyles(); Application.Run(new ForgeForm()); }
}
