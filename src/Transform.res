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
  let reactComponents = doc.items->Array.flatMap(collectReactComponents)->Set.fromArray
  if Set.size(reactComponents) == 0 {
    code
  } else {
    // parse JavaScript code to AST and modify exports
    open OxcParser

    let {program, magicString} = await parseAsync(`${resPath}.mjs`, code)
    program.body->Array.forEach(statement => {
      switch statement {
      | dict{"type": JSON.String("ExportNamedDeclaration"), "specifiers": Array(specifiers)} => {
          let exportSpecifiers = specifiers->Array.flatMap(specifier => {
            switch specifier {
            | JSON.Object(dict{"type": JSON.String("ExportSpecifier")} as specifier) => [specifier]
            | _ => []
            }
          })

          // Remove potential export specifiers that are not React components
          Console.log(exportSpecifiers)
        }
      | _ => ()
      }
    })
    magicString->MagicString.toString
  }
}

let code = await Node.FsPromises.readFile(
  "/Users/nojaf/Projects/vite-plugin-rescript/tests/Initial.res.mjs",
)
let _ = await transform(code, "/Users/nojaf/Projects/vite-plugin-rescript/tests/Initial.res")
