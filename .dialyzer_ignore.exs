[
  # Ecto.Multi opaque type false positives (MapSet internal representation)
  # These are well-known false positives: https://github.com/elixir-ecto/ecto/issues/2693
  {"lib/jalka2026/accounts.ex", :call_without_opaque},
  {"lib/jalka2026/badges.ex", :call_without_opaque},
  {"lib/jalka2026/football.ex", :call_without_opaque}
]
