defmodule DistributedAlgorithmsApp do
  @moduledoc """
    Module that contains the starting point of the application.
  """

  @doc """
    Starting point
  """
  def start() do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: DistributedAlgorithmsApp.PerfectLinkHandler.DynamicSupervisor},
      {Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(Application.get_env(:elixir_distributed_algorithms, :port)) end}
    ]

    opts = [strategy: :one_for_one, name: DistributedAlgorithmsApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
