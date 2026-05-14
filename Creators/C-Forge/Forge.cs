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
    private TabPage tabMain, tabModel, tabCN, tabSession, tabGpu;
    private TextBox txtPrompt, txtNegative, txtOutfit, txtLog;
    private ComboBox comboLora1, comboLora2, comboLora3, comboSampler, comboScheduler;
    private ComboBox comboCheckpoint, comboDiffuser, comboCNModel, comboCNImage, comboCNFilter, comboWorkflow;
    private ComboBox comboOutCat, comboOutItem, comboOutColor, comboOutMat, comboOutPreset, comboOutfitPlacement;
    private NumericUpDown numLora1Str, numLora2Str, numLora3Str, numSeed, numSteps, numCfg, numWidth, numHeight;
    private NumericUpDown numCNStrength, numCNStart, numCNEnd;
    private CheckBox chkLora1, chkLora2, chkLora3, chkRandomSeed, chkCN, chkIncludePrompts, chkEnableOutfit;
    private Button btnGenerate, btnRefresh, btnOutput, btnSession, btnOpenReport, btnRefreshLists, btnRefreshGPU;
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
        this.Size = new Size(1450, 980);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Font = new Font("Segoe UI", 9);
        string iconPath = @"H:\MystikStudio\Icons\Forge.ico";
        if (File.Exists(iconPath)) this.Icon = new Icon(iconPath);

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
        tabModel = new TabPage("Models") { Padding = new Padding(6) };
        tabCN = new TabPage("ControlNet") { Padding = new Padding(6) };
        tabSession = new TabPage("Session") { Padding = new Padding(6) };
        tabGpu = new TabPage("GPU Status") { Padding = new Padding(6) };
        tabs.TabPages.Add(tabMain); tabs.TabPages.Add(tabModel); tabs.TabPages.Add(tabCN); tabs.TabPages.Add(tabSession); tabs.TabPages.Add(tabGpu);

        BuildCompTab(); BuildModelsTab(); BuildCNTab(); BuildSessionTab(); BuildGpuTab();
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
            SetWfNode(wf, "6", "seed", seed);
            SetWfNode(wf, "6", "steps", (int)numSteps.Value);
            SetWfNode(wf, "6", "cfg", (double)numCfg.Value);
            SetWfNode(wf, "6", "sampler_name", comboSampler.SelectedItem != null ? comboSampler.SelectedItem.ToString() : "euler");
            SetWfNode(wf, "6", "scheduler", comboScheduler.SelectedItem != null ? comboScheduler.SelectedItem.ToString() : "normal");
            SetWfNode(wf, "6", "width", (int)numWidth.Value);
            SetWfNode(wf, "6", "height", (int)numHeight.Value);
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
        tabMain.Controls.Add(Lbl("Prompt", 8, y));
        txtPrompt = new TextBox { Left = 8, Top = y + 18, Width = 440, Height = 55, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = Cfg("prompt") };
        tabMain.Controls.Add(txtPrompt); y += 80;
        tabMain.Controls.Add(Lbl("Negative prompt", 8, y));
        txtNegative = new TextBox { Left = 8, Top = y + 18, Width = 440, Height = 45, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = Cfg("negativePrompt") };
        tabMain.Controls.Add(txtNegative); y += 70;
        int lx = 8;
        tabMain.Controls.Add(Lbl("LoRA 1", lx, y + 2, 60));
        comboLora1 = MakeCombo(lx + 60, y, 200); comboLora1.Items.Add("None");
        chkLora1 = new CheckBox { Text = "Use", Left = lx + 264, Top = y + 2, Width = 40 };
        numLora1Str = new NumericUpDown { Left = lx + 308, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.80m };
        tabMain.Controls.Add(comboLora1); tabMain.Controls.Add(chkLora1); tabMain.Controls.Add(numLora1Str); y += 24;
        tabMain.Controls.Add(Lbl("LoRA 2", lx, y + 2, 60));
        comboLora2 = MakeCombo(lx + 60, y, 200); comboLora2.Items.Add("None");
        chkLora2 = new CheckBox { Text = "Use", Left = lx + 264, Top = y + 2, Width = 40 };
        numLora2Str = new NumericUpDown { Left = lx + 308, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.65m };
        tabMain.Controls.Add(comboLora2); tabMain.Controls.Add(chkLora2); tabMain.Controls.Add(numLora2Str); y += 24;
        tabMain.Controls.Add(Lbl("LoRA 3", lx, y + 2, 60));
        comboLora3 = MakeCombo(lx + 60, y, 200); comboLora3.Items.Add("None");
        chkLora3 = new CheckBox { Text = "Use", Left = lx + 264, Top = y + 2, Width = 40 };
        numLora3Str = new NumericUpDown { Left = lx + 308, Top = y, Width = 70, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 0.50m };
        tabMain.Controls.Add(comboLora3); tabMain.Controls.Add(chkLora3); tabMain.Controls.Add(numLora3Str); y += 30;
        tabMain.Controls.Add(Lbl("Seed", 8, y)); tabMain.Controls.Add(Lbl("Steps", 100, y)); tabMain.Controls.Add(Lbl("CFG", 180, y)); tabMain.Controls.Add(Lbl("Width", 250, y)); tabMain.Controls.Add(Lbl("Height", 330, y)); y += 18;
        chkRandomSeed = new CheckBox { Text = "Rnd", Left = 8, Top = y, Width = 40, Height = 18, Checked = true };
        numSeed = new NumericUpDown { Left = 46, Top = y, Width = 50, Maximum = int.MaxValue, Minimum = 1, Value = new Random().Next(1, int.MaxValue), Enabled = false };
        chkRandomSeed.CheckedChanged += (o, e) => { numSeed.Enabled = !chkRandomSeed.Checked; if (chkRandomSeed.Checked) numSeed.Value = new Random().Next(1, int.MaxValue); };
        numSteps = new NumericUpDown { Left = 100, Top = y, Width = 60, Minimum = 1, Maximum = 150, Value = 30 };
        numCfg = new NumericUpDown { Left = 170, Top = y, Width = 60, DecimalPlaces = 1, Minimum = 1, Maximum = 20, Increment = 0.1m, Value = 6 };
        numWidth = new NumericUpDown { Left = 240, Top = y, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabMain.Controls.Add(new Label { Text = "x", Left = 312, Top = y + 2, Width = 12 });
        numHeight = new NumericUpDown { Left = 324, Top = y, Width = 70, Minimum = 256, Maximum = 2048, Increment = 64, Value = 1024 };
        tabMain.Controls.Add(chkRandomSeed); tabMain.Controls.Add(numSeed); tabMain.Controls.Add(numSteps); tabMain.Controls.Add(numCfg); tabMain.Controls.Add(numWidth); tabMain.Controls.Add(numHeight); y += 24;
        tabMain.Controls.Add(Lbl("Sampler", 8, y, 120)); tabMain.Controls.Add(Lbl("Scheduler", 140, y, 120)); y += 18;
        comboSampler = MakeCombo(8, y + 18, 120); comboSampler.Items.AddRange(new[] { "dpmpp_2m", "dpmpp_2m_sde", "euler", "euler_ancestral", "heun", "ddim" }); comboSampler.SelectedIndex = 0;
        tabMain.Controls.Add(comboSampler);
        comboScheduler = MakeCombo(140, y + 18, 120); comboScheduler.Items.AddRange(new[] { "karras", "exponential", "simple", "normal" }); comboScheduler.SelectedIndex = 0;
        tabMain.Controls.Add(comboScheduler); y += 44;
        tabMain.Controls.Add(Lbl("Workflow Preset", 8, y));
        comboWorkflow = MakeCombo(8, y + 18, 300); comboWorkflow.Items.Add("Standard"); comboWorkflow.SelectedIndex = 0;
        tabMain.Controls.Add(comboWorkflow); y += 46;
        var outfitBox = new GroupBox { Text = "Outfit", Left = 6, Top = y, Width = 460, Height = 130 };
        tabMain.Controls.Add(outfitBox); int oy = 18;
        outfitBox.Controls.Add(Lbl("Category", 8, oy, 60, 16)); outfitBox.Controls.Add(Lbl("Item", 200, oy, 60, 16)); oy += 16;
        comboOutCat = MakeCombo(8, oy, 180); comboOutCat.Items.Add("-- All --"); comboOutCat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutCat);
        comboOutItem = MakeCombo(200, oy, 180); comboOutItem.Enabled = false;
        outfitBox.Controls.Add(comboOutItem); oy += 24;
        outfitBox.Controls.Add(Lbl("Color", 8, oy, 60, 16)); outfitBox.Controls.Add(Lbl("Material", 200, oy, 60, 16)); oy += 16;
        comboOutColor = MakeCombo(8, oy, 180); comboOutColor.Items.Add("-- None --"); comboOutColor.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutColor);
        comboOutMat = MakeCombo(200, oy, 180); comboOutMat.Items.Add("-- None --"); comboOutMat.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutMat); oy += 24;
        chkEnableOutfit = new CheckBox { Text = "Enable", Left = 8, Top = oy, Width = 60, Height = 18 };
        outfitBox.Controls.Add(chkEnableOutfit);
        comboOutfitPlacement = MakeCombo(70, oy - 1, 120); comboOutfitPlacement.Items.Add("Append"); comboOutfitPlacement.Items.Add("Prepend"); comboOutfitPlacement.SelectedIndex = 0;
        outfitBox.Controls.Add(comboOutfitPlacement);
        btnRefreshLists = MakeButton("Refresh Lists", 200, oy - 2, 90, 22, Color.FromArgb(50, 50, 60));
        outfitBox.Controls.Add(btnRefreshLists);
    }

    private void BuildModelsTab() {
        int y = 4;
        tabModel.Controls.Add(Lbl("Checkpoint", 8, y));
        comboCheckpoint = MakeCombo(8, y + 18, 380); comboCheckpoint.Items.Add("None"); comboCheckpoint.SelectedIndex = 0;
        tabModel.Controls.Add(comboCheckpoint); y += 46;
        tabModel.Controls.Add(Lbl("Diffuser / Refiner", 8, y));
        comboDiffuser = MakeCombo(8, y + 18, 200); comboDiffuser.Items.Add("(checkpoint default)"); comboDiffuser.SelectedIndex = 0;
        tabModel.Controls.Add(comboDiffuser);
    }

    private void BuildCNTab() {
        int y = 4;
        chkCN = new CheckBox { Text = "Enable ControlNet", Left = 8, Top = y, Width = 140, Height = 22 };
        tabCN.Controls.Add(chkCN); y += 28;
        tabCN.Controls.Add(Lbl("Model", 8, y));
        comboCNModel = MakeCombo(8, y + 18, 250); comboCNModel.Items.Add("None"); comboCNModel.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNModel); y += 46;
        tabCN.Controls.Add(Lbl("Input Image", 8, y));
        comboCNImage = MakeCombo(8, y + 18, 300); comboCNImage.Items.Add("None"); comboCNImage.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNImage); y += 46;
        tabCN.Controls.Add(Lbl("Preprocessor", 8, y));
        comboCNFilter = MakeCombo(8, y + 18, 200); comboCNFilter.Items.AddRange(new[] { "None", "Canny", "Depth", "OpenPose" }); comboCNFilter.SelectedIndex = 0;
        tabCN.Controls.Add(comboCNFilter); y += 46;
        tabCN.Controls.Add(Lbl("Strength", 8, y));
        numCNStrength = new NumericUpDown { Left = 8, Top = y + 18, Width = 80, DecimalPlaces = 2, Minimum = 0, Maximum = 2, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNStrength); y += 46;
        tabCN.Controls.Add(Lbl("Start / End", 8, y));
        numCNStart = new NumericUpDown { Left = 8, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m };
        tabCN.Controls.Add(new Label { Text = "to", Left = 70, Top = y + 20, Width = 20 });
        numCNEnd = new NumericUpDown { Left = 90, Top = y + 18, Width = 60, DecimalPlaces = 2, Minimum = 0, Maximum = 1, Increment = 0.05m, Value = 1 };
        tabCN.Controls.Add(numCNEnd);
    }

    private void BuildSessionTab() { tabSession.Controls.Add(txtLog); }

    private void BuildGpuTab() {
        var lbl = new Label { Left = 8, Top = 8, Width = 580, Height = 100, Font = new Font("Consolas", 9), ForeColor = Color.FromArgb(180, 220, 180) };
        tabGpu.Controls.Add(lbl);
        var btn = MakeButton("Refresh", 8, 100, 130, 28, Color.FromArgb(50, 50, 60));
        btn.Click += (o, e) => { try { var info = GpuStatusProvider.Refresh(); lbl.Text = info.ToString(); } catch { lbl.Text = "GPU: Unknown"; } };
        tabGpu.Controls.Add(btn);
        try { var info = GpuStatusProvider.Refresh(); lbl.Text = info.ToString(); } catch { lbl.Text = "GPU: Unknown"; }
    }

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
        string loraRoot = @"C:\Users\Michael\Documents\ComfyUI\models\loras";
        comboLora1.Items.Clear(); comboLora2.Items.Clear(); comboLora3.Items.Clear();
        comboLora1.Items.Add("None"); comboLora2.Items.Add("None"); comboLora3.Items.Add("None");
        if (Directory.Exists(loraRoot)) {
            foreach (var f in Directory.GetFiles(loraRoot, "*.safetensors", SearchOption.AllDirectories).Concat(Directory.GetFiles(loraRoot, "*.ckpt", SearchOption.AllDirectories)).Concat(Directory.GetFiles(loraRoot, "*.pt", SearchOption.AllDirectories)).OrderBy(f => f)) {
                string rel = f.Substring(loraRoot.Length).TrimStart('\\'); comboLora1.Items.Add(rel); comboLora2.Items.Add(rel); comboLora3.Items.Add(rel);
            }
        }
        comboLora1.SelectedIndex = comboLora2.SelectedIndex = comboLora3.SelectedIndex = 0;
    }

    private void LoadPrefs() { }
    private void SavePrefs() { }

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
