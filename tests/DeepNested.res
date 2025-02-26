module A = {
  module B = {
    let sum = (a, b) => a + b
    module C = {
      @react.component
      let make = () => {
        React.string("String")
      }
    }

    module D = {
      @react.component
      let make = () => {
        React.int(3)
      }
    }
  }
}
