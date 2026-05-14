using System;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Net;
using System.Text;

public class GpuInfo {
    public string Name { get; set; }
    public long DedicatedTotal { get; set; }
    public long DedicatedUsed { get; set; }
    public long SharedUsed { get; set; }
    public string ComfyUiStatus { get; set; }
    public bool ComfyUiOnline { get; set; }
    public override string ToString() {
        string dTotal = (DedicatedTotal > 0 ? FormatGb(DedicatedTotal) + " GB" : "? GB");
        string dUsed = (DedicatedUsed > 0 ? FormatGb(DedicatedUsed) + " GB" : "? GB");
        string sUsed = (SharedUsed > 0 ? FormatGb(SharedUsed) + " GB" : "");
        return "GPU: " + Name + " | VRAM: " + dUsed + " / " + dTotal + (SharedUsed > 0 ? " | Shared: " + sUsed : "") + " | ComfyUI: " + (ComfyUiOnline ? "Online" : "Offline");
    }
    private static string FormatGb(long bytes) {
        return (bytes / (1024.0 * 1024.0 * 1024.0)).ToString("0.0");
    }
}

public static class GpuStatusProvider {
    private static PerformanceCounter dedicatedUsedCounter = null;
    private static PerformanceCounter sharedUsedCounter = null;
    private static string lastGpuName = "";
    private static long lastTotal = 0;
    private static string logDir = "";
    private static string configuredComfyUrl = "http://127.0.0.1:8000";

    public static void SetLogDir(string dir) { logDir = dir; }
    public static void SetComfyUrl(string url) { configuredComfyUrl = url; }

    public static GpuInfo Refresh(string comfyUrl = null) {
        if (comfyUrl == null) comfyUrl = configuredComfyUrl;
        var info = new GpuInfo();
        try { LoadFromWmi(info); } catch { }
        try { LoadFromCounters(info); } catch { }
        try { LoadFromNvidiaSmi(info); } catch { }
        try { CheckComfyUi(info, comfyUrl); } catch { }
        LogStatus(info);
        return info;
    }

    private static void LoadFromWmi(GpuInfo info) {
        using (var searcher = new ManagementObjectSearcher("SELECT Name, AdapterRAM FROM Win32_VideoController"))
        using (var results = searcher.Get()) {
            string bestName = ""; long bestRam = 0;
            foreach (var mo in results) {
                string name = Convert.ToString(mo["Name"] ?? "");
                long ram = 0;
                if (mo["AdapterRAM"] != null) long.TryParse(mo["AdapterRAM"].ToString(), out ram);
                if (string.IsNullOrEmpty(name) || name.Contains("Microsoft") || name.Contains("Basic Display")) continue;
                if (ram > bestRam) { bestRam = ram; bestName = name; }
            }
            if (!string.IsNullOrEmpty(bestName)) { info.Name = bestName; info.DedicatedTotal = bestRam; lastGpuName = bestName; lastTotal = bestRam; }
            else if (!string.IsNullOrEmpty(lastGpuName)) { info.Name = lastGpuName; info.DedicatedTotal = lastTotal; }
            else info.Name = "Unknown GPU";
        }
    }

    private static void LoadFromCounters(GpuInfo info) {
        if (dedicatedUsedCounter == null && !string.IsNullOrEmpty(info.Name)) {
            string shortName = info.Name.Contains("RTX") || info.Name.Contains("GTX") ? "GPU 0 (NVIDIA)" : info.Name.Contains("Radeon") ? "GPU 0 (AMD)" : info.Name.Contains("Intel") ? "GPU 0 (Intel)" : "GPU 0";
            dedicatedUsedCounter = new PerformanceCounter("GPU Adapter Memory", "Dedicated Usage", shortName);
            sharedUsedCounter = new PerformanceCounter("GPU Adapter Memory", "Shared Usage", shortName);
            dedicatedUsedCounter.NextValue(); sharedUsedCounter.NextValue();
            System.Threading.Thread.Sleep(50);
        }
        if (dedicatedUsedCounter != null) { float v = dedicatedUsedCounter.NextValue(); if (v >= 0 && v < 1e10) info.DedicatedUsed = (long)(v * 1024 * 1024); }
        if (sharedUsedCounter != null) { float v = sharedUsedCounter.NextValue(); if (v >= 0 && v < 1e10) info.SharedUsed = (long)(v * 1024 * 1024); }
    }

    private static void LoadFromNvidiaSmi(GpuInfo info) {
        var psi = new ProcessStartInfo("nvidia-smi", "--query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader,nounits") { UseShellExecute = false, RedirectStandardOutput = true, CreateNoWindow = true };
        var proc = Process.Start(psi);
        if (proc != null && proc.WaitForExit(3000)) {
            string line = proc.StandardOutput.ReadLine();
            if (!string.IsNullOrEmpty(line)) {
                string[] p = line.Split(',');
                if (p.Length >= 4) {
                    info.Name = p[0].Trim(); double t, u;
                    if (double.TryParse(p[1].Trim(), out t)) info.DedicatedTotal = (long)(t * 1024 * 1024);
                    if (double.TryParse(p[2].Trim(), out u)) info.DedicatedUsed = (long)(u * 1024 * 1024);
                }
            }
        }
    }

    private static void CheckComfyUi(GpuInfo info, string url) {
        var wc = new WebClient(); wc.Headers.Add("User-Agent", "GpuCheck/1.0"); wc.Encoding = Encoding.UTF8;
        string resp = wc.DownloadString(url + "/system_stats");
        info.ComfyUiOnline = true; info.ComfyUiStatus = "Online";
    }

    private static void LogStatus(GpuInfo info) {
        if (string.IsNullOrEmpty(logDir) || !Directory.Exists(logDir)) return;
        try { File.WriteAllText(Path.Combine(logDir, "gpu-status-latest.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | " + info.ToString() + Environment.NewLine); } catch { }
    }
}
