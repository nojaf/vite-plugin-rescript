module A = {
  module B = {
    module C = {
      @react.component
      let make = () => {
        React.string("String")
      }
    }
  }
}
