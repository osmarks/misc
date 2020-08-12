module Kerbal.Names

open Argu

let readLinesFrom file =
    use reader = new System.IO.StreamReader(path=file)
    reader.ReadToEnd().Split('\n')
    |> List.ofArray

type CommandLineArgument =
| [<AltCommandLine("-q")>] Quantity of int
| [<AltCommandLine("-s")>] Separator of string
| [<AltCommandLine("-d")>] DataDir of string
with
    interface IArgParserTemplate with
        member this.Usage =
            match this with
            | Quantity _ -> "How many names to generate (defaults to 1)"
            | Separator _ -> "What to separate generated names with (defaults to newline)"
            | DataDir _ -> "Where the program's datafiles can be found (defaults to KerbalNameData under working directory)"
            
module RNG =
    let seedGenerator = System.Random()
    let localGenerator = new System.Threading.ThreadLocal<System.Random>(fun _ -> 
        lock seedGenerator (fun _ -> 
            let seed = seedGenerator.Next()
            new System.Random(seed)))
    
    // Returns a version of System.Random using the threadlocal RNG.
    // NOTE: Most functions are NOT thread-safe in this version.
    let getRand() = {new System.Random() with member this.Next(lim) = localGenerator.Value.Next(lim)}

let inline randomChoice (rand : System.Random) (list:'a list) =
    list.[rand.Next(list.Length)]

let inline generateHybridName rand prefixList suffixList =
    (randomChoice rand prefixList) + (randomChoice rand suffixList)

let genName (rand : System.Random) properNames namePrefixes nameSuffixes =
    if rand.Next(20) = 20 then
        randomChoice rand properNames
    else
        generateHybridName rand namePrefixes nameSuffixes

[<EntryPoint>]
let main argv =
    // Construct CLI parser with programname taken from env variables
    let argParser = ArgumentParser.Create<CommandLineArgument>(programName = (Array.head <| System.Environment.GetCommandLineArgs()))

    let parseResults = argParser.Parse argv
    let dataDir = parseResults.GetResult(<@ DataDir @>, defaultValue = "KerbalNameData") + "/" // Append a slash in case missing
    let quantity = parseResults.GetResult(<@ Quantity @>, defaultValue = 1)
    let separator = parseResults.GetResult(<@ Separator @>, defaultValue = "\n")

    // Access name datafiles
    let properNames = readLinesFrom (dataDir + "Proper.txt")
    let namePrefixes = readLinesFrom (dataDir + "Prefixes.txt")
    let nameSuffixes = readLinesFrom (dataDir + "Suffixes.txt")

    let rand = RNG.getRand()

    let printingMailbox = MailboxProcessor.Start(fun inbox ->
        let rec loop () = async {
                let! msg = inbox.Receive()
                printf "%s" msg
                return! loop()
            }

        loop()
    )

    System.Threading.Tasks.Parallel.For(0, quantity, fun idx ->
        genName rand properNames namePrefixes nameSuffixes
        |> (fun name -> printingMailbox.Post(name + separator))
    ) |> ignore // We do not care about the result which came from the parallel loop.

    0