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
    @SerializedName("created_at")
    val createdAt: String
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
                println("[Error] Failed to load cache: ${e.message}")
            }
        }
    }

    private fun saveCache() {
        val file = File(cacheFileName)
        try {
            val json = gson.toJson(users.values.toList())
            file.writeText(json)
        } catch (e: Exception) {
            println("[Error] Failed to save cache: ${e.message}")
        }
    }

    fun addUser(user: GitHubUser) {
        users[user.username] = user
        saveCache()
    }

    fun getAllUsers(): List<GitHubUser> = users.values.toList()

    fun findUserByUsername(username: String): GitHubUser? = users[username]

    fun searchUsersByRepoName(repoName: String): List<GitHubUser> {
        return users.values.filter { user ->
            user.repositories.any { it.name.contains(repoName, ignoreCase = true) }
        }
    }
}

fun printHeader() {
    println("=======================================")
    println("         GitHub User Fetcher           ")
    println("=======================================")
}

fun printMenu() {
    println(
        """
        1. Fetch GitHub user information by username
        2. Display all saved users
        3. Search for a user by username
        4. Search for users by repository name
        5. Exit
        """.trimIndent()
    )
    println("=======================================")
}

fun printUser(user: GitHubUser) {
    println("Username         : ${user.username}")
    println("Followers        : ${user.followers}")
    println("Following        : ${user.following}")
    println("Account Created  : ${user.createdAt}")
    println("Repositories     :")
    if (user.repositories.isEmpty()) {
        println("   No repositories available.")
    } else {
        user.repositories.forEach { println("   - ${it.name}") }
    }
    println("=======================================")
}

fun main() = runBlocking {
    val gitHubService = GitHubService()

    while (true) {
        printHeader()
        printMenu()
        print("Your choice: ")
        when (readLine()?.trim()) {
            "1" -> {
                print("Enter GitHub username: ")
                val username = readLine()?.trim() ?: ""
                if (username.isEmpty()) {
                    println("\n[Error] Username cannot be empty!\n")
                    continue
                }
                if (FileCacheManager.findUserByUsername(username) != null) {
                    println("\n[Info] User '$username' is already saved.\n")
                } else {
                    println("\nFetching data for user '$username'...\n")
                    val result = gitHubService.fetchUser(username)
                    result.fold(
                        onSuccess = { user ->
                            FileCacheManager.addUser(user)
                            println("[Success] User data fetched successfully:")
                            printUser(user)
                        },
                        onFailure = { error ->
                            println("[Error] Failed to fetch user data: ${error.message}\n")
                        }
                    )
                }
            }
            "2" -> {
                val users = FileCacheManager.getAllUsers()
                if (users.isEmpty()) {
                    println("\n[Info] No users saved yet.\n")
                } else {
                    println("\n[Saved Users]")
                    users.forEach { user -> printUser(user) }
                }
            }
            "3" -> {
                print("Enter username to search: ")
                val searchUsername = readLine()?.trim() ?: ""
                val user = FileCacheManager.findUserByUsername(searchUsername)
                if (user != null) {
                    println("\n[User Found]")
                    printUser(user)
                } else {
                    println("\n[Info] User not found.\n")
                }
            }
            "4" -> {
                print("Enter repository name to search: ")
                val repoName = readLine()?.trim() ?: ""
                val matchedUsers = FileCacheManager.searchUsersByRepoName(repoName)
                if (matchedUsers.isEmpty()) {
                    println("\n[Info] No users found with a matching repository.\n")
                } else {
                    println("\n[Users with Matching Repository]")
                    matchedUsers.forEach { user ->
                        println("Username: ${user.username}")
                        println("Matching Repositories:")
                        user.repositories.filter { it.name.contains(repoName, ignoreCase = true) }
                            .forEach { println("   - ${it.name}") }
                        println("=======================================")
                    }
                }
            }
            "5" -> {
                println("\nExiting the application. Goodbye!")
                break
            }
            else -> {
                println("\n[Error] Invalid option. Please try again.\n")
            }
        }
        println()
    }
}
