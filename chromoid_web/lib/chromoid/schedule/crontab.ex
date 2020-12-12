defmodule Chromoid.Schedule.Crontab do
  @behaviour Ecto.Type

  def type, do: :string

  def cast(crontab_str) when is_binary(crontab_str) do
    case Crontab.CronExpression.Parser.parse(crontab_str) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> :error
    end
  end

  def cast(%Crontab.CronExpression{} = ok), do: {:ok, ok}
  def cast(_), do: :error

  def load(crontab_str) when is_binary(crontab_str) do
    case Crontab.CronExpression.Parser.parse(crontab_str) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> :error
    end
  end

  def dump(crontab_str) when is_binary(crontab_str) do
    {:ok, crontab_str}
  end

  def dump(%Crontab.CronExpression{} = expression) do
    case Crontab.CronExpression.Composer.compose(expression) do
      data when is_binary(data) -> {:ok, data}
      _ -> :error
    end
  end

  def embed_as(_format), do: :self

  def equal?(term, term), do: true
  def equal?(_, _), do: false
end
