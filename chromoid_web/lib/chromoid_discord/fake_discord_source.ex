defmodule ChromoidDiscord.FakeDiscordSource do
  @moduledoc """
  Stub interface for dispatching Discord events
  """

  use GenServer
  require Logger

  def message_create(%Nostrum.Struct.Message{guild_id: guild_id} = message) do
    guild = %Nostrum.Struct.Guild{id: guild_id}
    ChromoidDiscord.Guild.EventDispatcher.dispatch(guild, {:MESSAGE_CREATE, message})
  end

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  def init_guild(%Nostrum.Struct.Guild{} = guild, %Nostrum.Struct.User{} = current_user) do
    Logger.info("GUILD_AVAILABLE: #{guild.name}")
    config = ChromoidDiscord.NostrumConsumer.get_or_create_config(guild)

    case ChromoidDiscord.GuildSupervisor.start_guild(guild, config, current_user) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        Logger.error("Could not start guild: #{guild.name}: #{inspect(error)}")
    end
  end

  def init_guild() do
    init_guild(default_guild(), default_user())
  end

  def default_user() do
    %Nostrum.Struct.User{
      avatar: nil,
      bot: true,
      discriminator: "4588",
      email: nil,
      id: 755_805_360_123_805_987,
      mfa_enabled: true,
      public_flags: %Nostrum.Struct.User.Flags{
        bug_hunter_level_1: false,
        bug_hunter_level_2: false,
        early_supporter: false,
        hypesquad_balance: false,
        hypesquad_bravery: false,
        hypesquad_brilliance: false,
        hypesquad_events: false,
        partner: false,
        staff: false,
        system: false,
        team_user: false,
        verified_bot: false,
        verified_developer: false
      },
      username: "Chromoid",
      verified: true
    }
  end

  def default_guild do
    %Nostrum.Struct.Guild{
      afk_channel_id: nil,
      afk_timeout: 300,
      application_id: nil,
      channels: nil,
      default_message_notifications: 1,
      embed_channel_id: "643947340453118019",
      embed_enabled: true,
      emojis: [
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 644_017_512_102_494_209,
          managed: false,
          name: "ping",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 644_017_585_452_482_597,
          managed: false,
          name: "pika",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 644_017_632_030_359_566,
          managed: false,
          name: "easyy",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: true,
          id: 644_017_675_940_528_138,
          managed: false,
          name: "miata_wink",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 644_018_994_604_539_904,
          managed: false,
          name: "dickboob",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 644_213_138_996_199_466,
          managed: false,
          name: "okflex",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 656_675_224_690_884_618,
          managed: false,
          name: "norotor",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: true,
          id: 656_677_133_669_892_109,
          managed: false,
          name: "honk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 656_677_915_664_318_474,
          managed: false,
          name: "nomiata",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 656_909_942_183_165_983,
          managed: false,
          name: "thistbh",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 666_048_907_494_686_720,
          managed: false,
          name: "novq",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 668_955_782_749_880_330,
          managed: false,
          name: "bonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 669_764_680_839_069_705,
          managed: false,
          name: "jakebonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 669_922_371_863_576_576,
          managed: false,
          name: "benbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 669_922_390_423_240_707,
          managed: false,
          name: "lambobonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 670_050_624_079_134_730,
          managed: false,
          name: "perhaps",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 671_517_874_099_191_808,
          managed: false,
          name: "justinbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 671_517_888_993_165_362,
          managed: false,
          name: "jasperbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 671_547_774_025_728_000,
          managed: false,
          name: "elisebonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 671_560_094_273_634_304,
          managed: false,
          name: "tjbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 671_560_829_849_698_304,
          managed: false,
          name: "nukibonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 672_131_951_980_838_933,
          managed: false,
          name: "fartbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 672_315_697_417_682_954,
          managed: false,
          name: "2kbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 673_723_901_192_306_709,
          managed: false,
          name: "noej",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 674_856_645_838_241_812,
          managed: false,
          name: "fakegay",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 677_752_873_362_259_989,
          managed: false,
          name: "philbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 701_478_919_345_406_035,
          managed: false,
          name: "venezuelabonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 701_670_287_950_872_576,
          managed: false,
          name: "bagelbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 712_708_080_760_258_691,
          managed: false,
          name: "sanic",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 720_331_180_024_528_999,
          managed: false,
          name: "tearsunglasses",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 720_341_136_031_613_038,
          managed: false,
          name: "brassobonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 721_949_666_408_792_134,
          managed: false,
          name: "nookbonk",
          require_colons: true,
          roles: [],
          user: nil
        },
        %Nostrum.Struct.Emoji{
          animated: false,
          id: 724_730_868_240_875_602,
          managed: false,
          name: "flex",
          require_colons: true,
          roles: [],
          user: nil
        }
      ],
      explicit_content_filter: 0,
      features: [],
      icon: "0c8e107405e53f0923deaa2a69cb504f",
      id: 643_947_339_895_013_416,
      joined_at: nil,
      large: nil,
      member_count: nil,
      members: nil,
      mfa_level: 0,
      name: "miata",
      owner_id: 316_741_621_498_511_363,
      region: "us-central",
      roles: %{
        643_947_339_895_013_416 => %Nostrum.Struct.Guild.Role{
          color: 0,
          hoist: false,
          id: 643_947_339_895_013_416,
          managed: false,
          mentionable: false,
          name: "@everyone",
          permissions: 104_324_689,
          position: 0
        },
        643_956_480_369_754_113 => %Nostrum.Struct.Guild.Role{
          color: 3_443_672,
          hoist: false,
          id: 643_956_480_369_754_113,
          managed: false,
          mentionable: false,
          name: "nb",
          permissions: 104_324_689,
          position: 19
        },
        643_956_497_184_718_887 => %Nostrum.Struct.Guild.Role{
          color: 1_752_220,
          hoist: false,
          id: 643_956_497_184_718_887,
          managed: false,
          mentionable: false,
          name: "nc",
          permissions: 104_324_689,
          position: 18
        },
        643_956_509_830_676_491 => %Nostrum.Struct.Guild.Role{
          color: 15_844_367,
          hoist: false,
          id: 643_956_509_830_676_491,
          managed: false,
          mentionable: false,
          name: "nd",
          permissions: 104_324_689,
          position: 17
        },
        643_956_523_575_410_718 => %Nostrum.Struct.Guild.Role{
          color: 3_066_993,
          hoist: false,
          id: 643_956_523_575_410_718,
          managed: false,
          mentionable: false,
          name: "exo",
          permissions: 104_324_689,
          position: 21
        },
        643_958_189_460_553_729 => %Nostrum.Struct.Guild.Role{
          color: 0,
          hoist: false,
          id: 643_958_189_460_553_729,
          managed: false,
          mentionable: true,
          name: "admin",
          permissions: 2_146_959_097,
          position: 22
        },
        644_001_874_420_432_908 => %Nostrum.Struct.Guild.Role{
          color: 11_537_257,
          hoist: false,
          id: 644_001_874_420_432_908,
          managed: false,
          mentionable: false,
          name: "honorary miata guy",
          permissions: 104_324_689,
          position: 15
        },
        645_070_257_060_446_209 => %Nostrum.Struct.Guild.Role{
          color: 16_711_680,
          hoist: false,
          id: 645_070_257_060_446_209,
          managed: false,
          mentionable: false,
          name: "na",
          permissions: 104_324_689,
          position: 20
        },
        645_075_570_006_294_538 => %Nostrum.Struct.Guild.Role{
          color: 16_711_932,
          hoist: true,
          id: 645_075_570_006_294_538,
          managed: false,
          mentionable: false,
          name: "server queen",
          permissions: 104_324_689,
          position: 24
        },
        656_921_490_268_094_472 => %Nostrum.Struct.Guild.Role{
          color: 2_067_276,
          hoist: false,
          id: 656_921_490_268_094_472,
          managed: false,
          mentionable: false,
          name: "baked",
          permissions: 104_324_689,
          position: 14
        },
        668_158_431_664_013_313 => %Nostrum.Struct.Guild.Role{
          color: 9_936_031,
          hoist: false,
          id: 668_158_431_664_013_313,
          managed: false,
          mentionable: false,
          name: "jake",
          permissions: 104_324_689,
          position: 23
        },
        676_866_072_032_575_498 => %Nostrum.Struct.Guild.Role{
          color: 0,
          hoist: false,
          id: 676_866_072_032_575_498,
          managed: false,
          mentionable: false,
          name: "new role",
          permissions: 104_324_689,
          position: 13
        },
        676_866_075_324_842_045 => %Nostrum.Struct.Guild.Role{
          color: 7_419_530,
          hoist: false,
          id: 676_866_075_324_842_045,
          managed: false,
          mentionable: true,
          name: "rotard",
          permissions: 104_324_689,
          position: 16
        },
        700_924_023_084_810_311 => %Nostrum.Struct.Guild.Role{
          color: 15_277_667,
          hoist: false,
          id: 700_924_023_084_810_311,
          managed: false,
          mentionable: false,
          name: "nice",
          permissions: 104_324_689,
          position: 12
        },
        700_953_507_104_292_915 => %Nostrum.Struct.Guild.Role{
          color: 2_067_276,
          hoist: false,
          id: 700_953_507_104_292_915,
          managed: false,
          mentionable: false,
          name: "baked af",
          permissions: 104_324_689,
          position: 11
        }
      },
      splash: nil,
      system_channel_id: 643_947_340_453_118_019,
      unavailable: nil,
      verification_level: 2,
      voice_states: nil,
      widget_channel_id: 643_947_340_453_118_019,
      widget_enabled: true
    }
  end
end
