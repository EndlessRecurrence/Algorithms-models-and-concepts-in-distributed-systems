defmodule DistributedAlgorithmsApp.PerfectLinkLayer do
  require Logger
  alias DistributedAlgorithmsApp.PerfectLinkHandler, as: PerfectLinkHandler

  def accept(port, process_id, nickname) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])

    Logger.info("Port #{port} is open.")
    PerfectLinkHandler.register_process("127.0.0.1", 5000, process_id, port, nickname)
    loop_acceptor(socket, process_id, nickname)
  end

  defp loop_acceptor(socket, process_id, nickname) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("New connection accepted.")

    {:ok, pid} =
      DynamicSupervisor.start_child(PerfectLinkHandler.DynamicSupervisor, %{
        id: PerfectLinkHandler,
        start: {PerfectLinkHandler, :start_link, [%{socket: client, process_id: process_id, owner: nickname}]},
        type: :worker,
        restart: :transient
      })

    :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, process_id, nickname)
  end
end
