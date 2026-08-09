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
// Plugin subprojects with native code (`:jni`, pulled in by path_provider_android)
// default to flutter.ndkVersion — 28.2.13676358 — which is a failed partial
// install on this machine. Redirect every Android subproject to the complete
// local NDK so nothing has to be re-downloaded.
//
// This must be registered *before* the evaluationDependsOn block below: that one
// force-evaluates `:app`, and afterEvaluate throws on an already-evaluated
// project.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.ndkVersion = "27.1.12297006"
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
