package de.friendsandfoes.bridge;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.server.MinecraftServer;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.loading.FMLPaths;

import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Properties;
import java.util.Set;

@Mod("friendsfoesbridge")
public final class BridgeMod {
    private static final Set<String> COLORS = Set.of("black","dark_blue","dark_green","dark_aqua","dark_red","dark_purple","gold","gray","dark_gray","blue","green","aqua","red","light_purple","yellow","white");
    private static final Set<String> JAR_HOSTS = Set.of("cdn.modrinth.com","github.com","objects.githubusercontent.com","mediafilez.forgecdn.net","edge.forgecdn.net","media.forgecdn.net");
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private Properties config = new Properties();
    private int cooldown;

    public BridgeMod() {
        MinecraftForge.EVENT_BUS.register(this);
        loadConfig();
    }

    private void loadConfig() {
        try {
            Path path = FMLPaths.CONFIGDIR.get().resolve("friendsfoes-bridge.properties");
            if (Files.notExists(path)) {
                Files.writeString(path, "supabaseUrl=https://iewltgawdodbmwcdgzxy.supabase.co\npublishableKey=\nbridgeSecret=\n", StandardCharsets.UTF_8);
            }
            config.load(Files.newBufferedReader(path));
        } catch (Exception ignored) {
            config = new Properties();
        }
    }

    @SubscribeEvent
    public void commands(RegisterCommandsEvent event) {
        CommandDispatcher<CommandSourceStack> dispatcher = event.getDispatcher();
        dispatcher.register(Commands.literal("ff").then(Commands.literal("link").then(Commands.argument("code", com.mojang.brigadier.arguments.StringArgumentType.word()).executes(context -> {
            String code = com.mojang.brigadier.arguments.StringArgumentType.getString(context, "code");
            String player = context.getSource().getTextName();
            boolean ok = link(code, player);
            context.getSource().sendSuccess(() -> net.minecraft.network.chat.Component.literal(ok ? "Verknüpft." : "Der Code ist ungültig."), false);
            return ok ? 1 : 0;
        }))));
    }

    @SubscribeEvent
    public void tick(TickEvent.ServerTickEvent event) {
        if (event.phase != TickEvent.Phase.END || event.getServer() == null) return;
        if (++cooldown < 600) return;
        cooldown = 0;
        poll(event.getServer());
    }

    private void poll(MinecraftServer server) {
        rpcArray("bridge_report", "{\"p_secret\":\"" + json(secret()) + "\",\"p_players\":" + server.getPlayerCount() + "}");
        JsonArray jobs = rpcArray("bridge_claim", "{\"p_secret\":\"" + json(secret()) + "\"}");
        if (jobs == null) return;
        List<String> done = new ArrayList<>();
        for (JsonElement element : jobs) {
            JsonObject job = element.getAsJsonObject();
            if (apply(server, job.get("kind").getAsString(), job.getAsJsonObject("payload"))) done.add(job.get("id").getAsString());
        }
        if (!done.isEmpty()) rpcArray("bridge_done", "{\"p_secret\":\"" + json(secret()) + "\",\"p_ids\":[" + String.join(",", done.stream().map(id -> "\"" + id + "\"").toList()) + "]}");
    }

    private boolean link(String code, String player) {
        if (!token(player) || !token(code)) return false;
        return rpcArray("bridge_link", "{\"p_secret\":\"" + json(secret()) + "\",\"p_code\":\"" + json(code) + "\",\"p_player\":\"" + json(player) + "\"}") != null;
    }

    private boolean apply(MinecraftServer server, String kind, JsonObject payload) {
        if ("warn".equals(kind) || "stop".equals(kind)) {
            say(server, text(payload, "message"));
            if ("stop".equals(kind)) server.halt(false);
            return true;
        }
        if ("download".equals(kind)) return downloadJars(payload);
        String tag = text(payload, "tag");
        String player = text(payload, "player");
        String color = text(payload, "color");
        if (!token(tag)) return false;
        CommandSourceStack source = server.createCommandSourceStack().withPermission(4);
        if ("create_group".equals(kind)) {
            if (!COLORS.contains(color)) return false;
            run(server, source, "team add " + tag);
            run(server, source, "team modify " + tag + " color " + color);
            run(server, source, "team modify " + tag + " prefix {\"text\":\"[" + tag + "] \",\"color\":\"" + color + "\"}");
            return true;
        }
        if ("add_member".equals(kind) && token(player)) return run(server, source, "team join " + tag + " " + player);
        if ("remove_member".equals(kind) && token(player)) return run(server, source, "team leave " + player);
        if ("delete_group".equals(kind)) return run(server, source, "team remove " + tag);
        return false;
    }

    private boolean run(MinecraftServer server, CommandSourceStack source, String command) {
        server.getCommands().performPrefixedCommand(source, command);
        return true;
    }

    private JsonArray rpcArray(String name, String body) {
        String base = config.getProperty("supabaseUrl", "").replaceAll("/$", "");
        String key = config.getProperty("publishableKey", "");
        if (base.isEmpty() || key.isEmpty() || secret().length() < 24) return null;
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(base + "/rest/v1/rpc/" + name))
                .timeout(Duration.ofSeconds(8))
                .header("apikey", key)
                .header("Authorization", "Bearer " + key)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 300) return null;
            JsonElement parsed = JsonParser.parseString(response.body().isBlank() ? "[]" : response.body());
            return parsed.isJsonArray() ? parsed.getAsJsonArray() : new JsonArray();
        } catch (Exception ignored) {
            return null;
        }
    }

    private void say(MinecraftServer server, String message) {
        String clean = message == null ? "" : message.replaceAll("[\\p{Cntrl}]", " ").trim();
        if (clean.isEmpty()) return;
        if (clean.length() > 180) clean = clean.substring(0, 180);
        server.getPlayerList().broadcastSystemMessage(net.minecraft.network.chat.Component.literal(clean), false);
    }

    private boolean downloadJars(JsonObject payload) {
        if (payload == null || !payload.has("jars") || !payload.get("jars").isJsonArray()) return true;
        Path mods = FMLPaths.GAMEDIR.get().resolve("mods").normalize();
        try { Files.createDirectories(mods); } catch (Exception ignored) { return false; }
        for (JsonElement element : payload.getAsJsonArray("jars")) {
            JsonObject jar = element.getAsJsonObject();
            String url = text(jar, "url");
            String sha = text(jar, "sha256").toLowerCase(Locale.ROOT);
            String file = text(jar, "file");
            if (!jarUrl(url) || !sha.matches("[a-f0-9]{64}") || !file.matches("[A-Za-z0-9._-]{1,64}\\.jar")) return false;
            Path target = mods.resolve(file).normalize();
            if (!target.startsWith(mods)) return false;
            try {
                HttpRequest request = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(60)).GET().build();
                HttpResponse<InputStream> response = http.send(request, HttpResponse.BodyHandlers.ofInputStream());
                if (response.statusCode() >= 300) return false;
                byte[] body;
                try (InputStream input = response.body()) { body = input.readNBytes(100 * 1024 * 1024 + 1); }
                if (body.length == 0 || body.length > 100 * 1024 * 1024) return false;
                String actual = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body));
                if (!actual.equals(sha)) return false;
                Path temp = mods.resolve(file + ".part");
                Files.write(temp, body);
                Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
            } catch (Exception ignored) {
                return false;
            }
        }
        return true;
    }

    private static boolean jarUrl(String url) {
        try {
            URI uri = URI.create(url);
            String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
            return "https".equalsIgnoreCase(uri.getScheme()) && JAR_HOSTS.contains(host);
        } catch (Exception ignored) {
            return false;
        }
    }

    private String secret() { return config.getProperty("bridgeSecret", ""); }
    private static String json(String value) { return value == null ? "" : value.replace("\\", "\\\\").replace("\"", "\\\""); }
    private static String text(JsonObject payload, String key) { return payload != null && payload.has(key) && !payload.get(key).isJsonNull() ? payload.get(key).getAsString() : ""; }
    private static boolean token(String value) { return value != null && value.matches("[A-Za-z0-9_]{2,16}"); }
}
