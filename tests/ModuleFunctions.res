module Foo = (
  T: {
    let a: string
  },
) => {
  let b = () => T.a
}

include Foo({
  let a = "Yow!"
})
