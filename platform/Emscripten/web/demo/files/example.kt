// Kotlin sample
package com.example.demo

import kotlin.collections.mutableListOf
import kotlinx.coroutines.delay

@Target(AnnotationTarget.CLASS)
annotation class Serializable

enum class Color { RED, GREEN, BLUE }

data class User(val name: String, val age: Int)

sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
}

// generic type
data class DataA<T>(val a: Int) : Result<T>()
open class Container<K, V>(val key: K, val value: V) : Map<K, V>
abstract class Mapper<T : Comparable<T>>(val items: List<T>) : Iterable<T>
class Registry<T>(name: String) : Repository<T> where T : Any

/**
 * A generic repository for managing entities.
 *
 * @param T the type of entity this repository manages
 * @see UserService
 * @since 1.0
 * @sample com.example.demo.UserService
 */
interface Repository<T> {
    /**
     * Finds an entity by its unique identifier.
     *
     * @param id the unique identifier of the entity
     * @return the entity if found, or null
     * @throws IllegalArgumentException if [id] is negative
     * @see UserService#findById
     */
    suspend fun findById(id: Int): T?
    fun getAll(): List<T>
}

@Serializable
class UserService : Repository<User> {
    private val users = mutableListOf<User>()

    override suspend fun findById(id: Int): User? {
        delay(100)
        return users.getOrNull(id)
    }

    override fun getAll(): List<User> = users

    fun add(user: User) {
        users.add(user)
    }
}

// ext fun
fun String.isPalindrome(): Boolean =
    this == this.reversed()

fun main() {
    val service = UserService()
    val user = User("Alice", 30)
    service.add(user)

    // number
    val hex = 0xFF_AB
    val bin = 0b1100_0011
    val long = 100_000L
    val float = 3.14f
    val double = 2.718

    val isValid = true
    val nothing: String? = null

    // string template
    val msg = "User: ${user.name}, Age: ${user.age}"
    val raw = """
        |multi-line
        |raw string
    """.trimMargin()

    // control flow
    val result = when (user.age) {
        in 0..17 -> "minor"
        in 18..64 -> "adult"
        else -> "senior"
    }

    val items = listOf("a", "bb", "ccc")
    for ((index, item) in items.withIndex()) {
        if (item.length > 1) {
            println("$index: $item")
        }
    }

    // lambda
    val squares = items.map { it.length }.filter { it > 1 }
    val owner = false

    /* comment
       multi-line */
}
