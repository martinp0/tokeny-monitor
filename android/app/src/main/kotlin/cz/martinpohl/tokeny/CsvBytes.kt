package cz.martinpohl.tokeny

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import cz.martinpohl.tokeny.core.CsvLimits
import java.io.ByteArrayOutputStream

sealed class CsvBytesRead {
    data class Ok(val name: String, val bytes: ByteArray) : CsvBytesRead()
    data object TooLarge : CsvBytesRead()
    data object Unreadable : CsvBytesRead()
}

fun readCsvBytes(resolver: ContentResolver, uri: Uri): CsvBytesRead {
    val name = displayName(resolver, uri)
    val reported = reportedSize(resolver, uri)
    if (reported != null && reported > CsvLimits.MAX_FILE_BYTES) return CsvBytesRead.TooLarge
    return try {
        resolver.openInputStream(uri).use { input ->
            if (input == null) return CsvBytesRead.Unreadable
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                total += n
                if (total > CsvLimits.MAX_FILE_BYTES) return CsvBytesRead.TooLarge
                out.write(buffer, 0, n)
            }
            CsvBytesRead.Ok(name, out.toByteArray())
        }
    } catch (_: Exception) {
        CsvBytesRead.Unreadable
    }
}

private fun displayName(resolver: ContentResolver, uri: Uri): String {
    val cursor = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
    cursor?.use {
        if (it.moveToFirst()) {
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0) return it.getString(index)?.takeIf { name -> name.isNotBlank() } ?: "import.csv"
        }
    }
    return "import.csv"
}

private fun reportedSize(resolver: ContentResolver, uri: Uri): Long? {
    val cursor = resolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null) ?: return null
    cursor.use {
        if (!it.moveToFirst()) return null
        val index = it.getColumnIndex(OpenableColumns.SIZE)
        if (index < 0 || it.isNull(index)) return null
        return it.getLong(index)
    }
}
