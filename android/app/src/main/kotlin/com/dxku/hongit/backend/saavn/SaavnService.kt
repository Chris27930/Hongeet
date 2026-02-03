package com.dxku.hongit.backend.saavn

import okhttp3.OkHttpClient
import okhttp3.Request
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

object SaavnService {

    private const val BASE_URL = "https://saavn.sumit.co"

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    fun searchSongs(query: String): String {
        val encodedQuery = URLEncoder.encode(query, "UTF-8")

        val request = Request.Builder()
            .url("$BASE_URL/api/search/songs?query=$encodedQuery")
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw RuntimeException("Saavn API error: ${response.code}")
            }

            return response.body?.string()
                ?: throw RuntimeException("Empty response from Saavn")
        }
    }
}
