defmodule DistributedAlgorithmsApp.PerfectLinkHandler do
  use GenServer
  require Logger

  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    socket = Map.get(args, :socket)
    :inet.setopts(socket, active: true)
    {:ok, %{socket: socket}}
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    Logger.info("Received packet: #{inspect(packet)} and send response")
    :gen_tcp.send(socket, "Hi from tcp server \n")
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket is closed")
    {:stop, {:shutdown, "Socket is closed"}, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("Tcp error: #{inspect(reason)}")
    {:stop, {:shutdown, "Tcp error: #{inspect(reason)}"}, state}
  end
end
