package com.dxku.hongit

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.dxku.hongit.backend.MainService
import com.ryanheise.audioservice.AudioServiceActivity
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "battery_optimization"
    private val YT_CHANNEL = "youtube_extractor"
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "YoutubeExtractor"
        private const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    private data class ExtractAttempt(
        val formatSelector: String,
        val extractorArgs: String?,
        val useAuthHeaders: Boolean
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "manufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }

                "isIgnoring" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }

                "request" -> {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            YT_CHANNEL
        ).setMethodCallHandler { call, result ->

            fun runBg(block: () -> Unit) {
                Thread(block).start()
            }

            when (call.method) {
                "extractAudio" -> {
                    val videoId = call.argument<String>("videoId")?.trim().orEmpty()
                    val authHeaders = call.argument<Map<String, Any?>>("authHeaders").toStringMap()
                    if (videoId.isBlank()) {
                        result.error("missing_video_id", "videoId is required", null)
                        return@setMethodCallHandler
                    }

                    runBg {
                        try {
                            val payload = extractBestAudio(videoId, authHeaders)
                            mainHandler.post { result.success(payload) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("extract_failed", e.message, null) }
                        }
                    }
                }

                "extractAudioUrl" -> {
                    val videoId = call.argument<String>("videoId")?.trim().orEmpty()
                    val authHeaders = call.argument<Map<String, Any?>>("authHeaders").toStringMap()
                    if (videoId.isBlank()) {
                        result.error("missing_video_id", "videoId is required", null)
                        return@setMethodCallHandler
                    }

                    runBg {
                        try {
                            val payload = extractBestAudio(videoId, authHeaders)
                            val url = payload["url"] as? String
                                ?: throw IllegalStateException("No playable audio URL extracted")
                            mainHandler.post { result.success(url) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("extract_failed", e.message, null) }
                        }
                    }
                }

                "search" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    val take = call.argument<Int>("take") ?: 30
                    if (query.isBlank()) {
                        result.error("missing_query", "query is required", null)
                        return@setMethodCallHandler
                    }

                    runBg {
                        try {
                            val items = searchYoutube(query, take.coerceIn(1, 50))
                            mainHandler.post { result.success(items) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("search_failed", e.message, null) }
                        }
                    }
                }

                "related" -> {
                    val videoId = call.argument<String>("videoId")?.trim().orEmpty()
                    val take = call.argument<Int>("take") ?: 10
                    if (videoId.isBlank()) {
                        result.error("missing_video_id", "videoId is required", null)
                        return@setMethodCallHandler
                    }

                    runBg {
                        try {
                            val items = relatedYoutube(videoId, take.coerceIn(1, 50))
                            mainHandler.post { result.success(items) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("related_failed", e.message, null) }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            YoutubeDL.getInstance().init(this)
        } catch (e: YoutubeDLException) {
            Log.e(TAG, "Failed to init yt-dlp", e)
        }
        MainService.start(this)
    }

    private fun maybeUpdateYtDlpInBackground() {
        Thread {
            try {
                val status = YoutubeDL.getInstance()
                    .updateYoutubeDL(this, YoutubeDL.UpdateChannel.STABLE)
                val version = YoutubeDL.getInstance().version(this)
                Log.i(TAG, "yt-dlp update status=$status version=$version")
            } catch (e: Exception) {
                Log.w(TAG, "yt-dlp update skipped: ${e.message}")
            }
        }.start()
    }

    private fun extractBestAudio(
        videoId: String,
        authHeaders: Map<String, String>
    ): Map<String, Any?> {
        val attempts = listOf(
            ExtractAttempt(
                formatSelector = "bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best",
                extractorArgs = "youtube:player_client=android;player_skip=webpage,configs",
                useAuthHeaders = false
            ),
            ExtractAttempt(
                formatSelector = "bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best",
                extractorArgs = "youtube:player_client=android,web",
                useAuthHeaders = true
            ),
            ExtractAttempt(
                formatSelector = "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best",
                extractorArgs = "youtube:player_client=web",
                useAuthHeaders = true
            ),
            ExtractAttempt(
                formatSelector = "bestaudio/best",
                extractorArgs = null,
                useAuthHeaders = true
            )
        )

        var lastError: Exception? = null

        for (attempt in attempts) {
            try {
                return extractBestAudioWithAttempt(videoId, authHeaders, attempt)
            } catch (e: Exception) {
                lastError = e
                Log.w(
                    TAG,
                    "Extraction attempt failed " +
                        "(format=${attempt.formatSelector}, extractorArgs=${attempt.extractorArgs}, " +
                        "useAuth=${attempt.useAuthHeaders}): ${e.message}"
                )
            }
        }

        throw lastError ?: IllegalStateException("No playable audio URL extracted")
    }

    private fun extractBestAudioWithAttempt(
        videoId: String,
        authHeaders: Map<String, String>,
        attempt: ExtractAttempt
    ): Map<String, Any?> {
        val watchUrl = "https://www.youtube.com/watch?v=$videoId"
        val request = YoutubeDLRequest(watchUrl)

        request.addOption("--no-playlist")
        request.addOption("--no-warnings")
        request.addOption("--geo-bypass")
        request.addOption("--socket-timeout", "8")
        request.addOption("--retries", "1")
        request.addOption("--extractor-retries", "1")
        request.addOption("-f", attempt.formatSelector)

        if (!attempt.extractorArgs.isNullOrBlank()) {
            request.addOption("--extractor-args", attempt.extractorArgs)
        }

        if (attempt.useAuthHeaders) {
            applyAuthHeaders(request, authHeaders)
        }

        val info = YoutubeDL.getInstance().getInfo(request)
        val url = info.url?.trim().orEmpty()

        if (url.isBlank()) {
            throw IllegalStateException("No playable audio URL extracted")
        }

        val safeUrl = if (url.startsWith("http://")) {
            url.replaceFirst("http://", "https://")
        } else {
            url
        }

        val headers = HashMap<String, String>()
        info.httpHeaders?.let { headers.putAll(it) }

        if (!headers.containsKey("User-Agent")) {
            headers["User-Agent"] = DEFAULT_USER_AGENT
        }
        if (!headers.containsKey("Accept")) {
            headers["Accept"] = "*/*"
        }
        if (!headers.containsKey("Accept-Language")) {
            headers["Accept-Language"] = "en-US,en;q=0.9"
        }
        if (!headers.containsKey("Referer")) {
            headers["Referer"] = "https://www.youtube.com/"
        }
        if (!headers.containsKey("Origin")) {
            headers["Origin"] = "https://www.youtube.com"
        }

        return mapOf(
            "url" to safeUrl,
            "headers" to headers
        )
    }

    private fun applyAuthHeaders(
        request: YoutubeDLRequest,
        rawHeaders: Map<String, String>
    ) {
        val headers = normalizeAuthHeaders(rawHeaders)

        for ((key, value) in headers) {
            if (key.isBlank() || value.isBlank()) continue
            request.addOption("--add-header", "$key: $value")
        }

        if (!headers.containsKey("Referer")) {
            request.addOption("--add-header", "Referer: https://www.youtube.com/")
        }
        if (!headers.containsKey("Origin")) {
            request.addOption("--add-header", "Origin: https://www.youtube.com")
        }
    }

    private fun normalizeAuthHeaders(rawHeaders: Map<String, String>): Map<String, String> {
        if (rawHeaders.isEmpty()) return emptyMap()

        val normalized = HashMap<String, String>()
        val lower = HashMap<String, String>()

        for ((key, value) in rawHeaders) {
            val k = key.trim().lowercase()
            val v = value.trim()
            if (k.isEmpty() || v.isEmpty()) continue
            lower[k] = v
        }

        lower["cookie"]?.let { normalized["Cookie"] = it }
        lower["user-agent"]?.let { normalized["User-Agent"] = it }
        lower["accept"]?.let { normalized["Accept"] = it }
        lower["accept-language"]?.let { normalized["Accept-Language"] = it }
        lower["x-goog-visitor-id"]?.let { normalized["X-Goog-Visitor-Id"] = it }
        lower["x-goog-authuser"]?.let { normalized["X-Goog-AuthUser"] = it }
        lower["x-youtube-client-name"]?.let { normalized["X-Youtube-Client-Name"] = it }
        lower["x-youtube-client-version"]?.let { normalized["X-Youtube-Client-Version"] = it }
        lower["x-youtube-bootstrap-logged-in"]?.let { normalized["X-Youtube-Bootstrap-Logged-In"] = it }
        lower["x-origin"]?.let { normalized["X-Origin"] = it }
        lower["referer"]?.let { normalized["Referer"] = it }
        lower["origin"]?.let { normalized["Origin"] = it }

        return normalized
    }

    private fun searchYoutube(query: String, take: Int): List<Map<String, Any?>> {
        val safeTake = take.coerceIn(1, 50)
        val fetchTake = (safeTake * 2).coerceIn(safeTake, 50)
        val artistQuery = isLikelyArtistQuery(query)
        val effectiveQuery = buildMusicSearchQuery(query)

        val request = YoutubeDLRequest("ytsearch${fetchTake}:${effectiveQuery}")
        request.addOption("--dump-single-json")
        request.addOption("--no-playlist")
        request.addOption("--no-warnings")
        request.addOption("--geo-bypass")
        request.addOption("--flat-playlist")
        request.addOption("--playlist-end", fetchTake.toString())
        request.addOption("--socket-timeout", "8")
        request.addOption("--retries", "1")
        request.addOption("--extractor-retries", "1")
        request.addOption("--extractor-args", "youtube:player_skip=webpage,configs")

        val resp = YoutubeDL.getInstance().execute(request)
        val json = JSONObject(resp.out)
        val entries = json.optJSONArray("entries") ?: return emptyList()

        val strict = ArrayList<Map<String, Any?>>()
        val relaxed = ArrayList<Map<String, Any?>>()

        for (i in 0 until entries.length()) {
            val e = entries.optJSONObject(i) ?: continue
            if (artistQuery) {
                val mapped = mapYtEntryToSong(e, query, strictMode = false) ?: continue
                val uploader = e.optString("uploader").ifBlank { e.optString("channel").trim() }.trim()
                if (isArtistChannelMatch(uploader, query)) {
                    strict.add(mapped)
                } else {
                    relaxed.add(mapped)
                }
                continue
            }

            val strictMapped = mapYtEntryToSong(e, query, strictMode = true)
            if (strictMapped != null) {
                strict.add(strictMapped)
                continue
            }

            val relaxedMapped = mapYtEntryToSong(e, query, strictMode = false)
            if (relaxedMapped != null) {
                relaxed.add(relaxedMapped)
            }
        }

        val out = ArrayList<Map<String, Any?>>()
        val seenIds = HashSet<String>()

        for (item in strict) {
            val id = item["id"] as? String ?: continue
            if (seenIds.add(id)) out.add(item)
            if (out.size >= safeTake) return out
        }

        for (item in relaxed) {
            val id = item["id"] as? String ?: continue
            if (seenIds.add(id)) out.add(item)
            if (out.size >= safeTake) break
        }

        return out
    }

    private fun relatedYoutube(videoId: String, take: Int): List<Map<String, Any?>> {
        val mixUrl = "https://www.youtube.com/watch?v=$videoId&list=RD$videoId"
        val request = YoutubeDLRequest(mixUrl)
        request.addOption("--dump-single-json")
        request.addOption("--no-warnings")
        request.addOption("--geo-bypass")
        request.addOption("--flat-playlist")
        request.addOption("--playlist-end", (take + 2).toString())
        request.addOption("--socket-timeout", "8")
        request.addOption("--retries", "1")
        request.addOption("--extractor-retries", "1")
        request.addOption("--extractor-args", "youtube:player_skip=webpage,configs")

        val resp = YoutubeDL.getInstance().execute(request)
        val json = JSONObject(resp.out)
        val entries = json.optJSONArray("entries") ?: return emptyList()

        val out = ArrayList<Map<String, Any?>>()
        for (i in 0 until entries.length()) {
            val e = entries.optJSONObject(i) ?: continue
            val mapped = mapYtEntryToSong(e, query = "", strictMode = false) ?: continue
            out.add(mapped)
            if (out.size >= take) break
        }
        return out
    }

    private fun mapYtEntryToSong(
        e: JSONObject,
        query: String,
        strictMode: Boolean
    ): Map<String, Any?>? {
        val id = e.optString("id").trim()
        val title = e.optString("title").trim()
        val uploader = e.optString("uploader").ifBlank { e.optString("channel").trim() }.trim()
        val duration = if (e.has("duration")) e.optInt("duration", -1) else -1

        if (id.isBlank() || title.isBlank()) return null

        if (duration > 0) {
            if (duration in 0..59) return null
            if (duration > 15 * 60) return null
        }

        if (!isLikelyMusicResult(title, uploader, duration, query, strictMode)) {
            return null
        }

        val thumbUrl = "https://i.ytimg.com/vi/$id/hqdefault.jpg"

        return mapOf(
            "id" to "yt:$id",
            "name" to title,
            "duration" to if (duration > 0) duration else null,
            "author" to uploader,
            "thumbnail" to thumbUrl
        )
    }

    private fun buildMusicSearchQuery(query: String): String {
        val q = query.trim()
        if (q.isBlank()) return q

        if (isLikelyArtistQuery(q)) {
            return "$q topic"
        }

        val lower = q.lowercase()
        val hasMusicHint = listOf(
            "song",
            "music",
            "lyrics",
            "lyric",
            "audio",
            "album",
            "track",
            "remix",
            "cover",
            "ost",
            "soundtrack",
            "instrumental"
        ).any { lower.contains(it) }

        return if (hasMusicHint) q else "$q song"
    }

    private fun isLikelyArtistQuery(query: String): Boolean {
        val q = query.trim()
        if (q.isBlank()) return false

        val lower = q.lowercase()
        val musicHint = listOf(
            "song",
            "songs",
            "music",
            "lyrics",
            "lyric",
            "audio",
            "album",
            "track",
            "playlist",
            "mix",
            "remix",
            "cover",
            "ost",
            "soundtrack"
        ).any { lower.contains(it) }
        if (musicHint) return false

        val words = q.split(Regex("\\s+")).filter { it.isNotBlank() }
        if (words.size !in 2..4) return false

        if (q.any { it.isDigit() }) return false
        if (!q.matches(Regex("[A-Za-z'&.\\- ]+"))) return false

        return true
    }

    private fun isArtistChannelMatch(uploader: String, query: String): Boolean {
        val u = uploader.lowercase()
        val tokens = query.lowercase()
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 }

        if (tokens.isEmpty()) return false

        val matches = tokens.count { token -> u.contains(token) }
        if (matches >= 2) return true
        if (matches >= 1 && (u.contains("- topic") || u.contains("vevo") || u.contains("official"))) {
            return true
        }

        return false
    }

    private fun isLikelyMusicResult(
        title: String,
        uploader: String,
        duration: Int,
        query: String,
        strictMode: Boolean
    ): Boolean {
        val t = title.lowercase()
        val u = uploader.lowercase()
        val q = query.lowercase()

        val blockedTokens = listOf(
            "full movie",
            "episode",
            "podcast",
            "reaction",
            "review",
            "interview",
            "news",
            "trailer",
            "teaser",
            "shorts",
            "gameplay",
            "walkthrough",
            "tutorial",
            "how to",
            "lecture",
            "speech",
            "sermon",
            "comedy",
            "prank",
            "vlog"
        )
        if (blockedTokens.any { t.contains(it) }) return false

        val likelyNonMusicChannels = listOf(
            "news",
            "podcast",
            "tv",
            "interview"
        )
        if (strictMode && likelyNonMusicChannels.any { u.contains(it) }) return false

        if (duration > 0) {
            if (duration in 0..59) return false
            if (duration > 15 * 60) return false
            if (strictMode && duration > 10 * 60 && !q.contains("live") && !q.contains("mix")) {
                return false
            }
        } else if (strictMode) {
            return false
        }

        val queryTokens = q
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 }
            .filter { it !in setOf("the", "and", "for", "song", "music", "video", "audio") }
        if (strictMode && queryTokens.isNotEmpty()) {
            val matches = queryTokens.count { token -> t.contains(token) || u.contains(token) }
            if (matches == 0) return false
        }

        val musicSignals = listOf(
            "official audio",
            "audio",
            "lyrics",
            "lyric",
            "music video",
            "visualizer",
            "remix",
            "cover",
            "ost",
            "soundtrack"
        )
        val hasMusicSignal = musicSignals.any { t.contains(it) } ||
            u.contains("- topic") ||
            u.contains("vevo")

        if (strictMode && !hasMusicSignal && duration > 0 && duration !in 90..480) {
            return false
        }

        return true
    }

    private fun Map<String, Any?>?.toStringMap(): Map<String, String> {
        if (this == null) return emptyMap()
        val out = HashMap<String, String>()
        for ((key, value) in this) {
            val k = key.trim()
            val v = value?.toString()?.trim().orEmpty()
            if (k.isNotEmpty() && v.isNotEmpty()) {
                out[k] = v
            }
        }
        return out
    }
}
