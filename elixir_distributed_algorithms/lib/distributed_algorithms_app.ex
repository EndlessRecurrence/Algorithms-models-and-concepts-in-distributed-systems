defmodule DistributedAlgorithmsApp do
  @moduledoc """
    Module that contains the starting point of the application.
  """

  @doc """
    Starting point
  """
  def start() do
    port = Application.get_env(:elixir_distributed_algorithms, :port)

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: DistributedAlgorithmsApp.PerfectLinkHandler.DynamicSupervisor},
      Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port, 1) end}, id: :first_listener_worker),
      # TODO-1: Synchronize the 2 child processes below so that they send their registration messages to the hub sequentially, otherwise
      #         the messages will be garbled up and the hub will assign the same listening port to all processes, according to which message
      #         arrives first.
      # TODO-2: Maybe a message queue should be implemented for the server? (might be useless since Elixir process communication inherently
      #         uses message queueing for each process)

      # Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 1, 2) end}, id: :second_listener_worker),
      # Supervisor.child_spec({Task, fn -> DistributedAlgorithmsApp.PerfectLinkLayer.accept(port + 2, 3) end}, id: :third_listener_worker)
    ]

    opts = [strategy: :one_for_one, name: DistributedAlgorithmsApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
