package com.example.carapp

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import coil.compose.AsyncImage
import kotlinx.coroutines.launch

private fun rub(v: Double) = "%,.0f ₽".format(v).replace(',', ' ')

@Composable
private fun ListingCard(l: ListingShort, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable { onClick() }) {
        Row(Modifier.padding(8.dp)) {
            AsyncImage(l.photo, null, Modifier.size(100.dp).clip(MaterialTheme.shapes.small),
                contentScale = ContentScale.Crop)
            Spacer(Modifier.width(8.dp))
            Column {
                Text("${l.brand} ${l.model}, ${l.year}", style = MaterialTheme.typography.titleMedium)
                Text(rub(l.price), style = MaterialTheme.typography.titleSmall)
                Text("${l.mileage} км · ${l.transmission ?: ""} · ${l.city ?: ""}")
                l.reliability_rating?.let { Text("Надёжность: $it / 10") }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListScreen(nav: NavController) {
    val scope = rememberCoroutineScope()
    var brand by remember { mutableStateOf("") }
    var yearFrom by remember { mutableStateOf("") }
    var priceTo by remember { mutableStateOf("") }
    var items by remember { mutableStateOf<List<ListingShort>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }

    fun load() = scope.launch {
        try {
            val f = mutableMapOf<String, String>()
            if (brand.isNotBlank()) f["brand"] = brand
            if (yearFrom.isNotBlank()) f["year_from"] = yearFrom
            if (priceTo.isNotBlank()) f["price_to"] = priceTo
            items = Net.api.search(f); error = null
        } catch (e: Exception) { error = "Ошибка сети: ${e.message}" }
    }
    LaunchedEffect(Unit) { load() }

    Scaffold(topBar = {
        TopAppBar(title = { Text("Б/у автомобили") }, actions = {
            TextButton(onClick = { nav.navigate(if (Session.loggedIn) "favorites" else "login") }) { Text("Избранное") }
            TextButton(onClick = {
                if (Session.loggedIn) { Session.token = null; nav.navigate("list") } else nav.navigate("login")
            }) { Text(if (Session.loggedIn) "Выйти" else "Войти") }
        })
    }) { pad ->
        Column(Modifier.padding(pad).padding(8.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedTextField(brand, { brand = it }, label = { Text("Марка") }, singleLine = true, modifier = Modifier.weight(1f))
                OutlinedTextField(yearFrom, { yearFrom = it }, label = { Text("Год от") }, singleLine = true, modifier = Modifier.weight(0.7f))
                OutlinedTextField(priceTo, { priceTo = it }, label = { Text("Цена до") }, singleLine = true, modifier = Modifier.weight(1f))
            }
            Button({ load() }, Modifier.fillMaxWidth().padding(vertical = 6.dp)) { Text("Найти") }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            LazyColumn { items(items) { l -> ListingCard(l) { nav.navigate("details/${l.id}") } } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(nav: NavController) {
    var items by remember { mutableStateOf<List<ListingShort>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        try { items = Net.api.favorites() } catch (e: Exception) { error = "Ошибка: ${e.message}" }
    }
    Scaffold(topBar = {
        TopAppBar(title = { Text("Избранное") }, navigationIcon = { TextButton({ nav.popBackStack() }) { Text("←") } })
    }) { pad ->
        Column(Modifier.padding(pad).padding(8.dp)) {
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            LazyColumn { items(items) { l -> ListingCard(l) { nav.navigate("details/${l.id}") } } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailsScreen(nav: NavController, id: Int) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var d by remember { mutableStateOf<ListingDetails?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(id) {
        try { d = Net.api.details(id) } catch (e: Exception) { msg = "Ошибка сети: ${e.message}" }
    }
    Scaffold(topBar = {
        TopAppBar(title = { Text("Объявление") }, navigationIcon = { TextButton({ nav.popBackStack() }) { Text("←") } })
    }) { pad ->
        val x = d
        Column(Modifier.padding(pad).padding(12.dp).verticalScroll(rememberScrollState())) {
            msg?.let { Text(it) }
            if (x == null) { if (msg == null) CircularProgressIndicator(); return@Column }
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                items(x.photos) { AsyncImage(it, null, Modifier.height(200.dp).width(300.dp), contentScale = ContentScale.Crop) }
            }
            Text("${x.brand} ${x.model}, ${x.year}", style = MaterialTheme.typography.headlineSmall)
            Text(rub(x.price), style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.height(6.dp))
            listOf(
                "Пробег" to "${x.mileage} км", "Двигатель" to "${x.engine_volume ?: "-"} л, ${x.engine_power ?: "-"} л.с., ${x.fuel_type ?: ""}",
                "КПП" to x.transmission, "Привод" to x.drive_type, "Кузов" to x.body_type, "Цвет" to x.color,
                "Владельцев" to x.owners_count?.toString(), "Состояние" to x.condition,
                "Комплектация" to x.trim_level, "Город" to x.city
            ).forEach { (k, v) -> if (v != null) Text("$k: $v") }
            x.description?.let { Text("\n$it") }

            Divider(Modifier.padding(vertical = 10.dp))
            Text("Рейтинг надёжности: ${x.reliability_rating ?: "—"} / 10", style = MaterialTheme.typography.titleMedium)
            Text("Слабые места", style = MaterialTheme.typography.titleSmall)
            x.weaknesses.forEach { w ->
                Card(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                    Column(Modifier.padding(8.dp)) {
                        Text("[${w.severity}] ${w.system_node}: ${w.title}")
                        w.description?.let { Text(it) }
                        Text("Типичный пробег: ${w.typical_mileage ?: "—"} км; ремонт: " +
                            "${w.repair_cost_min?.let(::rub) ?: "—"} – ${w.repair_cost_max?.let(::rub) ?: "—"}")
                        Text(if (w.is_relevant) "⚠ Актуально: ${w.relevance_note}" else "✓ Не актуально: ${w.relevance_note}")
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
                Button({ scope.launch { try { d = Net.api.refresh(id); msg = "Обновлено" } catch (e: Exception) { msg = "Ошибка: ${e.message}" } } }) { Text("Обновить") }
                Button({
                    if (!Session.loggedIn) { nav.navigate("login"); return@Button }
                    scope.launch { try { Net.api.addFav(id); msg = "Добавлено в избранное" } catch (e: Exception) { msg = "Ошибка: ${e.message}" } }
                }) { Text("♥ В избранное") }
            }
            OutlinedButton({ ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(x.source_url))) },
                Modifier.fillMaxWidth()) { Text("Открыть оригинал") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(nav: NavController) {
    val scope = rememberCoroutineScope()
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var register by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Scaffold(topBar = { TopAppBar(title = { Text(if (register) "Регистрация" else "Вход") },
        navigationIcon = { TextButton({ nav.popBackStack() }) { Text("←") } }) }) { pad ->
        Column(Modifier.padding(pad).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            OutlinedTextField(email, { email = it }, label = { Text("Email") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(pass, { pass = it }, label = { Text("Пароль") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Button({
                scope.launch {
                    try {
                        val r = if (register) Net.api.register(Creds(email, pass)) else Net.api.login(Creds(email, pass))
                        Session.token = r.token
                        nav.navigate("list") { popUpTo("list") { inclusive = true } }
                    } catch (e: Exception) { error = "Не удалось: проверьте данные (${e.message})" }
                }
            }, Modifier.fillMaxWidth()) { Text(if (register) "Зарегистрироваться" else "Войти") }
            TextButton({ register = !register }) { Text(if (register) "Уже есть аккаунт" else "Создать аккаунт") }
        }
    }
}
