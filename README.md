# `lib_elixir`

**EXPERIMENTAL:** This library should not be used yet.
It is broken in a number of ways and serves mainly as a proof-of-concept.

## Setup

Here's how you can try this out:

1. Clone this repo and add `:lib_elixir` to your list of dependencies as a path dependency:

    ```elixir
    def deps do
      [
        {:lib_elixir, path: "path/to/lib_elixir"}
      ]
    end
    ```

2. Add a `:lib_elixir` with a namespace module, Elixir ref, and target modules to your `mix.exs` project:

    ```elixir
    def project do
      [
        ...,
        lib_elixir: {My.Project.LibElixir, "v1.17.2", [Macro, Macro.Env]}
      ]
    end
    ```

3. Use Elixir modules available under the chosen namespace:

    ```elixir
    alias My.Project.LibElixir.Macro, as: Macro

    struct(Macro.Env, Map.from_struct(__ENV__))
    #=> %My.Project.LibElixir.Macro.Env{...}
    ```

4. Compile and run without protocol consolidation (which is currently broken):

    ```sh
    # Compile for desired environment without protocol consolidation
    $ MIX_ENV=test mix compile --no-protocol-consolidation

    # Run mix commands without additional compilation
    $ mix test --no-compile
    ```
