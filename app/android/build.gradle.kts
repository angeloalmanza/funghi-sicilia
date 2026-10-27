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
    project.evaluationDependsOn(":app")
}
// tflite_flutter dichiara Java 11 ma Kotlin usa il JDK 17: allinea il target Kotlin alla Java del plugin.
subprojects {
    if (name == "tflite_flutter") {
        tasks.configureEach {
            if (javaClass.name.contains("KotlinCompile")) {
                (this as org.jetbrains.kotlin.gradle.tasks.KotlinCompile).compilerOptions.jvmTarget
                    .set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
