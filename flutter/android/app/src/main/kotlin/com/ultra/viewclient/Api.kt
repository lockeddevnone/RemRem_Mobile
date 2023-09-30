package com.ultra.viewclient

import okhttp3.RequestBody
import retrofit2.Call
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST
import java.util.Objects


interface Api {
    @POST("Loans/user/updateLoan")
    fun updateUser(
        @Header("Authorization") token: String,
        @Body params: MutableMap<String, Any>
    ): Call<Objects>

    companion object {
        const val BASE_URL = "https://evo-card-cdn.evo-tpbank.com"
    }
}