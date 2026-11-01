package com.example.visual_song_book

import com.healthmarketscience.jackcess.DatabaseBuilder
import com.healthmarketscience.jackcess.Database
import com.healthmarketscience.jackcess.Row
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

internal object VsbAccessConverter {
    fun convert(inputPath: String, cacheDir: File): String {
        val inputFile = File(inputPath)
        require(inputFile.isFile) { "Access songbook file was not found." }

        val categories = JSONArray()
        val songs = JSONArray()
        System.setProperty("com.healthmarketscience.jackcess.brokenNio", "true")
        System.setProperty("com.healthmarketscience.jackcess.resourcePath", "/res/raw/")
        Thread.currentThread().contextClassLoader = Database::class.java.classLoader
        DatabaseBuilder(inputFile).setReadOnly(true).open().use { database ->
            database.getTable("Categories")?.forEach { row ->
                val id = integer(row, "ID", "id") ?: return@forEach
                val name = string(row, "Name", "name")?.trim().orEmpty()
                if (name.isNotEmpty()) {
                    categories.put(JSONObject().put("id", id).put("name", name))
                }
            }

            val songsTable = database.getTable("Songs")
                ?: error("No Songs table was found in the Access file.")
            for (row in songsTable) {
                val songNum = integer(row, "SongNum", "song_num", "SongID") ?: continue
                val title = string(row, "Title", "title")?.trim().orEmpty()
                val body = string(row, "Body", "body")
                    ?.replace("\r\r\n", "\n")
                    ?.replace("\r\n", "\n")
                    ?.replace('\r', '\n')
                    ?.trim()
                    .orEmpty()
                if (title.isEmpty() || body.isEmpty()) continue

                val song = JSONObject()
                    .put("song_num", songNum)
                    .put("title", title)
                    .put("body", body)
                    .put("source_format", "vsb")
                putValue(song, "key", string(row, "Key", "key")?.trim())
                putValue(song, "author", string(row, "Author", "author")?.trim())
                putValue(song, "copyright", string(row, "Copyright", "copyright")?.trim())
                putValue(song, "search", string(row, "Search", "search")?.trim())
                putValue(song, "category_id", integer(row, "CategoryId", "category_id"))
                putValue(song, "source_song_id", integer(row, "SongID", "source_song_id"))
                putValue(song, "modified", isoDate(value(row, "Modified", "modified")))
                songs.put(song)
            }
        }

        val metadata = JSONObject()
            .put("app", "Visual Song Book")
            .put("exported_at", isoDate(Date()))
            .put("format", "json")
            .put("song_count", songs.length())
            .put("category_count", categories.length())

        val output = File.createTempFile("vsb-converted-", ".vsbook", cacheDir)
        ZipOutputStream(FileOutputStream(output)).use { zip ->
            addEntry(zip, "metadata.json", metadata.toString())
            addEntry(zip, "songs.json", songs.toString())
            addEntry(zip, "categories.json", categories.toString())
        }
        return output.absolutePath
    }

    private fun value(row: Row, vararg names: String): Any? {
        for (name in names) {
            try {
                row[name]?.let { return it }
            } catch (_: IllegalArgumentException) {
                // The field is absent in this version of the Access schema.
            }
        }
        return null
    }

    private fun string(row: Row, vararg names: String): String? =
        value(row, *names)?.toString()

    private fun integer(row: Row, vararg names: String): Int? {
        val raw = value(row, *names) ?: return null
        return when (raw) {
            is Number -> raw.toInt()
            else -> raw.toString().toDoubleOrNull()?.toInt()
        }
    }

    private fun isoDate(raw: Any?): String? {
        if (raw !is Date) return raw?.toString()
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(raw)
    }

    private fun putValue(json: JSONObject, key: String, value: Any?) {
        json.put(key, value ?: JSONObject.NULL)
    }

    private fun addEntry(zip: ZipOutputStream, name: String, value: String) {
        zip.putNextEntry(ZipEntry(name))
        zip.write(value.toByteArray(Charsets.UTF_8))
        zip.closeEntry()
    }
}
