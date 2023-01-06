defmodule KinoExplorer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(KinoExplorer.DataFrameCell)
    children = []
    opts = [strategy: :one_for_one, name: KinoExplorer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
