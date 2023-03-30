defmodule DistributedAlgorithmsApp.PerfectLinkHandler do
  use GenServer
  alias Protobuf
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

  @spec generate_process_registration_message(
    sender_address :: String.t(),
    sender_port :: integer(),
    owner :: String.t(),
    process_index :: integer()) :: Proto.Message
  def generate_process_registration_message(sender_address, sender_port, owner, process_index) do
    %Proto.Message{
      type: :NETWORK_MESSAGE,
      networkMessage: %Proto.NetworkMessage{
        senderHost: sender_address,
        senderListeningPort: sender_port,
        message: %Proto.Message{
          type: :PROC_REGISTRATION,
          procRegistration: %Proto.ProcRegistration{
            owner: owner,
            index: process_index
          }
        }
      }
    }
  end

  @spec register_process(hub_address :: String.t(), hub_port :: integer()) :: atom()
  def register_process(hub_address, hub_port) do
    address_bytes = Regex.split(~r/\./, hub_address)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, hub_port, options)
    port = Application.get_env(:elixir_distributed_algorithms, :port)

    encoded_registration_message=
      generate_process_registration_message("127.0.0.1", port, "george", 1)
        |> Protobuf.encode()

    IO.inspect Protobuf.decode(encoded_registration_message, Proto.Message)
    :gen_tcp.send(socket, <<0,0,0,byte_size(encoded_registration_message)>> <> encoded_registration_message)
    encoded_registration_message
  end
end
