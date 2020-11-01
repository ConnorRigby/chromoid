defmodule Chromoid.Lua.Discord.User.Flags do
  use Chromoid.Lua.Class

  def alloc(%Nostrum.Struct.User.Flags{} = flags, state) do
    :luerl_heap.alloc_table(table(flags), state)
  end

  def table(%Nostrum.Struct.User.Flags{
        bug_hunter_level_1: bug_hunter_level_1,
        bug_hunter_level_2: bug_hunter_level_2,
        early_supporter: early_supporter,
        hypesquad_balance: hypesquad_balance,
        hypesquad_bravery: hypesquad_bravery,
        hypesquad_brilliance: hypesquad_brilliance,
        hypesquad_events: hypesquad_events,
        partner: partner,
        staff: staff,
        system: system,
        team_user: team_user,
        verified_bot: verified_bot,
        verified_developer: verified_developer
      }) do
    [
      {"bug_hunter_level_1", bug_hunter_level_1},
      {"bug_hunter_level_2", bug_hunter_level_2},
      {"early_supporter", early_supporter},
      {"hypesquad_balance", hypesquad_balance},
      {"hypesquad_bravery", hypesquad_bravery},
      {"hypesquad_brilliance", hypesquad_brilliance},
      {"hypesquad_events", hypesquad_events},
      {"partner", partner},
      {"staff", staff},
      {"system", system},
      {"team_user", team_user},
      {"verified_bot", verified_bot},
      {"verified_developer", verified_developer}
    ]
  end
end
