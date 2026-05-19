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

    // AGP 8+ requires every Android library to declare a namespace.
    // Register afterEvaluate here — before evaluationDependsOn triggers
    // project evaluation — so it fires as each plugin finishes evaluating.
    afterEvaluate {
        (extensions.findByName("android")
                as? com.android.build.gradle.LibraryExtension)
            ?.apply {
                if (namespace == null) {
                    namespace = group.toString()
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

plugins {
  id("com.google.gms.google-services") version "4.4.4" apply false
}
