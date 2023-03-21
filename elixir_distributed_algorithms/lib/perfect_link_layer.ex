defmodule DistributedAlgorithmsApp.PerfectLinkLayer do
  require Logger
  alias DistributedAlgorithmsApp.PerfectLinkHandler, as: PerfectLinkHandler

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])

    Logger.info("Port #{port} is open.")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("New connection accepted.")

    {:ok, pid} =
      DynamicSupervisor.start_child(PerfectLinkHandler.DynamicSupervisor, %{
        id: PerfectLinkHandler,
        start: {PerfectLinkHandler, :start_link, [%{socket: client}, []]},
        type: :worker,
        restart: :transient
      })

    :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end
end
