# LibElixir Integration Tests

This project contains integration tests for `lib_elixir`.

## Running tests

Tests can be run from the top-level `lib_elixir` source directory with:

```sh
$ ./integration_test/test.sh
```

The ref used to specify the version of Elixir to be compiled can be changed using the `LIB_ELIXIR_REF` environment variable.
For instance:

```sh
$ LIB_ELIXIR_REF=v1.15.4 ./integration_test/test.sh
$ LIB_ELIXIR_REF=cf49f8b ./integration_test/test.sh
```
