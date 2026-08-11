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
// Plugin subprojects with native code (`:jni`, via path_provider_android) pick
// up flutter.ndkVersion independently of :app, so a per-machine override has to
// reach them too. No-op unless ndk.version is set in local.properties.
//
// Must be registered *before* the evaluationDependsOn block below: that one
// force-evaluates `:app`, and afterEvaluate throws on an already-evaluated
// project.
val ndkOverride: String? = java.util.Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}.getProperty("ndk.version")

if (ndkOverride != null) {
    subprojects {
        afterEvaluate {
            extensions
                .findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.ndkVersion = ndkOverride
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
