defmodule DistributedAlgorithmsApp do
  @moduledoc """
    Module that contains the starting point of the application.
  """

  @doc """
    Starting point
  """
  def start() do
    port = Application.get_env(:elixir_distributed_algorithms, :port)
    nickname = "shoot"

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: DistributedAlgorithmsApp.PerfectLinkHandler.DynamicSupervisor},
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port, 1, nickname) end}, id: :first_listener_worker),
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 1, 2, nickname) end}, id: :second_listener_worker),
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 2, 3, nickname) end}, id: :third_listener_worker)
    ]

    opts = [strategy: :one_for_one, name: DistributedAlgorithmsApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
