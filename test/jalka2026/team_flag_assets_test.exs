defmodule Jalka2026.TeamFlagAssetsTest do
  @moduledoc """
  Guards against the regression where `teams.flag` was pointed at local
  `/images/flags/<iso>.svg` paths (by the seed parser and the
  `*_team_flags_to_local` migrations) without the backing SVG files being
  committed, leaving broken flag images across the app (favourite-team
  badges on the leaderboard, fixture flags, profiles, ...).
  """
  use ExUnit.Case, async: true

  # Source files that produce local flag paths. The deploy step copies
  # `assets/static/.` into `priv/static`, so the SVGs must live here.
  @source_files [
    "lib/jalka2026/seed/parser.ex"
    | Path.wildcard("priv/repo/migrations/*team_flags*.exs")
  ]

  @flags_dir "assets/static/images/flags"

  test "every referenced local flag path has a committed SVG file" do
    referenced =
      @source_files
      |> Enum.flat_map(fn file ->
        Regex.scan(~r{/images/flags/([a-z-]+)\.svg}, File.read!(file))
        |> Enum.map(fn [_full, code] -> code end)
      end)
      |> Enum.uniq()
      |> Enum.sort()

    # Sanity check that we actually scanned something meaningful.
    assert length(referenced) > 30,
           "expected to find many flag references; the scan may be broken"

    missing =
      Enum.reject(referenced, fn code ->
        File.exists?(Path.join(@flags_dir, "#{code}.svg"))
      end)

    assert missing == [],
           "missing flag SVG files in #{@flags_dir}: " <>
             Enum.map_join(missing, ", ", &"#{&1}.svg")
  end

  test "committed flag files are non-empty SVG documents" do
    for path <- Path.wildcard(Path.join(@flags_dir, "*.svg")) do
      contents = File.read!(path)
      assert byte_size(contents) > 0, "#{path} is empty"
      assert contents =~ "<svg", "#{path} does not look like an SVG"
    end
  end
end
