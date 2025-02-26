open Node
open RescriptTools_Docgen

let stripFileModuleName = (id: string) => {
  id->String.split(".")->Array.sliceToEnd(~start=1)->Array.join(".")
}

/**
  Merge the given identifier into the tree.
  The idea is to make a lookup tree where we can see which properties are exported from which module.
 */
let rec mergeIntoTree = (tree: dict<JSON.t>, identifier: string) => {
  let parts = identifier->String.split(".")
  switch parts->Array.at(0) {
  | None => tree
  | Some(node) if Array.length(parts) == 1 =>
    tree->Dict.set(node, JSON.Boolean(true))
    tree
  | Some(node) => {
      let rest = parts->Array.sliceToEnd(~start=1)->Array.join(".")
      // Check if the node is already in the tree
      switch tree->Dict.get(node) {
      | None =>
        // Merge the rest of the parts into the tree
        let subTree = JSON.Object(mergeIntoTree(dict{}, rest))
        tree->Dict.set(node, subTree)
        tree
      | Some(Object(subTree)) =>
        tree->Dict.set(node, JSON.Object(mergeIntoTree(subTree, rest)))
        tree
      | Some(_) => tree
      }
    }
  }
}

let rec collectReactComponents = (item: item) => {
  switch item {
  | Value({name: "make", detail, id}) =>
    switch detail {
    | Signature({details}) if details.returnType.path == "React.element" => [
        stripFileModuleName(id),
      ]
    | _ => []
    }
  | Module({items}) => items->Array.flatMap(collectReactComponents)
  | _ => []
  }
}

let transform = async (code, resPath: string, ~debug: option<bool>=?) => {
  let log = switch debug {
  | Some(true) => Console.log
  | _ => _ => ()
  }
  let docOutput = await ChildProcess.execAsync(`rescript-tools doc ${resPath}`)
  let json = JSON.parseExn(docOutput)
  let doc = decodeFromJson(json)
  let reactComponents = doc.items->Array.flatMap(collectReactComponents)->Set.fromArray
  if Set.size(reactComponents) == 0 {
    code
  } else {
    log((`React components found: `, reactComponents))
    let tree = reactComponents->Set.toArray->Array.reduce(dict{}, mergeIntoTree)
    log(JSON.stringifyAny(tree))
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
            }) => {
              let localSpecifierName = localSpecifierName->String.replace("$$", "")
              switch tree->Dict.get(localSpecifierName) {
              | None => {
                  // Remove potential export specifiers that are not React components
                  // Console.log(`Removing export specifier ${localSpecifierName}`)
                  log(`Removing export specifier ${localSpecifierName}`)
                  magicString->MagicString.remove(start - 2., end + 2.)
                }
              | Some(Boolean(true)) => 
                // The top level make function
                ()
              | Some(Object(_)) => ()
              | Some(v) => log((`Unexpected value in tree for ${localSpecifierName}`, v))
              }
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
      "/Users/nojaf/Projects/vite-plugin-rescript/tests/DeepNested.res.mjs",
    )
    let _ = await transform(
      code,
      "/Users/nojaf/Projects/vite-plugin-rescript/tests/DeepNested.res",
      ~debug=true,
    )
  }
| _ => ()
}
