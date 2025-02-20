let sum = (a, b) => a + b

@react.component
let make =
  // See https://github.com/vitejs/vite-plugin-react/issues/414

  @directive("'react/jsx-runtime'")
  () => {
    React.string("String")
  }
