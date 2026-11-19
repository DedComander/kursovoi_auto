package com.example.carapp

import android.content.Context
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*

// Эмулятор Android -> localhost компьютера. Для реального телефона укажите IP ПК в локальной сети.
const val BASE_URL = "http://10.0.2.2:8000/"

data class ListingShort(
    val id: Int, val brand: String, val model: String, val year: Int, val mileage: Int,
    val price: Double, val city: String?, val transmission: String?, val fuel_type: String?,
    val body_type: String?, val reliability_rating: Double?, val photo: String?
)

data class Weakness(
    val system_node: String, val title: String, val description: String?, val severity: String,
    val typical_mileage: Int?, val repair_cost_min: Double?, val repair_cost_max: Double?,
    val is_relevant: Boolean, val relevance_note: String?
)

data class ListingDetails(
    val id: Int, val brand: String, val model: String, val year: Int, val mileage: Int,
    val price: Double, val city: String?, val description: String?, val source_url: String,
    val engine_volume: Double?, val engine_power: Int?, val fuel_type: String?,
    val transmission: String?, val drive_type: String?, val body_type: String?,
    val color: String?, val owners_count: Int?, val condition: String?, val trim_level: String?,
    val reliability_rating: Double?, val photos: List<String>, val weaknesses: List<Weakness>
)

data class Creds(val email: String, val password: String)
data class AuthResp(val token: String, val email: String)

interface Api {
    @GET("listings") suspend fun search(@QueryMap filters: Map<String, String>): List<ListingShort>
    @GET("listings/{id}") suspend fun details(@Path("id") id: Int): ListingDetails
    @POST("listings/{id}/refresh") suspend fun refresh(@Path("id") id: Int): ListingDetails
    @GET("favorites") suspend fun favorites(): List<ListingShort>
    @POST("favorites/{id}") suspend fun addFav(@Path("id") id: Int): Map<String, Boolean>
    @DELETE("favorites/{id}") suspend fun delFav(@Path("id") id: Int): Map<String, Boolean>
    @POST("auth/login") suspend fun login(@Body c: Creds): AuthResp
    @POST("auth/register") suspend fun register(@Body c: Creds): AuthResp
}

object Session {
    private lateinit var prefs: android.content.SharedPreferences
    fun init(ctx: Context) { prefs = ctx.getSharedPreferences("session", Context.MODE_PRIVATE) }
    var token: String?
        get() = prefs.getString("token", null)
        set(v) { prefs.edit().putString("token", v).apply() }
    val loggedIn get() = token != null
}

object Net {
    private val client = OkHttpClient.Builder().addInterceptor { chain ->
        val b = chain.request().newBuilder()
        Session.token?.let { b.header("Authorization", "Bearer $it") }
        chain.proceed(b.build())
    }.build()

    val api: Api by lazy {
        Retrofit.Builder().baseUrl(BASE_URL).client(client)
            .addConverterFactory(GsonConverterFactory.create()).build().create(Api::class.java)
    }
}
