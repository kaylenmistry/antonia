# Check https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-configuration-file
[
  tools: [
    {:compiler, "mix compile --force --warnings-as-errors"},
    {:credo, "mix credo --strict"},
    {:sobelow, "mix sobelow -i Config.HTTPS --exit --skip"},
    {:mix_audit, "mix deps.audit"},
    {:ex_unit, "mix coveralls --trace",
     detect: [{:file, "test"}], retry: "mix test --trace --failed"},
    {:npm_test, false}
  ]
]
