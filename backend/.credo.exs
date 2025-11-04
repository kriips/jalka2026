%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: ["_build/", "deps/"]
      },
      checks: [
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Design.TagTODO, [exit_status: 0]},
        {Credo.Check.Refactor.LongQuoteBlocks, []}
      ]
    }
  ]
}

# NOTE (T008): Additional contexts added for ingestion & scoring; ensure naming follows Jalka2026.<Area> pattern.
