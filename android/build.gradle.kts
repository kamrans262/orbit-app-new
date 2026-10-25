allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Workmanager Android 0.9.x skips the Kotlin Gradle plugin under AGP 9.
    // Orbit explicitly uses android.builtInKotlin=false because other plugins
    // require KGP. Apply it ONLY to Workmanager's Android module, after the
    // Android library plugin loads, so its native Kotlin implementation and
    // Flutter plugin registrant class are compiled.
    if (name == "workmanager_android") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            // Workmanager Android 0.9.2 defaults JavaCompile to 1.8 while
            // Orbit's KGP compiles its Kotlin sources to JVM 17. Gradle
            // rejects mixed bytecode targets in the same plugin module.
            // Align ONLY this plugin's Java tasks; do not alter the app's
            // or any other dependency's compilation configuration.
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
