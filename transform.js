import { parseAsync } from "oxc-parser";

/**
 * @import { Program } from "oxc-parser"
 */

function isUpperCase(string) {
    return /^[A-Z]/.test(string);
}

/**
 *
 * @param {Program} program
 * @param {string} name
 * @returns {boolean}
 */
function isReactComponent(program, name) {
    let alias = null;
    let property = null;

    for (const node of program.body) {
        if (node.type === "FunctionDeclaration" && node.id?.name === name) {
            return isUpperCase(node.id.name);
        }

        if (node.type === "VariableDeclaration" && node.declarations.length === 1) {
            const declaration = node.declarations[0];

            if (declaration.type === "VariableDeclarator" && declaration.id.name === name) {
                if (declaration.init?.type === "Identifier") {
                    alias = declaration.init.name;
                } else if (declaration.init?.type === "ObjectExpression") {
                    const makeProperty = declaration.init.properties.find(
                        (property) => property.key.name === "make"
                    );
                    if (makeProperty) {
                        property = makeProperty.value.name;
                    }
                }
            }
        }
    }

    if (alias) {
        return isReactComponent(program, alias);
    }

    if (property) {
        return isReactComponent(program, property);
    }

    return false;
}

export async function transform(code, id) {
    if (!/\.res\.mjs$/.test(id)) {
        return;
    }

    console.log(id);
    const { program, magicString } = await parseAsync(id, code);
    const exportNamedDeclaration = program.body.find(
        (node) => node.type === "ExportNamedDeclaration",
    );
    if (!exportNamedDeclaration) {
        return;
    }

    const exportedItems =
        exportNamedDeclaration.specifiers.map((specifier) => [
            specifier,
            isReactComponent(program, specifier.local.name),
        ]);


    const allItemsAreReactComponents = exportedItems.every(
        ([, isReactComponent]) => isReactComponent,
    );

    if (allItemsAreReactComponents) {
        return;
    }

    for (const [exportSpecifier, isReactComponent] of exportedItems) {
        if (isReactComponent) {
            continue;
        }

        // The start of the specifier - 2 to include the leading spaces
        // The end of the specifier + 1 to include the comma
        magicString.remove(exportSpecifier.start -2 , exportSpecifier.end + 1);
    }

    return magicString.toString();
}
