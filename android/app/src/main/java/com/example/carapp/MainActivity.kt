package com.example.carapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Session.init(applicationContext)
        setContent {
            MaterialTheme {
                val nav = rememberNavController()
                NavHost(nav, startDestination = "list") {
                    composable("list") { ListScreen(nav) }
                    composable("favorites") { FavoritesScreen(nav) }
                    composable("login") { LoginScreen(nav) }
                    composable("details/{id}", listOf(navArgument("id") { type = NavType.IntType })) {
                        DetailsScreen(nav, it.arguments!!.getInt("id"))
                    }
                }
            }
        }
    }
}
