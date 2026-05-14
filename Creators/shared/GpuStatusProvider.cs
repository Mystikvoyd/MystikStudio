using System;
using System.Collections.Generic;
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
        string dTotal = Fmt(DedicatedTotal);
        string dUsed = Fmt(DedicatedUsed);
        string sUsed = Fmt(SharedUsed);
        return "GPU: " + Name + " | VRAM: " + dUsed + " / " + dTotal + (SharedUsed > 0 ? " | Shared: " + sUsed : "") + " | ComfyUI: " + (ComfyUiOnline ? "Online" : "Offline");
    }
    public string ToShortString() {
        string dTotal = Fmt(DedicatedTotal);
        string dUsed = Fmt(DedicatedUsed);
        return Name + " " + dUsed + "/" + dTotal;
    }
    private static string Fmt(long b) { return (b / (1024.0 * 1024.0 * 1024.0)).ToString("0.0") + " GB"; }
}

public static class GpuStatusProvider {
    private static PerformanceCounter dedicatedUsedCounter = null;
    private static PerformanceCounter sharedUsedCounter = null;
    private static string lastGpuName = "";
    private static long lastTotal = 0;
    private static string logDir = "";
    private static DateTime lastLogWrite = DateTime.MinValue;

    public static void SetLogDir(string dir) { logDir = dir; }

    public static GpuInfo Refresh(string comfyUrl = "http://127.0.0.1:8188") {
        var info = new GpuInfo();
        try { LoadFromWmi(info); } catch { }
        try { LoadFromCounters(info); } catch { }
        try { CheckComfyUi(info, comfyUrl); } catch { }
        LogStatus(info);
        return info;
    }

    private static void LoadFromWmi(GpuInfo info) {
        try {
            using (var searcher = new ManagementObjectSearcher("SELECT Name, AdapterRAM FROM Win32_VideoController"))
            using (var results = searcher.Get()) {
                string bestName = "";
                long bestRam = 0;
                foreach (var mo in results) {
                    string name = Convert.ToString(mo["Name"] ?? "");
                    long ram = 0;
                    if (mo["AdapterRAM"] != null) long.TryParse(mo["AdapterRAM"].ToString(), out ram);
                    if (string.IsNullOrEmpty(name)) continue;
                    if (name.Contains("Microsoft") || name.Contains("Basic Display")) continue;
                    if (ram > bestRam) { bestRam = ram; bestName = name; }
                }
                if (!string.IsNullOrEmpty(bestName)) { info.Name = bestName; info.DedicatedTotal = bestRam; lastGpuName = bestName; lastTotal = bestRam; }
                else if (!string.IsNullOrEmpty(lastGpuName)) { info.Name = lastGpuName; info.DedicatedTotal = lastTotal; }
                else { info.Name = "Unknown GPU"; }
            }
        } catch {
            if (!string.IsNullOrEmpty(lastGpuName)) { info.Name = lastGpuName; info.DedicatedTotal = lastTotal; }
            else info.Name = "Unknown GPU";
        }
    }

    private static void LoadFromCounters(GpuInfo info) {
        try {
            if (dedicatedUsedCounter == null && !string.IsNullOrEmpty(info.Name)) {
                string shortName = GetShortGpuName(info.Name);
                if (string.IsNullOrEmpty(shortName)) return;
                dedicatedUsedCounter = new PerformanceCounter("GPU Adapter Memory", "Dedicated Usage", shortName);
                sharedUsedCounter = new PerformanceCounter("GPU Adapter Memory", "Shared Usage", shortName);
                dedicatedUsedCounter.NextValue(); sharedUsedCounter.NextValue();
            }
            if (dedicatedUsedCounter != null) {
                float val = dedicatedUsedCounter.NextValue();
                if (val >= 0) info.DedicatedUsed = (long)(val * 1024 * 1024);
            }
            if (sharedUsedCounter != null) {
                float val = sharedUsedCounter.NextValue();
                if (val >= 0) info.SharedUsed = (long)(val * 1024 * 1024);
            }
        } catch {
            dedicatedUsedCounter = null; sharedUsedCounter = null;
        }
    }

    private static string GetShortGpuName(string fullName) {
        if (fullName.Contains("RTX")) return "GPU 0 (NVIDIA)";
        if (fullName.Contains("GTX")) return "GPU 0 (NVIDIA)";
        if (fullName.Contains("Radeon")) return "GPU 0 (AMD)";
        if (fullName.Contains("Intel")) return "GPU 0 (Intel)";
        return "GPU 0";
    }

    private static void CheckComfyUi(GpuInfo info, string url) {
        try {
            var wc = new WebClient();
            wc.Headers.Add("User-Agent", "ForgeGpu/1.0");
            wc.Encoding = Encoding.UTF8;
            string resp = wc.DownloadString(url + "/system_stats");
            info.ComfyUiOnline = true;
            info.ComfyUiStatus = "Online";
        } catch {
            info.ComfyUiOnline = false;
            info.ComfyUiStatus = "Offline";
        }
    }

    private static void LogStatus(GpuInfo info) {
        if (string.IsNullOrEmpty(logDir) || !Directory.Exists(logDir)) return;
        try {
            string logPath = Path.Combine(logDir, "gpu-status-latest.log");
            string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | " + info.ToString();
            File.WriteAllText(logPath, line + Environment.NewLine);
        } catch { }
    }
}
