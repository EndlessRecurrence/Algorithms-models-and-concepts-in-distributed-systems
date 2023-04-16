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
    hub_address = "127.0.0.1"
    hub_port = 5000

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: DistributedAlgorithmsApp.PerfectLinkConnectionHandler.DynamicSupervisor},
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port, 1, nickname, hub_address, hub_port) end}, id: :first_listener_worker),
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 1, 2, nickname, hub_address, hub_port) end}, id: :second_listener_worker),
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 2, 3, nickname, hub_address, hub_port) end}, id: :third_listener_worker)
    ]

    opts = [strategy: :one_for_one, name: DistributedAlgorithmsApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
