allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build output is redirected outside the repo (which lives under OneDrive)
// to avoid OneDrive's real-time sync locking Gradle's intermediate files
// mid-build, and to avoid colliding with the unrelated native Android
// project's own build/ directory at the repo root.
val newBuildDir: Directory =
    rootProject.layout.projectDirectory.dir("C:/gradle-builds/mobile_app")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
