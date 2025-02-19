let sum = (a, b) => a + b

module Integer = {
  @react.component
  let make = () => {
    React.int(1)
  }

  type t = int

  let sum = (a: t, b: t) => a + b
}

module Float = {
  @react.component
  let make = () => {
    React.float(1.0)
  }
}

module Array = {
  @react.component
  let make = () => {
    React.array([])
  }
}

module String = {
  @react.component
  let make = () => {
    React.string("String")
  }
}
