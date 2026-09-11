group = "dev.tiktokauth.android"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

// The TikTok OpenSDK is published to ByteDance's Maven repository, not to
// Maven Central. The app resolves this plugin's dependencies with its own
// repositories, so the repository is registered for every project in the
// build. Apps that forbid project repositories must add it themselves.
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://artifact.bytedance.com/repository/AwemeOpenSDK")
            content { includeGroup("com.tiktok.open.sdk") }
        }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "dev.tiktokauth.android"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            // The unit tests do not need resources. Including them would merge
            // the manifest, whose redirect placeholders only the app provides.
            isIncludeAndroidResources = false
            isReturnDefaultValues = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.tiktok.open.sdk:tiktok-open-sdk-core:2.4.0")
    implementation("com.tiktok.open.sdk:tiktok-open-sdk-auth:2.4.0")
    // The TikTok SDK's POM declares no dependencies, but its classes use
    // Custom Tabs, so the dependency is declared here.
    implementation("androidx.browser:browser:1.10.0")
    // Pigeon's generated Kotlin runs async host methods in coroutines.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
