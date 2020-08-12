open System
open System.Numerics

type Stack = StackContents of Complex list

let splitPart (what:char) index (stringIn:string) = stringIn.Split(what).[index]
let spliti = splitPart 'i'
let firstInSpliti = spliti 0
let secondInSpliti = spliti 1
let isDoubleAsString text = System.Double.TryParse text |> fst
let doubleFromString text = System.Double.TryParse text |> snd
let isImaginaryAsString (text:string) =
  match text.Contains("i") with
  | false -> false
  | true ->
    let normalPart = firstInSpliti text
    isDoubleAsString normalPart
let imaginaryFromString text =
  let imaginaryPart = doubleFromString (firstInSpliti text)
  Complex(0.0, imaginaryPart)

let showStack (StackContents contents) =
  printfn "%A" contents // Print unpacked StackContents with formatting string
  StackContents (contents) // Repack the StackContents

let push value (StackContents contents) =
  StackContents (value::contents)

let pop (StackContents contents) =
  match contents with
  | top::rest -> // Separate top from rest
    (top, StackContents rest) // Stack contents must be the StackContents type.
  | [] -> // Check for stack underflow
    failwith "Stack underflow"

let binary func stack =
  let x, newStack = pop stack
  let y, newestStack = pop newStack
  let z = func y x // This is deliberately swapped, because we are working on a stack
  push z newestStack

let unary func stack =
  let x, newStack = pop stack
  push (func x) stack

let dup stack =
  let x, _ = pop stack // Drop the new stack, we want to duplicate "x"
  push x stack

let swap stack =
  let x, newStack = pop stack
  let y, newerStack = pop newStack
  push y (push x newerStack)

let drop stack =
  let _, newStack = pop stack // Pop one off the top and ignore it
  newStack

let numberInput value stack = push value stack

let add = binary (+)
let multiply = binary (*)
let subtract = binary (-)
let divide = binary (/)
let negate = unary (fun x -> -(x))
let square = unary (fun x -> x * x)
let cube = dup >> dup >> multiply >> multiply
let exponent =  binary ( ** )

let show stack =
  let value, _ = pop(stack)
  printfn "%A" value
  stack // We're going to keep the same stack as before.

let empty = StackContents []

let splitString (text:string) = text.Split ' '

let processTokenString stack token =
  match token with
  | "*" -> stack |> multiply
  | "+" -> stack |> add
  | "/" -> stack |> divide
  | "+-" -> stack |> negate
  | "sqr" -> stack |> square
  | "cub" -> stack |> cube
  | "**" | "^" -> stack |> exponent
  | _ when isDoubleAsString token ->
    let doubleInString = doubleFromString token
    numberInput (Complex(doubleInString, 0.0)) stack
  | _ when isImaginaryAsString token ->
    let imaginaryInString = imaginaryFromString token
    numberInput imaginaryInString stack
  | _ -> showStack stack // For easier debugging.

Console.Write("Please enter your expression here: ")
let userExpression = Console.ReadLine()
let splitExpression = splitString userExpression

let resultantStack = List.fold processTokenString (empty) (Array.toList splitExpression) |> showStack
