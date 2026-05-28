defmodule Jalka2026.Football.ThirdPlaceSeeding do
  @moduledoc """
  FIFA 2026 World Cup third-place team seeding lookup table.

  With 12 groups (A-L), the top 2 from each group advance directly to the
  Round of 32, plus the 8 best third-place teams. This module determines
  which 3rd-place teams face which group winners in the Round of 32, based
  on which 8 groups' 3rd-place teams qualify.

  There are C(12,8) = 495 possible combinations. Each combination has a
  specific, FIFA-defined seeding that determines the matchups. The 8 slots
  for 3rd-place teams in the Round of 32 are opposite the winners of
  groups A, B, D, E, G, I, K, and L.

  ## Data source

  The seeding table is sourced from the official FIFA regulations for the
  2026 World Cup (Annex C, pages 41-49).
  """

  # Each entry maps a sorted string of 8 qualifying group letters to the
  # seeding assignment. The seeding is a map:
  #   %{a: X, b: Y, d: Z, e: W, g: V, i: U, k: T, l: S}
  # meaning "3rd place from group X faces the winner of group A", etc.
  #
  # The keys (:a, :b, :d, :e, :g, :i, :k, :l) are the group winners that
  # play against a 3rd-place team in the Round of 32.
  # The values are atoms representing which 3rd-place group team fills that slot.

  @seeding_table %{
    # Row 1
    "EFGHIJKL" => %{a: :E, b: :J, d: :I, e: :F, g: :H, i: :G, k: :L, l: :K},
    # Row 2
    "DFGHIJKL" => %{a: :H, b: :G, d: :I, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 3
    "DEGHIJKL" => %{a: :E, b: :J, d: :I, e: :D, g: :H, i: :G, k: :L, l: :K},
    # Row 4
    "DEFHIJKL" => %{a: :E, b: :J, d: :I, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 5
    "DEFGIJKL" => %{a: :E, b: :G, d: :I, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 6
    "DEFGHJKL" => %{a: :E, b: :G, d: :J, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 7
    "DEFGHIKL" => %{a: :E, b: :G, d: :I, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 8
    "DEFGHIJL" => %{a: :E, b: :G, d: :J, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 9
    "DEFGHIJK" => %{a: :E, b: :G, d: :J, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 10
    "CFGHIJKL" => %{a: :H, b: :G, d: :I, e: :C, g: :J, i: :F, k: :L, l: :K},
    # Row 11
    "CEGHIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :H, i: :G, k: :L, l: :K},
    # Row 12
    "CEFHIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 13
    "CEFGIJKL" => %{a: :E, b: :G, d: :I, e: :C, g: :J, i: :F, k: :L, l: :K},
    # Row 14
    "CEFGHJKL" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 15
    "CEFGHIKL" => %{a: :E, b: :G, d: :I, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 16
    "CEFGHIJL" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :F, k: :L, l: :I},
    # Row 17
    "CEFGHIJK" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :F, k: :I, l: :K},
    # Row 18
    "CDGHIJKL" => %{a: :H, b: :G, d: :I, e: :C, g: :J, i: :D, k: :L, l: :K},
    # Row 19
    "CDFHIJKL" => %{a: :C, b: :J, d: :I, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 20
    "CDFGIJKL" => %{a: :C, b: :G, d: :I, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 21
    "CDFGHJKL" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 22
    "CDFGHIKL" => %{a: :C, b: :G, d: :I, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 23
    "CDFGHIJL" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 24
    "CDFGHIJK" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 25
    "CDEHIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 26
    "CDEGIJKL" => %{a: :E, b: :G, d: :I, e: :C, g: :J, i: :D, k: :L, l: :K},
    # Row 27
    "CDEGHJKL" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 28
    "CDEGHIKL" => %{a: :E, b: :G, d: :I, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 29
    "CDEGHIJL" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :D, k: :L, l: :I},
    # Row 30
    "CDEGHIJK" => %{a: :E, b: :G, d: :J, e: :C, g: :H, i: :D, k: :I, l: :K},
    # Row 31
    "CDEFIJKL" => %{a: :C, b: :J, d: :E, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 32
    "CDEFHJKL" => %{a: :C, b: :J, d: :E, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 33
    "CDEFHIKL" => %{a: :C, b: :E, d: :I, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 34
    "CDEFHIJL" => %{a: :C, b: :J, d: :E, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 35
    "CDEFHIJK" => %{a: :C, b: :J, d: :E, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 36
    "CDEFGJKL" => %{a: :C, b: :G, d: :E, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 37
    "CDEFGIKL" => %{a: :C, b: :G, d: :E, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 38
    "CDEFGIJL" => %{a: :C, b: :G, d: :E, e: :D, g: :J, i: :F, k: :L, l: :I},
    # Row 39
    "CDEFGIJK" => %{a: :C, b: :G, d: :E, e: :D, g: :J, i: :F, k: :I, l: :K},
    # Row 40
    "CDEFGHKL" => %{a: :C, b: :G, d: :E, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 41
    "CDEFGHJL" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :L, l: :E},
    # Row 42
    "CDEFGHJK" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :E, l: :K},
    # Row 43
    "CDEFGHIL" => %{a: :C, b: :G, d: :E, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 44
    "CDEFGHIK" => %{a: :C, b: :G, d: :E, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 45
    "CDEFGHIJ" => %{a: :C, b: :G, d: :J, e: :D, g: :H, i: :F, k: :E, l: :I},
    # Row 46
    "BFGHIJKL" => %{a: :H, b: :J, d: :B, e: :F, g: :I, i: :G, k: :L, l: :K},
    # Row 47
    "BEGHIJKL" => %{a: :E, b: :J, d: :I, e: :B, g: :H, i: :G, k: :L, l: :K},
    # Row 48
    "BEFHIJKL" => %{a: :E, b: :J, d: :B, e: :F, g: :I, i: :H, k: :L, l: :K},
    # Row 49
    "BEFGIJKL" => %{a: :E, b: :J, d: :B, e: :F, g: :I, i: :G, k: :L, l: :K},
    # Row 50
    "BEFGHJKL" => %{a: :E, b: :J, d: :B, e: :F, g: :H, i: :G, k: :L, l: :K},
    # Row 51
    "BEFGHIKL" => %{a: :E, b: :G, d: :B, e: :F, g: :I, i: :H, k: :L, l: :K},
    # Row 52
    "BEFGHIJL" => %{a: :E, b: :J, d: :B, e: :F, g: :H, i: :G, k: :L, l: :I},
    # Row 53
    "BEFGHIJK" => %{a: :E, b: :J, d: :B, e: :F, g: :H, i: :G, k: :I, l: :K},
    # Row 54
    "BDGHIJKL" => %{a: :H, b: :J, d: :B, e: :D, g: :I, i: :G, k: :L, l: :K},
    # Row 55
    "BDFHIJKL" => %{a: :H, b: :J, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 56
    "BDFGIJKL" => %{a: :I, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 57
    "BDFGHJKL" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 58
    "BDFGHIKL" => %{a: :H, b: :G, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 59
    "BDFGHIJL" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :I},
    # Row 60
    "BDFGHIJK" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :I, l: :K},
    # Row 61
    "BDEHIJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :I, i: :H, k: :L, l: :K},
    # Row 62
    "BDEGIJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :I, i: :G, k: :L, l: :K},
    # Row 63
    "BDEGHJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :G, k: :L, l: :K},
    # Row 64
    "BDEGHIKL" => %{a: :E, b: :G, d: :B, e: :D, g: :I, i: :H, k: :L, l: :K},
    # Row 65
    "BDEGHIJL" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :G, k: :L, l: :I},
    # Row 66
    "BDEGHIJK" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :G, k: :I, l: :K},
    # Row 67
    "BDEFIJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 68
    "BDEFHJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 69
    "BDEFHIKL" => %{a: :E, b: :I, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 70
    "BDEFHIJL" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 71
    "BDEFHIJK" => %{a: :E, b: :J, d: :B, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 72
    "BDEFGJKL" => %{a: :E, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 73
    "BDEFGIKL" => %{a: :E, b: :G, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 74
    "BDEFGIJL" => %{a: :E, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :I},
    # Row 75
    "BDEFGIJK" => %{a: :E, b: :G, d: :B, e: :D, g: :J, i: :F, k: :I, l: :K},
    # Row 76
    "BDEFGHKL" => %{a: :E, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 77
    "BDEFGHJL" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :E},
    # Row 78
    "BDEFGHJK" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :E, l: :K},
    # Row 79
    "BDEFGHIL" => %{a: :E, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 80
    "BDEFGHIK" => %{a: :E, b: :G, d: :B, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 81
    "BDEFGHIJ" => %{a: :H, b: :G, d: :B, e: :D, g: :J, i: :F, k: :E, l: :I},
    # Row 82
    "BCGHIJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :I, i: :G, k: :L, l: :K},
    # Row 83
    "BCFHIJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :I, i: :F, k: :L, l: :K},
    # Row 84
    "BCFGIJKL" => %{a: :I, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :K},
    # Row 85
    "BCFGHJKL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :K},
    # Row 86
    "BCFGHIKL" => %{a: :H, b: :G, d: :B, e: :C, g: :I, i: :F, k: :L, l: :K},
    # Row 87
    "BCFGHIJL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :I},
    # Row 88
    "BCFGHIJK" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :I, l: :K},
    # Row 89
    "BCEHIJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :I, i: :H, k: :L, l: :K},
    # Row 90
    "BCEGIJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :I, i: :G, k: :L, l: :K},
    # Row 91
    "BCEGHJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :G, k: :L, l: :K},
    # Row 92
    "BCEGHIKL" => %{a: :E, b: :G, d: :B, e: :C, g: :I, i: :H, k: :L, l: :K},
    # Row 93
    "BCEGHIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :G, k: :L, l: :I},
    # Row 94
    "BCEGHIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :G, k: :I, l: :K},
    # Row 95
    "BCEFIJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :I, i: :F, k: :L, l: :K},
    # Row 96
    "BCEFHJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 97
    "BCEFHIKL" => %{a: :E, b: :I, d: :B, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 98
    "BCEFHIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :F, k: :L, l: :I},
    # Row 99
    "BCEFHIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :F, k: :I, l: :K},
    # Row 100
    "BCEFGJKL" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :K},
    # Row 101
    "BCEFGIKL" => %{a: :E, b: :G, d: :B, e: :C, g: :I, i: :F, k: :L, l: :K},
    # Row 102
    "BCEFGIJL" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :I},
    # Row 103
    "BCEFGIJK" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :F, k: :I, l: :K},
    # Row 104
    "BCEFGHKL" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :F, k: :L, l: :K},
    # Row 105
    "BCEFGHJL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :L, l: :E},
    # Row 106
    "BCEFGHJK" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :E, l: :K},
    # Row 107
    "BCEFGHIL" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :F, k: :L, l: :I},
    # Row 108
    "BCEFGHIK" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :F, k: :I, l: :K},
    # Row 109
    "BCEFGHIJ" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :E, l: :I},
    # Row 110
    "BCDHIJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :I, i: :D, k: :L, l: :K},
    # Row 111
    "BCDGIJKL" => %{a: :I, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :K},
    # Row 112
    "BCDGHJKL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :K},
    # Row 113
    "BCDGHIKL" => %{a: :H, b: :G, d: :B, e: :C, g: :I, i: :D, k: :L, l: :K},
    # Row 114
    "BCDGHIJL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :I},
    # Row 115
    "BCDGHIJK" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :I, l: :K},
    # Row 116
    "BCDFIJKL" => %{a: :C, b: :J, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 117
    "BCDFHJKL" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 118
    "BCDFHIKL" => %{a: :C, b: :I, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 119
    "BCDFHIJL" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 120
    "BCDFHIJK" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 121
    "BCDFGJKL" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :K},
    # Row 122
    "BCDFGIKL" => %{a: :C, b: :G, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 123
    "BCDFGIJL" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :I},
    # Row 124
    "BCDFGIJK" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :I, l: :K},
    # Row 125
    "BCDFGHKL" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 126
    "BCDFGHJL" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :J},
    # Row 127
    "BCDFGHJK" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :D, l: :K},
    # Row 128
    "BCDFGHIL" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 129
    "BCDFGHIK" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 130
    "BCDFGHIJ" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :D, l: :I},
    # Row 131
    "BCDEIJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :I, i: :D, k: :L, l: :K},
    # Row 132
    "BCDEHJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 133
    "BCDEHIKL" => %{a: :E, b: :I, d: :B, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 134
    "BCDEHIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :D, k: :L, l: :I},
    # Row 135
    "BCDEHIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :H, i: :D, k: :I, l: :K},
    # Row 136
    "BCDEGJKL" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :K},
    # Row 137
    "BCDEGIKL" => %{a: :E, b: :G, d: :B, e: :C, g: :I, i: :D, k: :L, l: :K},
    # Row 138
    "BCDEGIJL" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :I},
    # Row 139
    "BCDEGIJK" => %{a: :E, b: :G, d: :B, e: :C, g: :J, i: :D, k: :I, l: :K},
    # Row 140
    "BCDEGHKL" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :D, k: :L, l: :K},
    # Row 141
    "BCDEGHJL" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :L, l: :E},
    # Row 142
    "BCDEGHJK" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :E, l: :K},
    # Row 143
    "BCDEGHIL" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :D, k: :L, l: :I},
    # Row 144
    "BCDEGHIK" => %{a: :E, b: :G, d: :B, e: :C, g: :H, i: :D, k: :I, l: :K},
    # Row 145
    "BCDEGHIJ" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :D, k: :E, l: :I},
    # Row 146
    "BCDEFJKL" => %{a: :C, b: :J, d: :B, e: :D, g: :E, i: :F, k: :L, l: :K},
    # Row 147
    "BCDEFIKL" => %{a: :C, b: :E, d: :B, e: :D, g: :I, i: :F, k: :L, l: :K},
    # Row 148
    "BCDEFIJL" => %{a: :C, b: :J, d: :B, e: :D, g: :E, i: :F, k: :L, l: :I},
    # Row 149
    "BCDEFIJK" => %{a: :C, b: :J, d: :B, e: :D, g: :E, i: :F, k: :I, l: :K},
    # Row 150
    "BCDEFHKL" => %{a: :C, b: :E, d: :B, e: :D, g: :H, i: :F, k: :L, l: :K},
    # Row 151
    "BCDEFHJL" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :L, l: :E},
    # Row 152
    "BCDEFHJK" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :E, l: :K},
    # Row 153
    "BCDEFHIL" => %{a: :C, b: :E, d: :B, e: :D, g: :H, i: :F, k: :L, l: :I},
    # Row 154
    "BCDEFHIK" => %{a: :C, b: :E, d: :B, e: :D, g: :H, i: :F, k: :I, l: :K},
    # Row 155
    "BCDEFHIJ" => %{a: :C, b: :J, d: :B, e: :D, g: :H, i: :F, k: :E, l: :I},
    # Row 156
    "BCDEFGKL" => %{a: :C, b: :G, d: :B, e: :D, g: :E, i: :F, k: :L, l: :K},
    # Row 157
    "BCDEFGJL" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :L, l: :E},
    # Row 158
    "BCDEFGJK" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :E, l: :K},
    # Row 159
    "BCDEFGIL" => %{a: :C, b: :G, d: :B, e: :D, g: :E, i: :F, k: :L, l: :I},
    # Row 160
    "BCDEFGIK" => %{a: :C, b: :G, d: :B, e: :D, g: :E, i: :F, k: :I, l: :K},
    # Row 161
    "BCDEFGIJ" => %{a: :C, b: :G, d: :B, e: :D, g: :J, i: :F, k: :E, l: :I},
    # Row 162
    "BCDEFGHL" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :L, l: :E},
    # Row 163
    "BCDEFGHK" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :E, l: :K},
    # Row 164
    "BCDEFGHJ" => %{a: :H, b: :G, d: :B, e: :C, g: :J, i: :F, k: :D, l: :E},
    # Row 165
    "BCDEFGHI" => %{a: :C, b: :G, d: :B, e: :D, g: :H, i: :F, k: :E, l: :I},
    # Row 166
    "AFGHIJKL" => %{a: :H, b: :J, d: :I, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 167
    "AEGHIJKL" => %{a: :E, b: :J, d: :I, e: :A, g: :H, i: :G, k: :L, l: :K},
    # Row 168
    "AEFHIJKL" => %{a: :E, b: :J, d: :I, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 169
    "AEFGIJKL" => %{a: :E, b: :J, d: :I, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 170
    "AEFGHJKL" => %{a: :E, b: :G, d: :J, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 171
    "AEFGHIKL" => %{a: :E, b: :G, d: :I, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 172
    "AEFGHIJL" => %{a: :E, b: :G, d: :J, e: :F, g: :A, i: :H, k: :L, l: :I},
    # Row 173
    "AEFGHIJK" => %{a: :E, b: :G, d: :J, e: :F, g: :A, i: :H, k: :I, l: :K},
    # Row 174
    "ADGHIJKL" => %{a: :H, b: :J, d: :I, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 175
    "ADFHIJKL" => %{a: :H, b: :J, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 176
    "ADFGIJKL" => %{a: :I, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 177
    "ADFGHJKL" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 178
    "ADFGHIKL" => %{a: :H, b: :G, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 179
    "ADFGHIJL" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 180
    "ADFGHIJK" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 181
    "ADEHIJKL" => %{a: :E, b: :J, d: :I, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 182
    "ADEGIJKL" => %{a: :E, b: :J, d: :I, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 183
    "ADEGHJKL" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 184
    "ADEGHIKL" => %{a: :E, b: :G, d: :I, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 185
    "ADEGHIJL" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :H, k: :L, l: :I},
    # Row 186
    "ADEGHIJK" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :H, k: :I, l: :K},
    # Row 187
    "ADEFIJKL" => %{a: :E, b: :J, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 188
    "ADEFHJKL" => %{a: :H, b: :J, d: :E, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 189
    "ADEFHIKL" => %{a: :H, b: :E, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 190
    "ADEFHIJL" => %{a: :H, b: :J, d: :E, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 191
    "ADEFHIJK" => %{a: :H, b: :J, d: :E, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 192
    "ADEFGJKL" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 193
    "ADEFGIKL" => %{a: :E, b: :G, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 194
    "ADEFGIJL" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 195
    "ADEFGIJK" => %{a: :E, b: :G, d: :J, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 196
    "ADEFGHKL" => %{a: :H, b: :G, d: :E, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 197
    "ADEFGHJL" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 198
    "ADEFGHJK" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 199
    "ADEFGHIL" => %{a: :H, b: :G, d: :E, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 200
    "ADEFGHIK" => %{a: :H, b: :G, d: :E, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 201
    "ADEFGHIJ" => %{a: :H, b: :G, d: :J, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 202
    "ACGHIJKL" => %{a: :H, b: :J, d: :I, e: :C, g: :A, i: :G, k: :L, l: :K},
    # Row 203
    "ACFHIJKL" => %{a: :H, b: :J, d: :I, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 204
    "ACFGIJKL" => %{a: :I, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 205
    "ACFGHJKL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 206
    "ACFGHIKL" => %{a: :H, b: :G, d: :I, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 207
    "ACFGHIJL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 208
    "ACFGHIJK" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 209
    "ACEHIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 210
    "ACEGIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :A, i: :G, k: :L, l: :K},
    # Row 211
    "ACEGHJKL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 212
    "ACEGHIKL" => %{a: :E, b: :G, d: :I, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 213
    "ACEGHIJL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :H, k: :L, l: :I},
    # Row 214
    "ACEGHIJK" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :H, k: :I, l: :K},
    # Row 215
    "ACEFIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 216
    "ACEFHJKL" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 217
    "ACEFHIKL" => %{a: :H, b: :E, d: :I, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 218
    "ACEFHIJL" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 219
    "ACEFHIJK" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 220
    "ACEFGJKL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 221
    "ACEFGIKL" => %{a: :E, b: :G, d: :I, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 222
    "ACEFGIJL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 223
    "ACEFGIJK" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 224
    "ACEFGHKL" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 225
    "ACEFGHJL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :L, l: :E},
    # Row 226
    "ACEFGHJK" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :E, l: :K},
    # Row 227
    "ACEFGHIL" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 228
    "ACEFGHIK" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 229
    "ACEFGHIJ" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :E, l: :I},
    # Row 230
    "ACDHIJKL" => %{a: :H, b: :J, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 231
    "ACDGIJKL" => %{a: :I, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 232
    "ACDGHJKL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 233
    "ACDGHIKL" => %{a: :H, b: :G, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 234
    "ACDGHIJL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 235
    "ACDGHIJK" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 236
    "ACDFIJKL" => %{a: :C, b: :J, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 237
    "ACDFHJKL" => %{a: :H, b: :J, d: :F, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 238
    "ACDFHIKL" => %{a: :H, b: :F, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 239
    "ACDFHIJL" => %{a: :H, b: :J, d: :F, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 240
    "ACDFHIJK" => %{a: :H, b: :J, d: :F, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 241
    "ACDFGJKL" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 242
    "ACDFGIKL" => %{a: :C, b: :G, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 243
    "ACDFGIJL" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 244
    "ACDFGIJK" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 245
    "ACDFGHKL" => %{a: :H, b: :G, d: :F, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 246
    "ACDFGHJL" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :H},
    # Row 247
    "ACDFGHJK" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 248
    "ACDFGHIL" => %{a: :H, b: :G, d: :F, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 249
    "ACDFGHIK" => %{a: :H, b: :G, d: :F, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 250
    "ACDFGHIJ" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 251
    "ACDEIJKL" => %{a: :E, b: :J, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 252
    "ACDEHJKL" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 253
    "ACDEHIKL" => %{a: :H, b: :E, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 254
    "ACDEHIJL" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 255
    "ACDEHIJK" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 256
    "ACDEGJKL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 257
    "ACDEGIKL" => %{a: :E, b: :G, d: :I, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 258
    "ACDEGIJL" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 259
    "ACDEGIJK" => %{a: :E, b: :G, d: :J, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 260
    "ACDEGHKL" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 261
    "ACDEGHJL" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 262
    "ACDEGHJK" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :E, l: :K},
    # Row 263
    "ACDEGHIL" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 264
    "ACDEGHIK" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 265
    "ACDEGHIJ" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :D, k: :E, l: :I},
    # Row 266
    "ACDEFJKL" => %{a: :C, b: :J, d: :E, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 267
    "ACDEFIKL" => %{a: :C, b: :E, d: :I, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 268
    "ACDEFIJL" => %{a: :C, b: :J, d: :E, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 269
    "ACDEFIJK" => %{a: :C, b: :J, d: :E, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 270
    "ACDEFHKL" => %{a: :H, b: :E, d: :F, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 271
    "ACDEFHJL" => %{a: :H, b: :J, d: :F, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 272
    "ACDEFHJK" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 273
    "ACDEFHIL" => %{a: :H, b: :E, d: :F, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 274
    "ACDEFHIK" => %{a: :H, b: :E, d: :F, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 275
    "ACDEFHIJ" => %{a: :H, b: :J, d: :E, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 276
    "ACDEFGKL" => %{a: :C, b: :G, d: :E, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 277
    "ACDEFGJL" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 278
    "ACDEFGJK" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 279
    "ACDEFGIL" => %{a: :C, b: :G, d: :E, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 280
    "ACDEFGIK" => %{a: :C, b: :G, d: :E, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 281
    "ACDEFGIJ" => %{a: :C, b: :G, d: :J, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 282
    "ACDEFGHL" => %{a: :H, b: :G, d: :F, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 283
    "ACDEFGHK" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 284
    "ACDEFGHJ" => %{a: :H, b: :G, d: :J, e: :C, g: :A, i: :F, k: :D, l: :E},
    # Row 285
    "ACDEFGHI" => %{a: :H, b: :G, d: :E, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 286
    "ABGHIJKL" => %{a: :H, b: :J, d: :B, e: :A, g: :I, i: :G, k: :L, l: :K},
    # Row 287
    "ABFHIJKL" => %{a: :H, b: :J, d: :B, e: :A, g: :I, i: :F, k: :L, l: :K},
    # Row 288
    "ABFGIJKL" => %{a: :I, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 289
    "ABFGHJKL" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 290
    "ABFGHIKL" => %{a: :H, b: :G, d: :B, e: :A, g: :I, i: :F, k: :L, l: :K},
    # Row 291
    "ABFGHIJL" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :I},
    # Row 292
    "ABFGHIJK" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :I, l: :K},
    # Row 293
    "ABEHIJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :I, i: :H, k: :L, l: :K},
    # Row 294
    "ABEGIJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :I, i: :G, k: :L, l: :K},
    # Row 295
    "ABEGHJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :H, i: :G, k: :L, l: :K},
    # Row 296
    "ABEGHIKL" => %{a: :E, b: :G, d: :B, e: :A, g: :I, i: :H, k: :L, l: :K},
    # Row 297
    "ABEGHIJL" => %{a: :E, b: :J, d: :B, e: :A, g: :H, i: :G, k: :L, l: :I},
    # Row 298
    "ABEGHIJK" => %{a: :E, b: :J, d: :B, e: :A, g: :H, i: :G, k: :I, l: :K},
    # Row 299
    "ABEFIJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :I, i: :F, k: :L, l: :K},
    # Row 300
    "ABEFHJKL" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 301
    "ABEFHIKL" => %{a: :E, b: :I, d: :B, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 302
    "ABEFHIJL" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :H, k: :L, l: :I},
    # Row 303
    "ABEFHIJK" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :H, k: :I, l: :K},
    # Row 304
    "ABEFGJKL" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 305
    "ABEFGIKL" => %{a: :E, b: :G, d: :B, e: :A, g: :I, i: :F, k: :L, l: :K},
    # Row 306
    "ABEFGIJL" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :I},
    # Row 307
    "ABEFGIJK" => %{a: :E, b: :J, d: :B, e: :F, g: :A, i: :G, k: :I, l: :K},
    # Row 308
    "ABEFGHKL" => %{a: :E, b: :G, d: :B, e: :F, g: :A, i: :H, k: :L, l: :K},
    # Row 309
    "ABEFGHJL" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :E},
    # Row 310
    "ABEFGHJK" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :E, l: :K},
    # Row 311
    "ABEFGHIL" => %{a: :E, b: :G, d: :B, e: :F, g: :A, i: :H, k: :L, l: :I},
    # Row 312
    "ABEFGHIK" => %{a: :E, b: :G, d: :B, e: :F, g: :A, i: :H, k: :I, l: :K},
    # Row 313
    "ABEFGHIJ" => %{a: :H, b: :J, d: :B, e: :F, g: :A, i: :G, k: :E, l: :I},
    # Row 314
    "ABDHIJKL" => %{a: :I, b: :J, d: :B, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 315
    "ABDGIJKL" => %{a: :I, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 316
    "ABDGHJKL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 317
    "ABDGHIKL" => %{a: :I, b: :G, d: :B, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 318
    "ABDGHIJL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :I},
    # Row 319
    "ABDGHIJK" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :I, l: :K},
    # Row 320
    "ABDFIJKL" => %{a: :I, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 321
    "ABDFHJKL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 322
    "ABDFHIKL" => %{a: :H, b: :I, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 323
    "ABDFHIJL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 324
    "ABDFHIJK" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 325
    "ABDFGJKL" => %{a: :F, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 326
    "ABDFGIKL" => %{a: :I, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 327
    "ABDFGIJL" => %{a: :F, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :I},
    # Row 328
    "ABDFGIJK" => %{a: :F, b: :J, d: :B, e: :D, g: :A, i: :G, k: :I, l: :K},
    # Row 329
    "ABDFGHKL" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 330
    "ABDFGHJL" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :J},
    # Row 331
    "ABDFGHJK" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :J, l: :K},
    # Row 332
    "ABDFGHIL" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 333
    "ABDFGHIK" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 334
    "ABDFGHIJ" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :J},
    # Row 335
    "ABDEIJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :I, i: :D, k: :L, l: :K},
    # Row 336
    "ABDEHJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 337
    "ABDEHIKL" => %{a: :E, b: :I, d: :B, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 338
    "ABDEHIJL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :H, k: :L, l: :I},
    # Row 339
    "ABDEHIJK" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :H, k: :I, l: :K},
    # Row 340
    "ABDEGJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 341
    "ABDEGIKL" => %{a: :E, b: :G, d: :B, e: :A, g: :I, i: :D, k: :L, l: :K},
    # Row 342
    "ABDEGIJL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :I},
    # Row 343
    "ABDEGIJK" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :G, k: :I, l: :K},
    # Row 344
    "ABDEGHKL" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :H, k: :L, l: :K},
    # Row 345
    "ABDEGHJL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :E},
    # Row 346
    "ABDEGHJK" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :E, l: :K},
    # Row 347
    "ABDEGHIL" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :H, k: :L, l: :I},
    # Row 348
    "ABDEGHIK" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :H, k: :I, l: :K},
    # Row 349
    "ABDEGHIJ" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :G, k: :E, l: :I},
    # Row 350
    "ABDEFJKL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 351
    "ABDEFIKL" => %{a: :E, b: :I, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 352
    "ABDEFIJL" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 353
    "ABDEFIJK" => %{a: :E, b: :J, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 354
    "ABDEFHKL" => %{a: :H, b: :E, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 355
    "ABDEFHJL" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 356
    "ABDEFHJK" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 357
    "ABDEFHIL" => %{a: :H, b: :E, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 358
    "ABDEFHIK" => %{a: :H, b: :E, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 359
    "ABDEFHIJ" => %{a: :H, b: :J, d: :B, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 360
    "ABDEFGKL" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 361
    "ABDEFGJL" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :J},
    # Row 362
    "ABDEFGJK" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :J, l: :K},
    # Row 363
    "ABDEFGIL" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 364
    "ABDEFGIK" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 365
    "ABDEFGIJ" => %{a: :E, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :J},
    # Row 366
    "ABDEFGHL" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 367
    "ABDEFGHK" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 368
    "ABDEFGHJ" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :J},
    # Row 369
    "ABDEFGHI" => %{a: :H, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 370
    "ABCHIJKL" => %{a: :I, b: :J, d: :B, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 371
    "ABCGIJKL" => %{a: :I, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :K},
    # Row 372
    "ABCGHJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :K},
    # Row 373
    "ABCGHIKL" => %{a: :I, b: :G, d: :B, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 374
    "ABCGHIJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :I},
    # Row 375
    "ABCGHIJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :I, l: :K},
    # Row 376
    "ABCFIJKL" => %{a: :I, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 377
    "ABCFHJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 378
    "ABCFHIKL" => %{a: :H, b: :I, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 379
    "ABCFHIJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 380
    "ABCFHIJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 381
    "ABCFGJKL" => %{a: :C, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :K},
    # Row 382
    "ABCFGIKL" => %{a: :I, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 383
    "ABCFGIJL" => %{a: :C, b: :J, d: :B, e: :F, g: :A, i: :G, k: :L, l: :I},
    # Row 384
    "ABCFGIJK" => %{a: :C, b: :J, d: :B, e: :F, g: :A, i: :G, k: :I, l: :K},
    # Row 385
    "ABCFGHKL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 386
    "ABCFGHJL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :J},
    # Row 387
    "ABCFGHJK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :J, l: :K},
    # Row 388
    "ABCFGHIL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 389
    "ABCFGHIK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 390
    "ABCFGHIJ" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :I, l: :J},
    # Row 391
    "ABCEIJKL" => %{a: :E, b: :J, d: :B, e: :A, g: :I, i: :C, k: :L, l: :K},
    # Row 392
    "ABCEHJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 393
    "ABCEHIKL" => %{a: :E, b: :I, d: :B, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 394
    "ABCEHIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :H, k: :L, l: :I},
    # Row 395
    "ABCEHIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :H, k: :I, l: :K},
    # Row 396
    "ABCEGJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :K},
    # Row 397
    "ABCEGIKL" => %{a: :E, b: :G, d: :B, e: :A, g: :I, i: :C, k: :L, l: :K},
    # Row 398
    "ABCEGIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :I},
    # Row 399
    "ABCEGIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :G, k: :I, l: :K},
    # Row 400
    "ABCEGHKL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :H, k: :L, l: :K},
    # Row 401
    "ABCEGHJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :L, l: :E},
    # Row 402
    "ABCEGHJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :E, l: :K},
    # Row 403
    "ABCEGHIL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :H, k: :L, l: :I},
    # Row 404
    "ABCEGHIK" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :H, k: :I, l: :K},
    # Row 405
    "ABCEGHIJ" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :G, k: :E, l: :I},
    # Row 406
    "ABCEFJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 407
    "ABCEFIKL" => %{a: :E, b: :I, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 408
    "ABCEFIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 409
    "ABCEFIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 410
    "ABCEFHKL" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 411
    "ABCEFHJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :L, l: :E},
    # Row 412
    "ABCEFHJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :E, l: :K},
    # Row 413
    "ABCEFHIL" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 414
    "ABCEFHIK" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 415
    "ABCEFHIJ" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :E, l: :I},
    # Row 416
    "ABCEFGKL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :K},
    # Row 417
    "ABCEFGJL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :J},
    # Row 418
    "ABCEFGJK" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :J, l: :K},
    # Row 419
    "ABCEFGIL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :I},
    # Row 420
    "ABCEFGIK" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :I, l: :K},
    # Row 421
    "ABCEFGIJ" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :F, k: :I, l: :J},
    # Row 422
    "ABCEFGHL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :L, l: :E},
    # Row 423
    "ABCEFGHK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :E, l: :K},
    # Row 424
    "ABCEFGHJ" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :E, l: :J},
    # Row 425
    "ABCEFGHI" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :E, l: :I},
    # Row 426
    "ABCDIJKL" => %{a: :I, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 427
    "ABCDHJKL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 428
    "ABCDHIKL" => %{a: :H, b: :I, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 429
    "ABCDHIJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 430
    "ABCDHIJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 431
    "ABCDGJKL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :K},
    # Row 432
    "ABCDGIKL" => %{a: :I, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 433
    "ABCDGIJL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :G, k: :L, l: :I},
    # Row 434
    "ABCDGIJK" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :G, k: :I, l: :K},
    # Row 435
    "ABCDGHKL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 436
    "ABCDGHJL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :J},
    # Row 437
    "ABCDGHJK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :J, l: :K},
    # Row 438
    "ABCDGHIL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 439
    "ABCDGHIK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 440
    "ABCDGHIJ" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :I, l: :J},
    # Row 441
    "ABCDFJKL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 442
    "ABCDFIKL" => %{a: :C, b: :I, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 443
    "ABCDFIJL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 444
    "ABCDFIJK" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 445
    "ABCDFHKL" => %{a: :H, b: :F, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 446
    "ABCDFHJL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :H},
    # Row 447
    "ABCDFHJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 448
    "ABCDFHIL" => %{a: :H, b: :F, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 449
    "ABCDFHIK" => %{a: :H, b: :F, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 450
    "ABCDFHIJ" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 451
    "ABCDFGKL" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 452
    "ABCDFGJL" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :J},
    # Row 453
    "ABCDFGJK" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :J, l: :K},
    # Row 454
    "ABCDFGIL" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 455
    "ABCDFGIK" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 456
    "ABCDFGIJ" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :I, l: :J},
    # Row 457
    "ABCDFGHL" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :H},
    # Row 458
    "ABCDFGHK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 459
    "ABCDFGHJ" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :D, l: :J},
    # Row 460
    "ABCDFGHI" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 461
    "ABCDEJKL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 462
    "ABCDEIKL" => %{a: :E, b: :I, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 463
    "ABCDEIJL" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 464
    "ABCDEIJK" => %{a: :E, b: :J, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 465
    "ABCDEHKL" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 466
    "ABCDEHJL" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 467
    "ABCDEHJK" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :E, l: :K},
    # Row 468
    "ABCDEHIL" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 469
    "ABCDEHIK" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 470
    "ABCDEHIJ" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :D, k: :E, l: :I},
    # Row 471
    "ABCDEGKL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :K},
    # Row 472
    "ABCDEGJL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :J},
    # Row 473
    "ABCDEGJK" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :J, l: :K},
    # Row 474
    "ABCDEGIL" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :I},
    # Row 475
    "ABCDEGIK" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :I, l: :K},
    # Row 476
    "ABCDEGIJ" => %{a: :E, b: :G, d: :B, e: :C, g: :A, i: :D, k: :I, l: :J},
    # Row 477
    "ABCDEGHL" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 478
    "ABCDEGHK" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :E, l: :K},
    # Row 479
    "ABCDEGHJ" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :E, l: :J},
    # Row 480
    "ABCDEGHI" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :D, k: :E, l: :I},
    # Row 481
    "ABCDEFKL" => %{a: :C, b: :E, d: :B, e: :D, g: :A, i: :F, k: :L, l: :K},
    # Row 482
    "ABCDEFJL" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 483
    "ABCDEFJK" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 484
    "ABCDEFIL" => %{a: :C, b: :E, d: :B, e: :D, g: :A, i: :F, k: :L, l: :I},
    # Row 485
    "ABCDEFIK" => %{a: :C, b: :E, d: :B, e: :D, g: :A, i: :F, k: :I, l: :K},
    # Row 486
    "ABCDEFIJ" => %{a: :C, b: :J, d: :B, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 487
    "ABCDEFHL" => %{a: :H, b: :F, d: :B, e: :C, g: :A, i: :D, k: :L, l: :E},
    # Row 488
    "ABCDEFHK" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :F, k: :D, l: :K},
    # Row 489
    "ABCDEFHJ" => %{a: :H, b: :J, d: :B, e: :C, g: :A, i: :F, k: :D, l: :E},
    # Row 490
    "ABCDEFHI" => %{a: :H, b: :E, d: :B, e: :C, g: :A, i: :F, k: :D, l: :I},
    # Row 491
    "ABCDEFGL" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :L, l: :E},
    # Row 492
    "ABCDEFGK" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :K},
    # Row 493
    "ABCDEFGJ" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :J},
    # Row 494
    "ABCDEFGI" => %{a: :C, b: :G, d: :B, e: :D, g: :A, i: :F, k: :E, l: :I},
    # Row 495
    "ABCDEFGH" => %{a: :H, b: :G, d: :B, e: :C, g: :A, i: :F, k: :D, l: :E}
  }

  @doc """
  Returns the set of group-winner slots that are paired with 3rd-place teams.

  These are the 8 group winners (out of 12) whose Round of 32 opponent is
  a 3rd-place qualifier: A, B, D, E, G, I, K, L.
  """
  def paired_group_winners, do: ~w(A B D E G I K L)

  @doc """
  Given a sorted list of 8 group identifiers (strings or atoms) that qualify
  as 3rd-place teams, returns the seeding map.

  The seeding map has the form:

      %{a: :E, b: :J, d: :I, e: :F, g: :H, i: :G, k: :L, l: :K}

  where keys are lowercase atoms representing the group winner being faced,
  and values are atoms representing the 3rd-place qualifying group.

  Returns `nil` if the combination is not found in the lookup table.

  ## Examples

      iex> ThirdPlaceSeeding.get_seeding(~w(E F G H I J K L))
      %{a: :E, b: :J, d: :I, e: :F, g: :H, i: :G, k: :L, l: :K}

      iex> ThirdPlaceSeeding.get_seeding([:D, :E, :F, :G, :H, :I, :J, :K])
      %{a: :E, b: :G, d: :J, e: :D, g: :H, i: :F, k: :I, l: :K}

  """
  @spec get_seeding([String.t() | atom()]) :: map() | nil
  def get_seeding(qualifying_groups) when is_list(qualifying_groups) and length(qualifying_groups) == 8 do
    key =
      qualifying_groups
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.upcase/1)
      |> Enum.sort()
      |> Enum.join()

    Map.get(@seeding_table, key)
  end

  def get_seeding(_), do: nil

  @doc """
  Given third-place standings for all 12 groups, determines which 8 qualify
  and returns their seeding for the Round of 32.

  ## Parameters

    - `third_place_standings` - a list of 12 maps, each with:
      - `:group` - the group letter as a string (e.g. `"A"`)
      - `:points` - total points (integer)
      - `:goal_diff` - goal difference (integer)
      - `:goals_for` - goals scored (integer)

  ## Returns

  A tuple `{qualified, seeding}` where:
    - `qualified` is the sorted list of 8 qualifying third-place entries
    - `seeding` is the seeding map from `get_seeding/1`, or `nil` if not found

  ## Tiebreaking

  Teams are ranked by:
  1. Points (descending)
  2. Goal difference (descending)
  3. Goals scored (descending)
  """
  @spec determine_qualifiers_and_seeding([map()]) :: {[map()], map() | nil}
  def determine_qualifiers_and_seeding(third_place_standings)
      when is_list(third_place_standings) and length(third_place_standings) == 12 do
    qualified =
      third_place_standings
      |> Enum.sort_by(&{-&1.points, -&1.goal_diff, -&1.goals_for})
      |> Enum.take(8)

    groups =
      qualified
      |> Enum.map(& &1.group)
      |> Enum.map(&String.upcase(to_string(&1)))

    seeding = get_seeding(groups)

    {qualified, seeding}
  end

  @doc """
  Returns the number of entries currently in the seeding lookup table.
  The complete table should contain 495 entries (C(12,8) = 495).
  """
  @spec table_size() :: non_neg_integer()
  def table_size, do: map_size(@seeding_table)

  @doc """
  Checks whether the seeding table is complete (contains all 495 entries).
  """
  @spec complete?() :: boolean()
  def complete?, do: map_size(@seeding_table) == 495
end
