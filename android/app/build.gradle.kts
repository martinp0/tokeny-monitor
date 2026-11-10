import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

kotlin {
    jvmToolchain(21)
}

// Release signing comes only from the environment, Gradle properties, or an
// untracked android/keystore.properties. The prepared key is PKCS12, alias
// tokeny-release, with the key password equal to the store password.
// None of those values belong in git. With all four unset, release stays unsigned.
val releaseSigningNames = listOf(
    "TOKENY_KEYSTORE_FILE",
    "TOKENY_KEYSTORE_PASSWORD",
    "TOKENY_KEY_ALIAS",
    "TOKENY_KEY_PASSWORD",
)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun releaseSecret(name: String): String? {
    System.getenv(name)?.takeIf { it.isNotBlank() }?.let { return it }
    (findProperty(name) as String?)?.takeIf { it.isNotBlank() }?.let { return it }
    return keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
}

val releaseSigning = releaseSigningNames.associateWith { releaseSecret(it) }
val releaseSigningProvided = releaseSigning.values.count { it != null }
if (releaseSigningProvided != 0 && releaseSigningProvided != releaseSigningNames.size) {
    val missing = releaseSigning.filterValues { it == null }.keys.sorted().joinToString(", ")
    throw GradleException(
        "Release signing needs all of ${releaseSigningNames.joinToString(", ")}, or none of them. Missing: $missing",
    )
}
val signRelease = releaseSigningProvided == releaseSigningNames.size

android {
    namespace = "cz.martinpohl.tokeny"
    compileSdk = 37

    defaultConfig {
        applicationId = "cz.martinpohl.tokeny"
        minSdk = 26
        targetSdk = 37
        versionCode = 2
        versionName = "0.2.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (signRelease) {
            create("release") {
                val storePath = releaseSigning.getValue("TOKENY_KEYSTORE_FILE")!!
                val store = file(storePath)
                if (!store.isFile) {
                    throw GradleException("TOKENY_KEYSTORE_FILE does not point at a file. Do not commit the keystore.")
                }
                storeFile = store
                storePassword = releaseSigning.getValue("TOKENY_KEYSTORE_PASSWORD")
                keyAlias = releaseSigning.getValue("TOKENY_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("TOKENY_KEY_PASSWORD")
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            // R8 stays off. The ledger uses kotlinx.serialization and the unit tests
            // do not run the minified release binary, so shrinking could drop those
            // serializers without a failing test.
            isMinifyEnabled = false
            if (signRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    buildFeatures {
        compose = true
    }

    lint {
        lintConfig = file("lint.xml")
        abortOnError = true
        checkDependencies = true
    }
}

dependencies {
    implementation(project(":core"))
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.viewmodel)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.coroutines.android)
    implementation(libs.androidx.core)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext)
    androidTestImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.espresso.intents)
    androidTestImplementation(libs.uiautomator)
}
