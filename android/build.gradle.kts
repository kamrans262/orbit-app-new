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
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
