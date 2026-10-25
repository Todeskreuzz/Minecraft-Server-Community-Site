using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

// One fixed website action. The URI never supplies paths or command arguments.
internal static class FriendsAndFoes {
    const string SchemeKey = @"Software\Classes\friendsandfoes";
    const string Site = "https://todeskreuzz.github.io/Minecraft-Server-Community-Site/";
    static readonly string Home = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FriendsAndFoes");
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    [STAThread]
    static int Main(string[] args) {
        try {
            if (args.Length == 1 && args[0] == "--self-test") { SelfTest(); return 0; }
            if (args.Length == 1 && args[0] == "--uninstall") { Uninstall(); return 0; }
            if (args.Length == 0) { Install(); return 0; }
            if (args.Length != 1 || !ValidUri(args[0])) throw new Exception("Unsupported launch request.");
            Launch(); return 0;
        } catch (Exception e) { if (args.Length == 1 && args[0] == "--self-test") return 2; MessageBox.Show(Say(e.Message), "Friends & Foes", MessageBoxButtons.OK, MessageBoxIcon.Information); return 1; }
    }
    static bool ValidUri(string value) { return value == "friendsandfoes://join" || value == "friendsandfoes://join/"; }
    static bool ValidServer(string value) {
        if (value == null || value.Length > 259 || !Regex.IsMatch(value, @"^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z0-9-]+(:[0-9]{1,5})?$")) return false;
        int colon = value.LastIndexOf(':'); int port;
        return colon < 0 || (Int32.TryParse(value.Substring(colon + 1), out port) && port > 0 && port <= 65535);
    }
    static Dictionary<string, object> ReadJson(string path) { return Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(path)); }
    static string Text(Dictionary<string, object> data, string key) { return data.ContainsKey(key) ? Convert.ToString(data[key]) : ""; }
    static string Say(string english) {
        if (System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName != "de") return english;
        switch (english) {
            case "Install the Friends & Foes link for this Windows user? It opens only your chosen Prism instance and the fixed community server. No administrator access is required.": return "Friends-&-Foes-Link für dieses Windows-Konto einrichten? Er öffnet nur deine gewählte Prism-Instanz und den festgelegten Community-Server. Administratorrechte sind nicht erforderlich.";
            case "Select your installed Prism Launcher": return "Installierten Prism Launcher auswählen";
            case "Select the imported Friends & Foes instance folder inside Prism/instances. In Prism: right-click instance > Folder.": return "Importierten Friends-&-Foes-Instanzordner unter Prism/instances auswählen. In Prism: Rechtsklick auf die Instanz > Ordner.";
            case "The community server is not configured yet.": return "Der Community-Server ist noch nicht eingerichtet.";
            case "Select Prism Launcher.": return "Bitte den Prism Launcher auswählen.";
            case "Select an imported Prism instance inside its instances directory.": return "Bitte eine importierte Prism-Instanz im Verzeichnis instances auswählen.";
            case "Prism instance metadata is missing. Import the current modpack first.": return "Die Prism-Instanzdaten fehlen. Bitte zuerst das aktuelle Modpack importieren.";
            case "This instance does not match the community Minecraft and Forge versions. Import the current modpack first.": return "Diese Instanz passt nicht zu den Minecraft- und Forge-Versionen der Community. Bitte zuerst das aktuelle Modpack importieren.";
            case "Ready. The website can now open your imported Prism instance. To remove the link, run Uninstall.cmd from the downloaded folder. Minecraft and Prism are not changed.": return "Fertig. Die Website kann jetzt deine importierte Prism-Instanz öffnen. Entfernen: Uninstall.cmd im heruntergeladenen Ordner starten. Minecraft und Prism werden nicht verändert.";
            case "Unsupported launch request.": return "Nicht unterstützter Startaufruf.";
            case "Invalid fixed launch settings. Run setup again.": return "Ungültige Starteinstellungen. Bitte die Einrichtung erneut ausführen.";
            case "Prism Launcher is missing. Run setup again.": return "Prism Launcher wurde nicht gefunden. Bitte die Einrichtung erneut ausführen.";
            case "The imported instance is missing. Run setup again.": return "Die importierte Instanz fehlt. Bitte die Einrichtung erneut ausführen.";
            case "Remove the Friends & Foes website link? Minecraft and Prism remain untouched.": return "Den Friends-&-Foes-Website-Link entfernen? Minecraft und Prism bleiben unverändert.";
            case "The website link and settings were removed. You may delete the FriendsAndFoes folder in LocalAppData after closing this window.": return "Website-Link und Einstellungen wurden entfernt. Nach dem Schließen dieses Fensters kannst du den Ordner FriendsAndFoes in LocalAppData löschen.";
            default: return english;
        }
    }
    static void Install() {
        if (MessageBox.Show(Say("Install the Friends & Foes link for this Windows user? It opens only your chosen Prism instance and the fixed community server. No administrator access is required."), "Friends & Foes", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        Dictionary<string, object> config;
        using (var client = new WebClient()) config = Json.Deserialize<Dictionary<string, object>>(client.DownloadString(Site + "assets/data/config.json"));
        string server = Text((Dictionary<string, object>)config["server"], "address");
        if (!ValidServer(server)) throw new Exception("The community server is not configured yet.");
        string prism, folder;
        using (var pick = new OpenFileDialog { Title = Say("Select your installed Prism Launcher"), Filter = "Prism Launcher|prismlauncher.exe", CheckFileExists = true }) {
            if (pick.ShowDialog() != DialogResult.OK) return;
            prism = pick.FileName;
        }
        if (!String.Equals(Path.GetFileName(prism), "prismlauncher.exe", StringComparison.OrdinalIgnoreCase)) throw new Exception("Select Prism Launcher.");
        using (var pick = new FolderBrowserDialog { Description = Say("Select the imported Friends & Foes instance folder inside Prism/instances. In Prism: right-click instance > Folder.") }) {
            if (pick.ShowDialog() != DialogResult.OK) return;
            folder = pick.SelectedPath;
        }
        var instance = new DirectoryInfo(folder);
        if (instance.Parent == null || !String.Equals(instance.Parent.Name, "instances", StringComparison.OrdinalIgnoreCase) || !File.Exists(Path.Combine(folder, "instance.cfg"))) throw new Exception("Select an imported Prism instance inside its instances directory.");
        CheckVersion(folder, Text(config, "minecraftVersion"), Text(config, "forgeVersion"));
        Directory.CreateDirectory(Home);
        string target = Path.Combine(Home, "FriendsAndFoes.exe");
        string source = Process.GetCurrentProcess().MainModule.FileName;
        if (!String.Equals(source, target, StringComparison.OrdinalIgnoreCase)) File.Copy(source, target, true);
        var settings = new Dictionary<string, object> { { "server", server }, { "prism", prism }, { "root", instance.Parent.Parent.FullName }, { "instance", instance.Name }, { "minecraft", Text(config, "minecraftVersion") }, { "forge", Text(config, "forgeVersion") } };
        File.WriteAllText(Path.Combine(Home, "settings.json"), Json.Serialize(settings), Encoding.UTF8);
        using (var key = Registry.CurrentUser.CreateSubKey(SchemeKey)) { key.SetValue("", "URL:Friends & Foes"); key.SetValue("URL Protocol", ""); }
        using (var key = Registry.CurrentUser.CreateSubKey(SchemeKey + @"\shell\open\command")) key.SetValue("", Quote(target) + " \"%1\"");
        MessageBox.Show(Say("Ready. The website can now open your imported Prism instance. To remove the link, run Uninstall.cmd from the downloaded folder. Minecraft and Prism are not changed."), "Friends & Foes");
    }
    static void CheckVersion(string folder, string minecraft, string forge) {
        string path = Path.Combine(folder, "mmc-pack.json");
        if (!File.Exists(path)) throw new Exception("Prism instance metadata is missing. Import the current modpack first.");
        var pack = ReadJson(path); bool mc = false, loader = false;
        foreach (var value in (IEnumerable)pack["components"]) {
            var component = (Dictionary<string, object>)value;
            if (Text(component, "uid") == "net.minecraft") mc = Text(component, "version") == minecraft;
            if (Text(component, "uid") == "net.minecraftforge") loader = Text(component, "version") == forge;
        }
        if (!mc || !loader) throw new Exception("This instance does not match the community Minecraft and Forge versions. Import the current modpack first.");
    }
    static void Launch() {
        var settings = ReadJson(Path.Combine(Home, "settings.json"));
        string server = Text(settings, "server"), prism = Text(settings, "prism"), root = Text(settings, "root"), instance = Text(settings, "instance");
        if (!ValidServer(server) || instance != Path.GetFileName(instance) || instance == "." || instance == "..") throw new Exception("Invalid fixed launch settings. Run setup again.");
        if (!File.Exists(prism) || !String.Equals(Path.GetFileName(prism), "prismlauncher.exe", StringComparison.OrdinalIgnoreCase)) throw new Exception("Prism Launcher is missing. Run setup again.");
        string folder = Path.Combine(Path.Combine(root, "instances"), instance);
        if (!File.Exists(Path.Combine(folder, "instance.cfg"))) throw new Exception("The imported instance is missing. Run setup again.");
        CheckVersion(folder, Text(settings, "minecraft"), Text(settings, "forge"));
        Process.Start(new ProcessStartInfo { FileName = prism, UseShellExecute = false, Arguments = "--dir " + Quote(root) + " --launch " + Quote(instance) + " --server " + Quote(server) });
    }
    static string Quote(string value) {
        var result = new StringBuilder("\""); int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') result.Append('\\', slashes * 2 + 1).Append('"');
            else result.Append('\\', slashes).Append(c);
            slashes = 0;
        }
        return result.Append('\\', slashes * 2).Append('"').ToString();
    }
    static void Uninstall() {
        if (MessageBox.Show(Say("Remove the Friends & Foes website link? Minecraft and Prism remain untouched."), "Friends & Foes", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
        Registry.CurrentUser.DeleteSubKeyTree(SchemeKey, false);
        string settings = Path.Combine(Home, "settings.json"); if (File.Exists(settings)) File.Delete(settings);
        // Windows locks the currently running executable; leave the inert binary for normal file deletion.
        MessageBox.Show(Say("The website link and settings were removed. You may delete the FriendsAndFoes folder in LocalAppData after closing this window."), "Friends & Foes");
    }
    static void SelfTest() {
        if (!ValidUri("friendsandfoes://join") || !ValidUri("friendsandfoes://join/")) throw new Exception("URI check failed");
        foreach (string value in new [] { "friendsandfoes://join?x=1", "friendsandfoes://other", "friendsandfoes://join\" --uninstall", "cmd.exe", "" }) if (ValidUri(value)) throw new Exception("Unsafe URI accepted");
        foreach (string value in new [] { "", "localhost", "https://example.net", "example.net:0", "example.net:65536", "example.net & calc" }) if (ValidServer(value)) throw new Exception("Invalid server accepted");
        if (!ValidServer("friends-foes.falixsrv.me") || !ValidServer("example.net:25565")) throw new Exception("Server check failed");
        if (Quote("a\"b") != "\"a\\\"b\"" || Quote("C:\\Game\\") != "\"C:\\Game\\\\\"") throw new Exception("Argument quoting failed");
        string temp = Path.Combine(Path.GetTempPath(), "faf-check-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);
        string metadata = Path.Combine(temp, "mmc-pack.json");
        try {
            File.WriteAllText(metadata, "{\"components\":[{\"uid\":\"net.minecraft\",\"version\":\"1.20.1\"},{\"uid\":\"net.minecraftforge\",\"version\":\"47.4.10\"}]}");
            CheckVersion(temp, "1.20.1", "47.4.10");
            bool rejected = false; try { CheckVersion(temp, "1.21.1", "47.4.10"); } catch { rejected = true; }
            if (!rejected) throw new Exception("Wrong profile accepted");
            File.Delete(metadata); rejected = false; try { CheckVersion(temp, "1.20.1", "47.4.10"); } catch { rejected = true; }
            if (!rejected) throw new Exception("Missing profile accepted");
        } finally { if (File.Exists(metadata)) File.Delete(metadata); Directory.Delete(temp); }
    }
}
