open Node
open RescriptTools_Docgen

let collectReactComponents = (item: item) => {
  switch item {
  | Value({name: "make", detail, id}) =>
    switch detail {
    | Signature({details}) if details.returnType.path == "React.element" => [id]
    | _ => []
    }
  | _ => []
  }
}

let transform = async (code, resPath: string) => {
  let docOutput = await ChildProcess.execAsync(`rescript-tools doc ${resPath}`)
  let json = JSON.parseExn(docOutput)
  let doc = decodeFromJson(json)
  let hasReactComponent = doc.items->Array.flatMap(collectReactComponents)->Set.fromArray
  Console.log2(hasReactComponent, doc)
  code
}

let _ = await transform("", "/Users/nojaf/Projects/vite-plugin-rescript/tests/Initial.res")
