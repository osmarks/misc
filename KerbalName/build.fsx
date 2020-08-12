// include Fake libs
#r "./packages/FAKE/tools/FakeLib.dll"

open Fake

// Directories
let buildDir  = "./build/"
let deployDir = "./deploy/"


// Filesets
let appReferences  =
    !! "/**/*.csproj"
    ++ "/**/*.fsproj"

// version info
let version = "1.2a"

// Targets
Target "Clean" (fun _ ->
    CleanDirs [buildDir; deployDir]
)

Target "Build" (fun _ ->
    MSBuildDebug buildDir "Build" appReferences
    |> Log "AppBuild-Output: "
)

Target "BuildRelease" (fun _ ->
    MSBuildRelease buildDir "Build" appReferences
    |> Log "AppBuild-Output: "
)

Target "Deploy" (fun _ ->
    // Copy name data to buildDir for deployment
    FileUtils.cp_r "KerbalNameData" (buildDir + "KerbalNameData/")

    !! (buildDir + "/**/*.*")
    -- "*.zip"
    |> Zip buildDir (deployDir + "KerbalName." + version + ".zip")
)

// Build order
"Clean"
  ==> "BuildRelease"
  ==> "Deploy"

"Build" <=> "BuildRelease"

// start build
RunTargetOrDefault "Build"
