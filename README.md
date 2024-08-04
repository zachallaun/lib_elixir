# `lib_elixir`

**EXPERIMENTAL:** This library should not be used yet.
It is broken in a number of ways and serves mainly as a proof-of-concept.

## Setup

Here's how you can try this out:

1. Clone this repo and add `:lib_elixir` to your list of dependencies as a path dependency:

    ```elixir
    def deps do
      [
        {:lib_elixir, path: "path/to/lib_elixir", runtime: false}
      ]
    end
    ```

2. Add a `:lib_elixir` with a namespace module, Elixir ref, and target modules to your `mix.exs` project:

    ```elixir
    def project do
      [
        ...,
        lib_elixir: [
          namespace: My.Project.LibElixir,
          ref: "v1.17.2",
          modules: [Macro, Macro.Env]
        ]
      ]
    end
    ```

3. Use Elixir modules available under the chosen namespace:

    ```elixir
    alias My.Project.LibElixir.Macro, as: Macro

    struct(Macro.Env, Map.from_struct(__ENV__))
    #=> %My.Project.LibElixir.Macro.Env{...}
    ```
