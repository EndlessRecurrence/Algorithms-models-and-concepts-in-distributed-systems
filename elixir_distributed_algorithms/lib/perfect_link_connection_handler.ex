defmodule DistributedAlgorithmsApp.PerfectLinkConnectionHandler do
  use GenServer
  alias Protobuf
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  require Logger

  @message_size_in_bytes 4

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    socket = Map.get(args, :socket)
    pl_memory_pid = Map.get(args, :pl_memory_pid)
    :inet.setopts(socket, active: true)

    state =
      GenServer.call(pl_memory_pid, :get_state)
      |> Map.put(:socket, socket)
      |> Map.put(:pl_memory_pid, pl_memory_pid)

    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, _socket, packet}, state) do
    Logger.info("PERFECT_LINK_CONNECTION_HANDLER: Received packet #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    message = Protobuf.decode(binary_message, Proto.Message)
    IO.inspect message, label: "Received message", limit: :infinity

    PerfectLinkLayer.deliver_message(message, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("PERFECT_LINK_CONNECTION_HANDLER: Socket is closed")
    {:stop, {:shutdown, "Socket is closed"}, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("PERFECT_LINK_CONNECTION_HANDLER: Tcp error - #{inspect(reason)}")
    {:stop, {:shutdown, "Tcp error: #{inspect(reason)}"}, state}
  end
end
