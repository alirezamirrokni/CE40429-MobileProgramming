import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.Path
import kotlinx.coroutines.runBlocking
import java.io.File

data class GitHubRepoResponse(val name: String)
data class GitHubUserResponse(
    val login: String,
    val followers: Int,
    val following: Int,
    @SerializedName("created_at") val createdAt: String
)
data class GitHubRepo(val name: String)
data class GitHubUser(
    val username: String,
    val followers: Int,
    val following: Int,
    val createdAt: String,
    val repositories: List<GitHubRepo>
)

interface GitHubApi {
    @GET("users/{username}")
    suspend fun getUser(@Path("username") username: String): GitHubUserResponse

    @GET("users/{username}/repos")
    suspend fun getUserRepos(@Path("username") username: String): List<GitHubRepoResponse>
}

object GitHubClient {
    val api: GitHubApi by lazy {
        Retrofit.Builder()
            .baseUrl("https://api.github.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(GitHubApi::class.java)
    }
}

class GitHubService(private val api: GitHubApi = GitHubClient.api) {
    suspend fun fetchUser(username: String): Result<GitHubUser> {
        return try {
            val userResponse = api.getUser(username)
            val repoResponses = api.getUserRepos(username)
            val repositories = repoResponses.map { GitHubRepo(it.name) }
            val user = GitHubUser(
                username = userResponse.login,
                followers = userResponse.followers,
                following = userResponse.following,
                createdAt = userResponse.createdAt,
                repositories = repositories
            )
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

object FileCacheManager {
    private const val cacheFileName = "cache.json"
    private val gson = Gson()
    private var users: MutableMap<String, GitHubUser> = mutableMapOf()

    init {
        loadCache()
    }

    private fun loadCache() {
        val file = File(cacheFileName)
        if (file.exists()) {
            try {
                val json = file.readText()
                if (json.isNotBlank()) {
                    val type = object : TypeToken<List<GitHubUser>>() {}.type
                    val userList: List<GitHubUser> = gson.fromJson(json, type)
                    users = userList.associateBy { it.username }.toMutableMap()
                }
            } catch (e: Exception) {
                println("❌ [Error] Failed to load cache: ${e.message}")
            }
        }
    }

    private fun saveCache() {
        val file = File(cacheFileName)
        try {
            val json = gson.toJson(users.values.toList())
            file.writeText(json)
        } catch (e: Exception) {
            println("❌ [Error] Failed to save cache: ${e.message}")
        }
    }

    fun addUser(user: GitHubUser) {
        users[user.username] = user
        saveCache()
    }

    fun getAllUsers(): List<GitHubUser> = users.values.toList()

    fun findUserByUsername(username: String): GitHubUser? = users[username]

    fun advancedSearchByUsername(query: String, minFollowers: Int?): List<GitHubUser> {
        return users.values.filter { user ->
            user.username.contains(query, ignoreCase = true) &&
                    (minFollowers == null || user.followers >= minFollowers)
        }
    }

    fun advancedSearchByRepoName(repoName: String, minMatches: Int?): List<GitHubUser> {
        return users.values.filter { user ->
            val matchCount = user.repositories.count { it.name.contains(repoName, ignoreCase = true) }
            matchCount > 0 && (minMatches == null || matchCount >= minMatches)
        }
    }
}

object ConsoleUI {
    const val LINE = "======================================="

    fun printHeader() {
        println()
        println("🔥 $LINE 🔥")
        println("         🤖 GitHub User Fetcher Pro 🤖         ")
        println("🔥 $LINE 🔥")
        println()
    }

    fun printMenu() {
        println("💡 1. Fetch GitHub user information by username")
        println("💡 2. Display all saved users")
        println("💡 3. Advanced Search for a user by username")
        println("💡 4. Advanced Search for users by repository name")
        println("💡 5. Exit")
        println(LINE)
        println()
    }

    fun prompt(message: String): String {
        print("👉 $message: ")
        return readLine()?.trim() ?: ""
    }

    fun printUser(user: GitHubUser) {
        println("⭐ Username         : ${user.username}")
        println("⭐ Followers        : ${user.followers}")
        println("⭐ Following        : ${user.following}")
        println("⭐ Account Created  : ${user.createdAt}")
        println("⭐ Repositories     :")
        if (user.repositories.isEmpty()) {
            println("   😞 No repositories available.")
        } else {
            user.repositories.forEach {
                println("   📦 - ${it.name}")
            }
        }
        println(LINE)
        println()
    }
}

fun main() = runBlocking {
    val gitHubService = GitHubService()

    while (true) {
        ConsoleUI.printHeader()
        ConsoleUI.printMenu()

        when (ConsoleUI.prompt("Your choice")) {
            "1" -> {
                val username = ConsoleUI.prompt("Enter GitHub username")
                if (username.isEmpty()) {
                    println("❌ [Error] Username cannot be empty!\n")
                    continue
                }
                val cachedUser = FileCacheManager.findUserByUsername(username)
                if (cachedUser != null) {
                    println("ℹ️ [Info] User '$username' is already saved.")
                    val updateChoice = ConsoleUI.prompt("🔄 Update the user data? (Y/n)")
                    if (updateChoice.lowercase() != "y" && updateChoice != "") {
                        println("ℹ️ [Info] Skipping update for '$username'.\n")
                        continue
                    }
                }
                println("🚀 Fetching data for user '$username'...\n")
                val result = gitHubService.fetchUser(username)
                result.fold(
                    onSuccess = { user ->
                        FileCacheManager.addUser(user)
                        println("✅ [Success] User data fetched successfully:")
                        println()
                        ConsoleUI.printUser(user)
                    },
                    onFailure = { error ->
                        println("❌ [Error] Failed to fetch user data: ${error.message}\n")
                    }
                )
            }
            "2" -> {
                val users = FileCacheManager.getAllUsers()
                if (users.isEmpty()) {
                    println("ℹ️ [Info] No users saved yet.\n")
                } else {
                    val sortOption = ConsoleUI.prompt("Sort users by: [1] Username (A-Z), [2] Followers (desc), [other] Unsorted")
                    val sortedUsers = when (sortOption) {
                        "1" -> users.sortedBy { it.username.lowercase() }
                        "2" -> users.sortedByDescending { it.followers }
                        else -> users
                    }
                    println("📚 [Saved Users]")
                    println()
                    sortedUsers.forEach { ConsoleUI.printUser(it) }
                }
            }
            "3" -> {
                val query = ConsoleUI.prompt("Enter full or partial username to search")
                val minFollowersInput = ConsoleUI.prompt("Enter minimum followers count (or leave blank)")
                val minFollowers = minFollowersInput.toIntOrNull()
                val matchingUsers = FileCacheManager.advancedSearchByUsername(query, minFollowers)
                if (matchingUsers.isEmpty()) {
                    println("ℹ️ [Info] No users found matching the criteria.\n")
                } else {
                    println("🔍 [Advanced Search Results]")
                    println()
                    matchingUsers.forEach { ConsoleUI.printUser(it) }
                }
            }
            "4" -> {
                val repoName = ConsoleUI.prompt("Enter repository name or keyword to search")
                val minMatchesInput = ConsoleUI.prompt("Enter minimum number of matching repositories (or leave blank)")
                val minMatches = minMatchesInput.toIntOrNull()
                val matchingUsers = FileCacheManager.advancedSearchByRepoName(repoName, minMatches)
                if (matchingUsers.isEmpty()) {
                    println("ℹ️ [Info] No users found with matching repository criteria.\n")
                } else {
                    println("🔍 [Advanced Repository Search Results]")
                    println()
                    matchingUsers.forEach { user ->
                        println("⭐ Username: ${user.username}")
                        println("⭐ Matching Repositories:")
                        user.repositories.filter { it.name.contains(repoName, ignoreCase = true) }
                            .forEach { println("   📦 - ${it.name}") }
                        println(ConsoleUI.LINE)
                        println()
                    }
                }
            }
            "5" -> {
                println("👋 Exiting the application. Goodbye!")
                break
            }
            else -> {
                println("❌ [Error] Invalid option. Please try again.\n")
            }
        }
        println()
    }
}