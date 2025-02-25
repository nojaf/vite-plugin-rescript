open Node
open RescriptTools_Docgen

let stripFileModuleName = (id: string) => {
  id->String.split(".")->Array.sliceToEnd(~start=1)->Array.join(".")
}

let collectReactComponents = (item: item) => {
  switch item {
  | Value({name: "make", detail, id}) =>
    switch detail {
    | Signature({details}) if details.returnType.path == "React.element" => [
        stripFileModuleName(id),
      ]
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
    Console.log(reactComponents)
    // parse JavaScript code to AST and modify exports
    open OxcParser

    let {program, magicString} = await parseAsync(`${resPath}.mjs`, code)
    program.body->Array.forEach(statement => {
      switch statement {
      | dict{"type": JSON.String("ExportNamedDeclaration"), "specifiers": Array(specifiers)} =>
        specifiers->Array.forEach(specifier => {
          switch specifier {
          | JSON.Object(dict{
              "type": JSON.String("ExportSpecifier"),
              "local": JSON.Object(dict{"name": JSON.String(localSpecifierName)}),
              "start": JSON.Number(start),
              "end": JSON.Number(end),
            }) =>
            if !(reactComponents->Set.has(localSpecifierName)) {
              // Remove potential export specifiers that are not React components
              // Console.log(`Removing export specifier ${localSpecifierName}`)
              magicString->MagicString.remove(start - 2., end + 2.)
            }
          | _ => ()
          }
        })
      | _ => ()
      }
    })
    let nextCode = magicString->MagicString.toString
    nextCode
  }
}

@scope(("import", "meta"))
external isMain: option<bool> = "main"

switch isMain {
| Some(true) => {
    let code = await Node.FsPromises.readFile(
      "/Users/nojaf/Projects/vite-plugin-rescript/tests/Initial.res.mjs",
    )
    let _ = await transform(code, "/Users/nojaf/Projects/vite-plugin-rescript/tests/Initial.res")
  }
| _ => ()
}
